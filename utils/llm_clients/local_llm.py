import json
import os
import re
from typing import Any, Optional, Type, Union

import requests
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel

try:
	from json_repair import repair_json as _repair_json
except ImportError:
	_repair_json = None

# Load environment variables from .env file
load_dotenv()


def _parse_json_lenient(text: str) -> Any:
	"""Parse JSON from LLM output, tolerating code fences and minor malformations."""
	if not text:
		return {}
	# Strip ```json ... ``` or ``` ... ``` fences
	stripped = text.strip()
	fence = re.match(r"^```(?:json)?\s*(.*?)\s*```$", stripped, re.DOTALL)
	if fence:
		stripped = fence.group(1).strip()
	try:
		return json.loads(stripped)
	except json.JSONDecodeError:
		pass
	if _repair_json is not None:
		try:
			repaired = _repair_json(stripped, return_objects=False)
			return json.loads(repaired) if isinstance(repaired, str) else repaired
		except Exception:
			pass
	# Last resort: extract the largest {...} or [...] block and retry
	match = re.search(r"[\{\[].*[\}\]]", stripped, re.DOTALL)
	if match:
		return json.loads(match.group(0))
	raise json.JSONDecodeError("Could not parse LLM output as JSON", text, 0)


class LocalLLMClient:
	"""
	OpenAI-compatible client for a local LLM server (for example llama.cpp server).
	"""

	def __init__(
		self,
		model_name: str = "gemma4:31b",
		base_url: Optional[str] = None,
		api_key: Optional[str] = None,
		timeout: Optional[float] = None,
	):
		"""
		Initialize the LocalLLMClient.

		Args:
			model_name (str): Model identifier served by the local endpoint.
			base_url (str, optional): OpenAI-compatible endpoint base URL.
			api_key (str, optional): API key used by the local endpoint.
			timeout (float, optional): Per-request timeout in seconds. The
				OpenAI SDK defaults to 600s, which is too short when a large
				model digests an 80k-char Fortran chunk on a busy GPU. We
				default to ``LOCAL_LLM_TIMEOUT_SECONDS`` (30 min) so long
				ingestion calls don't get cut off mid-generation.
		"""
		self.model_name = model_name
		self.base_url = base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
		self.api_key = api_key or os.getenv("LOCAL_LLM_API_KEY", "ollama")
		if timeout is None:
			try:
				timeout = float(os.getenv("LOCAL_LLM_TIMEOUT_SECONDS", "1800"))
			except ValueError:
				timeout = 1800.0
		self.timeout = timeout

		self.client = OpenAI(
			base_url=self.base_url,
			api_key=self.api_key,
			timeout=self.timeout,
		)

		# Detect Ollama endpoint (its OpenAI-compat layer drops images)
		self._ollama_base = None
		m = re.match(r"(https?://.+?)(/v1)?$", self.base_url)
		if m:
			try:
				r = requests.get(f"{m.group(1)}/api/tags", timeout=2)
				if r.ok:
					self._ollama_base = m.group(1)
			except Exception:
				pass

		# Context window cache — fetched lazily on first call.
		self._context_window: Optional[int] = None

	def get_context_window(self, default: int = 32768) -> int:
		"""Return the model's context window in tokens.

		Resolution order (cached after the first successful lookup):
		  1. ``LLM_CONTEXT_WINDOW`` env var, if set to a positive int.
		  2. Ollama's ``/api/show`` (the ``<arch>.context_length`` field of
		     ``model_info``) when an Ollama endpoint was detected.
		  3. ``default``.

		Letting callers override the value via env var means swapping in a
		different backend (vLLM, llama.cpp, hosted) just needs a config
		change, not code surgery.
		"""
		if self._context_window is not None:
			return self._context_window

		env_val = os.getenv("LLM_CONTEXT_WINDOW")
		if env_val:
			try:
				n = int(env_val)
				if n > 0:
					self._context_window = n
					return n
			except ValueError:
				pass

		if self._ollama_base:
			try:
				resp = requests.post(
					f"{self._ollama_base}/api/show",
					json={"name": self.model_name},
					timeout=5,
				)
				if resp.ok:
					info = resp.json().get("model_info", {}) or {}
					for key, val in info.items():
						if key.endswith(".context_length") and isinstance(val, int) and val > 0:
							self._context_window = val
							return val
			except Exception:
				pass

		self._context_window = default
		return default

	def _ollama_vision(
		self,
		user_prompt: list,
		system_prompt: Optional[str],
		temperature: float,
		max_tokens: int,
	) -> str:
		"""Send a vision request via Ollama's native /api/chat endpoint."""
		# Extract text and base64 images from OpenAI-format content blocks
		text_parts = []
		images = []
		for block in user_prompt:
			if block.get("type") == "text":
				text_parts.append(block["text"])
			elif block.get("type") == "image_url":
				url = block["image_url"]["url"]
				# Strip data URI prefix
				if url.startswith("data:"):
					images.append(url.split(",", 1)[1])
				else:
					images.append(url)

		messages = []
		if system_prompt:
			messages.append({"role": "system", "content": system_prompt})
		messages.append({
			"role": "user",
			"content": " ".join(text_parts),
			"images": images,
		})

		resp = requests.post(
			f"{self._ollama_base}/api/chat",
			json={
				"model": self.model_name,
				"messages": messages,
				"stream": False,
				"options": {"temperature": temperature},
			},
			timeout=self.timeout,
		)
		resp.raise_for_status()
		return resp.json().get("message", {}).get("content", "")

	def generate_response(
		self,
		user_prompt: Union[str, list],
		system_prompt: Optional[str] = None,
		response_schema: Optional[Type[BaseModel]] = None,
		response_mime_type: str = "application/json",
		temperature: float = 0.2,
		max_tokens: Optional[int] = None,
	) -> Any:
		"""
		Generate a response from the local model.

		Args:
			user_prompt (Union[str, list]): Main prompt from the user. Can be a string or a list of OpenAI content blocks.
			system_prompt (str, optional): Optional system instruction.
			response_schema (Type[BaseModel], optional): Pydantic schema for structured output.
			response_mime_type (str): "application/json" for JSON, otherwise plain text.
			temperature (float): Sampling temperature.
			max_tokens (int): Maximum completion tokens.

		Returns:
			Any: Text, dict, or validated Pydantic object depending on options.
		"""
		# Ollama's OpenAI-compat endpoint drops images; use native API
		has_images = isinstance(user_prompt, list) and any(
			b.get("type") == "image_url" for b in user_prompt
		)
		if has_images and self._ollama_base:
			return self._ollama_vision(
				user_prompt, system_prompt, temperature, max_tokens
			)

		messages = []
		if system_prompt:
			messages.append({"role": "system", "content": system_prompt})
		messages.append({"role": "user", "content": user_prompt})

		base_kwargs = {
			"model": self.model_name,
			"messages": messages,
			"temperature": temperature,
		}
		if max_tokens is not None:
			base_kwargs["max_tokens"] = max_tokens

		try:
			if response_schema and issubclass(response_schema, BaseModel):
				completion = self.client.chat.completions.create(
					**base_kwargs,
					response_format={"type": "json_object"},
				)
				response_text = completion.choices[0].message.content
				payload = _parse_json_lenient(response_text) if response_text else {}
				return response_schema.model_validate(payload)

			if response_mime_type == "application/json":
				completion = self.client.chat.completions.create(
					**base_kwargs,
					response_format={"type": "json_object"},
				)
				response_text = completion.choices[0].message.content
				return _parse_json_lenient(response_text) if response_text else {}

			completion = self.client.chat.completions.create(**base_kwargs)
			return completion.choices[0].message.content
		except Exception as e:
			print(f"Error generating content from local LLM: {e}")
			raise


if __name__ == "__main__":
	try:
		client = LocalLLMClient()
		response = client.generate_response(
			user_prompt="What is 2 + 2?",
			system_prompt="Answer with only the number.",
			response_mime_type="text/plain",
		)
		print(response)
	except Exception as e:
		print(f"Skipping execution: {e}")
