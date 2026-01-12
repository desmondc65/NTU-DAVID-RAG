import argparse
import os
import sys
import json
import re
import glob

# Ensure we can import from the same directory
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

try:
    from pdf_to_png import convert_pdf_to_png
    from cropper import crop_formulas
    from formula_png_to_latex import png_to_latex
except ImportError as e:
    print(f"Import Error: {e}")
    sys.exit(1)

def orchestrate_extraction(
    pdf_path: str,
    parsed_json_path: str,
    output_manuscript_png_folder: str,
    output_formula_png_folder: str,
    output_formula_latex_json_path: str,
    output_formula_latex_md_path: str = None
):
    """
    Orchestrates the full pipeline:
    1. Convert PDF to Page PNGs.
    2. Crop Formulas from Page PNGs using Docling JSON.
    3. Transcribe Cropped Formulas to LaTeX.
    4. Save results to a single JSON file.
    """
    
    # 1. Convert PDF to Page PNGs
    print("\n[Step 1/4] Converting PDF to Page PNGs...")
    convert_pdf_to_png(pdf_path, output_manuscript_png_folder)
    
    # 2. Crop Formulas
    print("\n[Step 2/4] Cropping Formulas...")
    crop_formulas(parsed_json_path, output_manuscript_png_folder, output_formula_png_folder)
    
    # 3. Transcribe & Collect Data
    print("\n[Step 3/4] Transcribing Formulas to LaTeX...")
    
    results = []
    
    # Find all generated formula images
    # Pattern: page_{page_no}_formula_{formula_idx}.png
    formula_files = glob.glob(os.path.join(output_formula_png_folder, "page_*_formula_*.png"))
    
    
    # Sort natural order (page 9 before page 10)
    def file_sort_key(fname):
        base = os.path.basename(fname)
        # Extract numbers using regex
        match = re.search(r"page_(\d+)_formula_(\d+)\.png", base)
        if match:
            return (int(match.group(1)), int(match.group(2)))
        return (0, 0)

    formula_files.sort(key=file_sort_key)
    
    total_formulas = len(formula_files)
    print(f"Found {total_formulas} cropped formula images to process.")
    
    # Define a helper function for processing a single image
    def process_single_image(img_path):
        filename = os.path.basename(img_path)
        # Extract metadata from filename
        match = re.search(r"page_(\d+)_formula_(\d+)\.png", filename)
        if match:
            page_no = int(match.group(1))
            formula_idx = int(match.group(2))
        else:
            # print(f"Warning: Could not parse filename {filename}. Skipping metadata extraction.")
            page_no = -1
            formula_idx = -1
            
        try:
            # Call the transcription function
            latex_code = png_to_latex(img_path)
            
            return {
                "page_no": page_no,
                "formula_index": formula_idx,
                "image_name": filename,
                "latex": latex_code
            }
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            return None

    # Use ThreadPoolExecutor for parallel processing
    from concurrent.futures import ThreadPoolExecutor, as_completed
    from tqdm import tqdm

    results = []
    # Adjust max_workers as needed. Gemini has rate limits, so don't set this too high (e.g., 5-10 is usually safe).
    MAX_WORKERS = 10 
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # Submit all tasks
        future_to_file = {executor.submit(process_single_image, f): f for f in formula_files}
        
        # Process as they complete (with progress bar)
        for future in tqdm(as_completed(future_to_file), total=total_formulas, desc="Transcribing"):
            res = future.result()
            if res:
                results.append(res)
    
    # Sort results by page_no then formula_index because parallel execution scrambles order
    results.sort(key=lambda x: (x['page_no'], x['formula_index']))
            
    # 4. Save to JSON
    print("\n[Step 4/4] Saving results to JSON...")
    
    # Ensure directory exists for output json
    output_json_dir = os.path.dirname(os.path.abspath(output_formula_latex_json_path))
    if not os.path.exists(output_json_dir):
        os.makedirs(output_json_dir, exist_ok=True)
        
    try:
        with open(output_formula_latex_json_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"Successfully saved {len(results)} formulas to {output_formula_latex_json_path}")
    except Exception as e:
        print(f"Error saving JSON: {e}")
        sys.exit(1)

    # 5. Save to Markdown (Optional)
    if output_formula_latex_md_path:
        print(f"\n[Step 5/5] Saving results to Markdown: {output_formula_latex_md_path}...")
        try:
             # Ensure directory exists for output md
            output_md_dir = os.path.dirname(os.path.abspath(output_formula_latex_md_path))
            if not os.path.exists(output_md_dir):
                os.makedirs(output_md_dir, exist_ok=True)
                
            with open(output_formula_latex_md_path, 'w', encoding='utf-8') as f:
                f.write(f"# Formula Extraction Results\n")
                f.write(f"Total Formulas: {len(results)}\n\n")
                
                current_page = -1
                for item in results:
                    page = item['page_no']
                    if page != current_page:
                        f.write(f"## Page {page}\n\n")
                        current_page = page
                    
                    f.write(f"### Formula {item['formula_index']}\n")
                    f.write(f"**Image:** `{item['image_name']}`\n\n")
                    f.write(f"$$ \n{item['latex']}\n $$\n\n")
                    f.write(f"---\n\n")
                    
            print(f"Successfully saved Markdown to {output_formula_latex_md_path}")
        except Exception as e:
            print(f"Error saving Markdown: {e}")


def main():
    parser = argparse.ArgumentParser(description="Extract and transcribe formulas from PDF manuscript.")
    
    parser.add_argument("pdf_path", help="Path to the original PDF file")
    parser.add_argument("parsed_json_path", help="Path to the Docling parsed JSON file")
    parser.add_argument("output_manuscript_png_folder", help="Output folder for full page PNGs")
    parser.add_argument("output_formula_png_folder", help="Output folder for cropped formula PNGs")
    parser.add_argument("output_formula_latex_json_path", help="Path for the final output JSON file")
    parser.add_argument("--output_formula_latex_md_path", help="Optional path for the final output Markdown file", default=None)
    
    args = parser.parse_args()
    
    orchestrate_extraction(
        args.pdf_path,
        args.parsed_json_path,
        args.output_manuscript_png_folder,
        args.output_formula_png_folder,
        args.output_formula_latex_json_path,
        args.output_formula_latex_md_path
    )

if __name__ == "__main__":
    main()
