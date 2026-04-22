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
	):
		"""
		Initialize the LocalLLMClient.

		Args:
			model_name (str): Model identifier served by the local endpoint.
			base_url (str, optional): OpenAI-compatible endpoint base URL.
			api_key (str, optional): API key used by the local endpoint.
		"""
		self.model_name = model_name
		self.base_url = base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
		self.api_key = api_key or os.getenv("LOCAL_LLM_API_KEY", "ollama")

		self.client = OpenAI(base_url=self.base_url, api_key=self.api_key)

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
			timeout=300,
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
