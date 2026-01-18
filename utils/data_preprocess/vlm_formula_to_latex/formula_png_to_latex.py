import os
import sys
import re
from PIL import Image
from typing import Optional

# Add the project root to sys.path to allow imports from utils
# assuming this script might be run from root or within subdirs
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(current_dir, "../../../../"))
if project_root not in sys.path:
    sys.path.append(project_root)

try:
    from utils.llm_clients.gemini import GeminiClient
except ImportError:
    # Fallback if running relative to root without sys.path adjustment working as expected
    sys.path.append(os.path.abspath(os.path.join(current_dir, "../../../")))
    from utils.llm_clients.gemini import GeminiClient

def png_to_latex(image_path: str, return_cost: bool = False):
    """
    Transcribes a formula PNG to LaTeX using Gemini.

    Args:
        image_path (str): Path to the formula PNG image.
        return_cost (bool): If True, return tuple of (latex_code, usage_metadata).
                           Defaults to False for backward compatibility.

    Returns:
        str: The LaTeX string of the formula.
        tuple: (latex_code, usage_metadata) if return_cost=True
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image file not found: {image_path}")

    # Initialize Gemini Client
    # Using gemini-3-flash-preview as default
    client = GeminiClient(model_name="gemini-3-flash-preview")
    
    try:
        image = Image.open(image_path)
    except Exception as e:
        raise ValueError(f"Failed to open image: {e}")

    prompt_text = (
        "Transcribe the mathematical formula in this image into LaTeX format. "
        "Return ONLY the LaTeX code. Do not include markdown code blocks (like ```latex ... ```). "
        "Do not include any explanations. "
        "If the image does not contain a valid mathematical formula (e.g., likely a noise crop, just text, or blank), "
        "return exactly the string 'NOT_A_FORMULA'."
    )

    # passing list of [text, image] as user_prompt, relying on dynamic typing 
    # and the fact that the underlying SDK accepts mixed content.
    try: 
        if return_cost:
            response_text, usage_metadata = client.generate_response(
                user_prompt=[prompt_text, image],
                response_mime_type="text/plain",
                return_usage=True
            )
        else:
            response_text = client.generate_response(
                user_prompt=[prompt_text, image],
                response_mime_type="text/plain"
            )
            usage_metadata = None
    except Exception as e:
        print(f"Gemini API Error: {e}")
        if return_cost:
            return "", None
        return ""

    # Post-process to ensure cleanliness
    latex_code = response_text.strip()
    
    if latex_code == "NOT_A_FORMULA":
        if return_cost:
            return "", usage_metadata
        return ""
    
    # Remove markdown code blocks if present (just in case model disobeys)
    # ^```(latex)?\s* and \s*```$
    latex_code = re.sub(r"^```[a-zA-Z]*\s*", "", latex_code)
    latex_code = re.sub(r"\s*```$", "", latex_code)

    # Fix potential double escaping (e.g., \\lambda -> \lambda)
    # But preserve LaTeX newlines (\\ at end of line or before space is valid)
    # We target \\ followed immediately by a letter.
    latex_code = re.sub(r"\\\\([a-zA-Z])", r"\\\1", latex_code)
    
    if return_cost:
        return latex_code.strip(), usage_metadata
    return latex_code.strip()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 formula_png_to_latex.py <path_to_png>")
        sys.exit(1)
        
    image_path = sys.argv[1]
    try:
        latex = png_to_latex(image_path)
        print(latex)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
