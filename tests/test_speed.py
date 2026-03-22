import time
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.llm_clients.local_llm import LocalLLMClient

def main():
    print("Initializing client...")
    client = LocalLLMClient(
        model_name="qwen3-next-80b-instruct-q8_0",
        base_url="http://localhost:8000/v1",
        api_key="local-dev-key",
    )
    
    prompt = "Explain the difference between OLS (Ordinary Least Squares) and Instrumental Variables (IV) in econometrics, and when to use each. Provide a concise 3-bullet summary."
    print("Sending request...")
    
    start_time = time.time()
    resp = client.generate_response(
        user_prompt=prompt,
        response_mime_type="text/plain",
    )
    end_time = time.time()
    
    elapsed = end_time - start_time
    # Since we can't easily get the exact token count from the simple client wrapper return string,
    # we can approximate using words or characters, assuming ~4 characters = 1 token.
    estimated_tokens = len(resp) / 4.0
    tokens_per_sec = estimated_tokens / elapsed
    
    print("\n--- Response ---")
    print(resp)
    print("----------------\n")
    print(f"Time taken: {elapsed:.2f} seconds")
    print(f"Estimated Tokens Generated: ~{int(estimated_tokens)}")
    print(f"Estimated Speed: ~{tokens_per_sec:.2f} tokens/second")

if __name__ == "__main__":
    main()
