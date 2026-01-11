import sys
import os
from pathlib import Path

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

from utils.llm_clients.gemini import GeminiClient
from utils.llm_clients.gpt import GPTClient
from pydantic import BaseModel


class ColorInfo(BaseModel):
    """Model for color information"""
    color: str
    hex_code: str


class ColorList(BaseModel):
    """Model for a list of colors"""
    colors: list[ColorInfo]


def test_gemini_text_generation():
    """Test Gemini client with plain text generation"""
    print("\n=== Testing Gemini: Text Generation ===")
    try:
        client = GeminiClient()
        response = client.generate_response(
            user_prompt="What is 2 + 2? Answer with just the number.",
            response_mime_type="text/plain"
        )
        print(f"Response: {response}")
        print("✓ Gemini text generation successful")
        return True
    except Exception as e:
        print(f"✗ Gemini text generation failed: {e}")
        return False


def test_gemini_json_generation():
    """Test Gemini client with JSON generation"""
    print("\n=== Testing Gemini: JSON Generation ===")
    try:
        client = GeminiClient()
        response = client.generate_response(
            user_prompt="List 2 colors with their hex codes",
            system_prompt="You are a color expert. Output in JSON format with structure: {colors: [{color: string, hex_code: string}]}",
            response_mime_type="application/json"
        )
        print(f"Response: {response}")
        print("✓ Gemini JSON generation successful")
        return True
    except Exception as e:
        print(f"✗ Gemini JSON generation failed: {e}")
        return False


def test_gemini_structured_output():
    """Test Gemini client with structured output using Pydantic"""
    print("\n=== Testing Gemini: Structured Output (Pydantic) ===")
    try:
        client = GeminiClient()
        response = client.generate_response(
            user_prompt="List 3 colors with their hex codes",
            system_prompt="You are a color expert.",
            response_schema=ColorList,
            response_mime_type="application/json"
        )
        print(f"Response: {response}")
        print(f"Type: {type(response)}")
        print("✓ Gemini structured output successful")
        return True
    except Exception as e:
        print(f"✗ Gemini structured output failed: {e}")
        return False


def test_gpt_text_generation():
    """Test GPT client with plain text generation"""
    print("\n=== Testing GPT: Text Generation ===")
    try:
        client = GPTClient()
        response = client.generate_response(
            user_prompt="What is 2 + 2? Answer with just the number.",
            response_mime_type="text/plain"
        )
        print(f"Response: {response}")
        print("✓ GPT text generation successful")
        return True
    except Exception as e:
        print(f"✗ GPT text generation failed: {e}")
        return False


def test_gpt_json_generation():
    """Test GPT client with JSON generation"""
    print("\n=== Testing GPT: JSON Generation ===")
    try:
        client = GPTClient()
        response = client.generate_response(
            user_prompt="List 2 colors with their hex codes in JSON format",
            system_prompt="You are a color expert. Output valid JSON.",
            response_mime_type="application/json"
        )
        print(f"Response: {response}")
        print(f"Type: {type(response)}")
        print("✓ GPT JSON generation successful")
        return True
    except Exception as e:
        print(f"✗ GPT JSON generation failed: {e}")
        return False


def test_gpt_structured_output():
    """Test GPT client with structured output using Pydantic"""
    print("\n=== Testing GPT: Structured Output (Pydantic) ===")
    try:
        client = GPTClient()
        response = client.generate_response(
            user_prompt="List 3 colors with their hex codes",
            system_prompt="You are a color expert.",
            response_schema=ColorList
        )
        print(f"Response: {response}")
        print(f"Type: {type(response)}")
        if hasattr(response, 'colors'):
            print(f"Number of colors: {len(response.colors)}")
            for color_info in response.colors:
                print(f"  - {color_info.color}: {color_info.hex_code}")
        print("✓ GPT structured output successful")
        return True
    except Exception as e:
        print(f"✗ GPT structured output failed: {e}")
        return False


def run_all_tests():
    """Run all tests and report results"""
    print("=" * 60)
    print("Starting LLM Client Tests")
    print("=" * 60)
    
    results = {
        "Gemini Text": test_gemini_text_generation(),
        "Gemini JSON": test_gemini_json_generation(),
        "Gemini Structured": test_gemini_structured_output(),
        "GPT Text": test_gpt_text_generation(),
        "GPT JSON": test_gpt_json_generation(),
        "GPT Structured": test_gpt_structured_output(),
    }
    
    print("\n" + "=" * 60)
    print("Test Results Summary")
    print("=" * 60)
    
    for test_name, passed in results.items():
        status = "✓ PASSED" if passed else "✗ FAILED"
        print(f"{test_name}: {status}")
    
    total = len(results)
    passed = sum(results.values())
    print(f"\nTotal: {passed}/{total} tests passed")
    print("=" * 60)
    
    return all(results.values())


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
