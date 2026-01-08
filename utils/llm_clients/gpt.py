import os
import json
from typing import Optional, Any, Type, Union, Dict
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel

# Load environment variables from .env file
load_dotenv()

class GPTClient:
    """
    A wrapper class for the OpenAI API.
    """

    def __init__(self, model_name: str = "gpt-4o", api_key: Optional[str] = None):
        """
        Initialize the GPTClient.

        Args:
            model_name (str): The name of the OpenAI model to use. Defaults to "gpt-4o".
            api_key (str, optional): The API key. If not provided, it is fetched from the OPENAI_API_KEY env var.
        """
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY not found in environment variables. Please set it in your .env file.")
            
        self.client = OpenAI(api_key=self.api_key)
        self.model_name = model_name

    def generate_response(
        self,
        user_prompt: str,
        system_prompt: Optional[str] = None,
        response_schema: Optional[Type[BaseModel]] = None,
        response_mime_type: str = "application/json" 
    ) -> Any:
        """
        Generates content based on user and system prompts, with optional structured output.

        Args:
            user_prompt (str): The main prompt from the user.
            system_prompt (str, optional): The system instruction to guide the model's behavior.
            response_schema (Type[BaseModel], optional): The Pydantic model for structured output.
            response_mime_type (str): Used to hint at JSON format if schema is not provided but JSON is desired.
                                      If "application/json" is passed and no schema, 'json_object' mode is used.

        Returns:
            Any: The parsed response object (if schema provided), or the response text.
        """
        
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        messages.append({"role": "user", "content": user_prompt})

        try:
            # Case 1: Structured Output using Pydantic schema (Structured Outputs)
            if response_schema and issubclass(response_schema, BaseModel):
                completion = self.client.beta.chat.completions.parse(
                    model=self.model_name,
                    messages=messages,
                    response_format=response_schema,
                )
                return completion.choices[0].message.parsed

            # Case 2: JSON Mode (no strict schema provided, but JSON requested)
            elif response_mime_type == "application/json":
                # Ensure the prompt asks for JSON if using json_object mode, 
                # otherwise OpenAI might throw an error or perform poorly.
                # We won't force-append text, but we'll set the flag.
                completion = self.client.chat.completions.create(
                    model=self.model_name,
                    messages=messages,
                    response_format={"type": "json_object"},
                )
                response_text = completion.choices[0].message.content
                return json.loads(response_text) if response_text else {}

            # Case 3: Standard Text Generation
            else:
                completion = self.client.chat.completions.create(
                    model=self.model_name,
                    messages=messages,
                )
                return completion.choices[0].message.content

        except Exception as e:
            print(f"Error generating content: {e}")
            raise

if __name__ == "__main__":
    # Example usage
    try:
        # Simple text example
        client = GPTClient()
        print("--- Text Generation ---")
        response = client.generate_response(
            user_prompt="Explain how AI works in a few words",
            response_mime_type="text/plain"
        )
        print(response)

        # Structured output example (requires defining a schema)
        print("\n--- Structured Output (Pydantic) ---")
        class ColorInfo(BaseModel):
            color: str
            hex_code: str

        class ColorList(BaseModel):
            colors: list[ColorInfo]

        response_obj = client.generate_response(
            user_prompt="List 3 colors and their hex codes",
            system_prompt="You are a color expert.",
            response_schema=ColorList
        )
        print(response_obj)

    except Exception as e:
        print(f"Skipping execution: {e}")
