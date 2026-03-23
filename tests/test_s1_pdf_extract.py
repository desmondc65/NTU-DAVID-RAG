import sys
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.s1_data_ingestion.pdf_extract import extract_pdf_mineru, describe_mineru_images, describe_mineru_equations

def main():
    input_pdf = REPO_ROOT / "tests" / "Manuscript.pdf"
    output_dir = REPO_ROOT / "tests" / "output_pdf_extract"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Checking for existing output for {input_pdf}...")
    expected_md = output_dir / input_pdf.stem / "auto" / f"{input_pdf.stem}.md"
    json_path = output_dir / input_pdf.stem / "auto" / f"{input_pdf.stem}_content_list.json"
    
    if not json_path.exists():
        print(f"Testing extraction on {input_pdf}...")
        try:
            expected_md_path = extract_pdf_mineru(
                input_path=input_pdf,
                output_dir=output_dir,
                backend="pipeline",
                method="auto",
                lang="en", 
            )
            print(f"Success! Output markdown saved to: {expected_md_path}")
        except Exception as e:
            print(f"Error during extraction (e.g. CUDA OOM): {e}")
    else:
        print(f"JSON already exists at {json_path}. Skipping extraction.")
            
    if json_path.exists():
        print(f"\nTesting image description for RAG on {json_path}...")
        try:
            describe_mineru_images(json_path)
                
            print("Success! Image description complete.")
        except Exception as e:
            print(f"Error during image description: {e}")
            
        print(f"\nTesting equation description for RAG on {json_path}...")
        try:
            describe_mineru_equations(json_path)
                
            print("Success! Equation description complete.")
        except Exception as e:
            print(f"Error during equation description: {e}")
    else:
        print(f"\nWarning: Could not find JSON output at {json_path} to test descriptions.")

if __name__ == "__main__":
    main()
