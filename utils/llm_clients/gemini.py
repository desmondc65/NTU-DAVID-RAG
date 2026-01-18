import os
from typing import Optional, Any, Type, Union
from dotenv import load_dotenv
from google import genai
from pydantic import BaseModel

# Load environment variables from .env file
load_dotenv()

class GeminiClient:
    """
    A wrapper class for the Google Gemini API using the google-genai SDK.
    """

    def __init__(self, model_name: str = "gemini-3-flash-preview", api_key: Optional[str] = None):
        """
        Initialize the GeminiClient.

        Args:
            model_name (str): The name of the Gemini model to use. Defaults to "gemini-3-flash-preview".
            api_key (str, optional): The API key. If not provided, it is fetched from the GEMINI_API_KEY env var.
        """
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not found in environment variables. Please set it in your .env file.")
            
        self.client = genai.Client(api_key=self.api_key)
        self.model_name = model_name

    def generate_response(
        self,
        user_prompt: str,
        system_prompt: Optional[str] = None,
        response_schema: Optional[Union[Type[BaseModel], Any]] = None,
        response_mime_type: str = "application/json",
        return_usage: bool = False
    ) -> Any:
        """
        Generates content based on user and system prompts, with optional structured output.

        Args:
            user_prompt (str): The main prompt from the user.
            system_prompt (str, optional): The system instruction to guide the model's behavior.
            response_schema (Type[BaseModel] | Any, optional): The schema for structured output. 
                                                               Can be a Pydantic model or a raw schema dict.
            response_mime_type (str): The MIME type for the response. Defaults to "application/json".
                                      Use "text/plain" for unstructured text.
            return_usage (bool): If True, return a tuple of (response_text, usage_metadata).
                                Defaults to False for backward compatibility.

        Returns:
            Any: The parsed response object if schema is provided, or the response text.
                 If return_usage=True, returns tuple of (response, usage_metadata).
        """
        
        config_kwargs = {
            "response_mime_type": response_mime_type,
        }

        if response_schema:
            config_kwargs["response_schema"] = response_schema
        
        if system_prompt:
            config_kwargs["system_instruction"] = system_prompt

        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=user_prompt,
                config=config_kwargs
            )
            
            # Extract the response content
            # If a Pydantic model was passed as schema, the SDK might return a parsed object
            # or we might need to handle parsing depending on the SDK version nuances.
            # With google-genai SDK, usually response.parsed is available if schema is provided.
            if response_schema and hasattr(response, 'parsed'):
                response_content = response.parsed
            else:
                response_content = response.text
            
            # Return with usage metadata if requested
            if return_usage:
                usage_metadata = response.usage_metadata if hasattr(response, 'usage_metadata') else None
                return response_content, usage_metadata
            
            return response_content
                
        except Exception as e:
            print(f"Error generating content: {e}")
            raise

if __name__ == "__main__":
    # Example usage
    try:
        # Simple text example
        client = GeminiClient()
        print("--- Text Generation ---")
        response = client.generate_response(
            user_prompt="Explain how AI works in a few words",
            response_mime_type="text/plain"
        )
        print(response)

        # Structured output example (requires defining a schema, here we just use JSON mime type generic)
        print("\n--- Structured Output (JSON) ---")
        response_json = client.generate_response(
            user_prompt="List 3 colors and their hex codes",
            system_prompt="You are a color expert. Output in JSON format.",
            response_mime_type="application/json"
        )
        print(response_json)

    except Exception as e:
        print(f"Skipping execution: {e}")
