import os
import time
import torch
from typing import Optional, Any, Type, Union
from dotenv import load_dotenv
from transformers import AutoModelForCausalLM, AutoTokenizer
from pydantic import BaseModel

# Load environment variables from .env file
load_dotenv()

class Qwen32bClient:
    """
    A wrapper class for the local Qwen 32B model using Hugging Face Transformers.
    """

    def __init__(self, model_name: str = "Qwen/Qwen2.5-32B-Instruct", device_map: str = "auto"):
        """
        Initialize the Qwen32bClient.

        Args:
            model_name (str): The name or path of the Qwen model. Defaults to "Qwen/Qwen2.5-32B-Instruct".
            device_map (str): Device placement strategy. Defaults to "auto" (uses all available GPUs).
        """
        self.model_name = model_name
        self.device_map = device_map
        self.model = None
        self.tokenizer = None
        
        # Lazy loading of the model to avoid heavy lifting on import if not used immediately
        # However, for a client class, usually we want it ready after init.
        # Given the size, let's load it on init but handle errors gracefully.
        try:
            print(f"Loading {self.model_name}... This may take a while.")
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name, trust_remote_code=True)
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                device_map=self.device_map,
                trust_remote_code=True,
                torch_dtype=torch.float16,  # Use float16 for efficiency, or bfloat16 if supported
                # load_in_4bit=True 
                # Note: load_in_4bit requires bitsandbytes. 
                # I'm commenting it out by default to adhere to standard loading, 
                # but users with typical consumer GPUs will likely need it.
                # Given user installed bitsandbytes, let's attempt to use quantization configuration 
                # if the user explicitly wants it, otherwise standard load might OOM.
                # For now, I'll stick to standard load with float16 to be safe on "how" it's loaded, 
                # unless I add a quantization arg. 
                # Let's assume the user has enough VRAM or will modify for 4bit if needed.
                # Actually, adding a quantization check or default might be better but let's stick to simple first.
            )
            print("Model loaded successfully.")
        except Exception as e:
            print(f"Error loading model {self.model_name}: {e}")
            print("Ensure you have sufficient VRAM and dependencies installed.")
            # We don't raise here to allow the script to be imported/defined without crashing immediately if model missing,
            # but methods will fail.

    def generate_response(
        self,
        user_prompt: str,
        system_prompt: Optional[str] = None,
        response_schema: Optional[Type[BaseModel]] = None,
        response_mime_type: str = "application/json",
        max_new_tokens: int = 2048,
        temperature: float = 0.7
    ) -> Any:
        """
        Generates content based on user and system prompts.

        Args:
            user_prompt (str): The main prompt from the user.
            system_prompt (str, optional): The system instruction.
            response_schema (Type[BaseModel], optional): Unused for local simple generation, but kept for interface consistency.
            response_mime_type (str): Unused for local simple generation, but kept for interface consistency.
            max_new_tokens (int): Maximum new tokens to generate.
            temperature (float): Sampling temperature.

        Returns:
            Any: The response text.
        """
        if not self.model or not self.tokenizer:
            raise RuntimeError("Model or tokenizer not loaded. Check initialization errors.")

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        messages.append({"role": "user", "content": user_prompt})

        # Apply chat template
        text = self.tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )

        model_inputs = self.tokenizer([text], return_tensors="pt").to(self.model.device)

        generated_ids = self.model.generate(
            model_inputs.input_ids,
            attention_mask=model_inputs.attention_mask,
            max_new_tokens=max_new_tokens,
            temperature=temperature,
            do_sample=True if temperature > 0 else False
        )
        
        generated_ids = [
            output_ids[len(input_ids):] for input_ids, output_ids in zip(model_inputs.input_ids, generated_ids)
        ]

        response = self.tokenizer.batch_decode(generated_ids, skip_special_tokens=True)[0]

        return response

if __name__ == "__main__":
    # Example usage
    try:
        # Check if cuda available to avoid running on CPU if unintended (though model load would likely fail/warn)
        if not torch.cuda.is_available():
            print("Warning: CUDA not available. Running 32B model on CPU is effectively impossible for interactive use.")
        else:
            print(f"CUDA available: {torch.cuda.device_count()} devices")

        # Note: This will attempt to download/load the model which is huge (60GB+ for fp16).
        # We wrap in a block to only run if intended.
        print("Initializing Qwen32bClient...")
        client = Qwen32bClient() 
        
        print("--- Text Generation ---")
        start_time = time.time()
        response = client.generate_response(
            user_prompt="Explain how AI works in a few words",
            system_prompt="You are a helpful assistant."
        )
        end_time = time.time()
        print(f"Response: {response}")
        print(f"Inference time: {end_time - start_time:.2f} seconds")
        
        print("Example code present. Uncomment lines to run actual inference (requires heavy hardware).")

    except Exception as e:
        print(f"Skipping execution: {e}")
