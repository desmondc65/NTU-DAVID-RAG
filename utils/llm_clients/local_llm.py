import json
import os
from typing import Any, Optional, Type, Union

from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel

# Load environment variables from .env file
load_dotenv()


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

	def generate_response(
		self,
		user_prompt: Union[str, list],
		system_prompt: Optional[str] = None,
		response_schema: Optional[Type[BaseModel]] = None,
		response_mime_type: str = "application/json",
		temperature: float = 0.2,
		max_tokens: int = 1024,
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
		messages = []
		if system_prompt:
			messages.append({"role": "system", "content": system_prompt})
		messages.append({"role": "user", "content": user_prompt})

		try:
			if response_schema and issubclass(response_schema, BaseModel):
				completion = self.client.chat.completions.create(
					model=self.model_name,
					messages=messages,
					temperature=temperature,
					max_tokens=max_tokens,
					response_format={"type": "json_object"},
				)
				response_text = completion.choices[0].message.content
				payload = json.loads(response_text) if response_text else {}
				return response_schema.model_validate(payload)

			if response_mime_type == "application/json":
				completion = self.client.chat.completions.create(
					model=self.model_name,
					messages=messages,
					temperature=temperature,
					max_tokens=max_tokens,
					response_format={"type": "json_object"},
				)
				response_text = completion.choices[0].message.content
				return json.loads(response_text) if response_text else {}

			completion = self.client.chat.completions.create(
				model=self.model_name,
				messages=messages,
				temperature=temperature,
				max_tokens=max_tokens,
			)
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
