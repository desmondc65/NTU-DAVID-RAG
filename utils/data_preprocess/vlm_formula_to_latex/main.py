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
    from cost_utils import cal_gemini_cost, aggregate_costs, save_accumulated_cost
    from latex_to_png import batch_render_formulas, render_latex_to_png
    from generate_comparison import generate_comparison_html
    from extract_docling_formulas import extract_docling_formulas, match_formulas_by_page_and_position
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
            # Call the transcription function with cost tracking
            latex_code, usage_metadata = png_to_latex(img_path, return_cost=True)
            
            # Calculate cost for this formula
            cost_info = None
            if usage_metadata:
                cost_info = cal_gemini_cost(usage_metadata, model_name="gemini-3-flash-preview")
            
            return {
                "page_no": page_no,
                "formula_index": formula_idx,
                "image_name": filename,
                "latex": latex_code,
                "cost_info": cost_info
            }
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            return None

    # Use ThreadPoolExecutor for parallel processing
    from concurrent.futures import ThreadPoolExecutor, as_completed
    from tqdm import tqdm

    results = []
    cost_list = []
    # Adjust max_workers as needed. Gemini has rate limits, so don't set this too high (e.g., 5-10 is usually safe).
    MAX_WORKERS = 10 
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # Submit all tasks
        future_to_file = {executor.submit(process_single_image, f): f for f in formula_files}
        
        # Process as they complete (with progress bar)
        for future in tqdm(as_completed(future_to_file), total=total_formulas, desc="Transcribing"):
            res = future.result()
            if res:
                # Collect cost information
                if res.get('cost_info'):
                    cost_list.append(res['cost_info'])
                # Remove cost_info from results before saving to JSON
                cost_info = res.pop('cost_info', None)
                results.append(res)
    
    # Sort results by page_no then formula_index because parallel execution scrambles order
    results.sort(key=lambda x: (x['page_no'], x['formula_index']))
    
    # Ensure directory exists for output json (needed for cost logs)
    output_json_dir = os.path.dirname(os.path.abspath(output_formula_latex_json_path))
    if not os.path.exists(output_json_dir):
        os.makedirs(output_json_dir, exist_ok=True)
    
    # Display cost summary
    if cost_list:
        print("\n" + "="*50)
        print("💰 Cost Summary")
        print("="*50)
        aggregated_cost = aggregate_costs(cost_list)
        print(f"🛠️  Model: {aggregated_cost['model_name']}")
        print(f"📊 Total formulas processed: {len(results)}")
        print(f"📥 Total input tokens: {aggregated_cost['prompt_tokens']:,}")
        print(f"📤 Total output tokens: {aggregated_cost['output_tokens']:,}")
        print(f"💵 Total input cost: ${aggregated_cost['input_cost']:.6f}")
        print(f"💵 Total output cost: ${aggregated_cost['output_cost']:.6f}")
        print(f"💰 Total cost: ${aggregated_cost['total_cost']:.6f}")
        print("="*50 + "\n")
        
        # Save cost information to file
        cost_log_path = os.path.join(output_json_dir, "cost_info.log")
        try:
            with open(cost_log_path, 'w', encoding='utf-8') as f:
                f.write("="*50 + "\n")
                f.write("💰 VLM Formula to LaTeX - Cost Summary\n")
                f.write("="*50 + "\n")
                f.write(f"Model: {aggregated_cost['model_name']}\n")
                f.write(f"Total formulas processed: {len(results)}\n")
                f.write(f"Total input tokens: {aggregated_cost['prompt_tokens']:,}\n")
                f.write(f"Total output tokens: {aggregated_cost['output_tokens']:,}\n")
                f.write(f"Total input cost: ${aggregated_cost['input_cost']:.6f}\n")
                f.write(f"Total output cost: ${aggregated_cost['output_cost']:.6f}\n")
                f.write(f"Total cost: ${aggregated_cost['total_cost']:.6f}\n")
                f.write("="*50 + "\n")
            print(f"💾 Cost information saved to: {cost_log_path}")
        except Exception as e:
            print(f"Warning: Could not save cost log: {e}")
        
        # Save accumulated cost to JSON
        cost_json_path = os.path.join(output_json_dir, "accumulated_cost.json")
        try:
            save_accumulated_cost(cost_json_path, aggregated_cost['total_cost'])
        except Exception as e:
            print(f"Warning: Could not save accumulated cost JSON: {e}")
            
    # 4. Save to JSON
    print("\n[Step 4/4] Saving results to JSON...")
        
    try:
        with open(output_formula_latex_json_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"Successfully saved {len(results)} formulas to {output_formula_latex_json_path}")
    except Exception as e:
        print(f"Error saving JSON: {e}")
        sys.exit(1)

    # 5. Save to Markdown (Optional)
    if output_formula_latex_md_path:
        print(f"\n[Step 5/9] Saving results to Markdown: {output_formula_latex_md_path}...")
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
    
    # 6. Render VLM LaTeX back to PNG for quality comparison
    print(f"\n[Step 6/9] Rendering VLM LaTeX back to PNG...")
    output_png_folder = os.path.join(output_json_dir, "png")
    try:
        batch_render_formulas(output_formula_latex_json_path, output_png_folder, dpi=300)
        print(f"Successfully rendered VLM formulas to {output_png_folder}")
    except Exception as e:
        print(f"Error rendering VLM LaTeX to PNG: {e}")
        print(f"Skipping quality comparison generation.")
        return
    
    # 7. Extract Docling formulas
    print(f"\n[Step 7/9] Extracting Docling formulas...")
    try:
        docling_formulas = extract_docling_formulas(parsed_json_path)
        print(f"Found {len(docling_formulas)} Docling formulas")
    except Exception as e:
        print(f"Warning: Could not extract Docling formulas: {e}")
        docling_formulas = []
    
    # 8. Render Docling LaTeX to PNG
    docling_png_folder = os.path.join(output_json_dir, "docling_png")
    if docling_formulas:
        print(f"\n[Step 8/9] Rendering Docling LaTeX to PNG...")
        os.makedirs(docling_png_folder, exist_ok=True)
        
        docling_success = 0
        docling_fail = 0
        
        for i, formula in enumerate(docling_formulas):
            latex_code = formula.get('latex', '')
            page_no = formula.get('page_no', -1)
            
            if not latex_code:
                docling_fail += 1
                continue
            
            # Generate filename matching VLM format: page_{page_no}_formula_{idx}.png
            # We'll use sequential numbering per page
            output_file = os.path.join(docling_png_folder, f"page_{page_no}_docling_{i+1}.png")
            
            success = render_latex_to_png(latex_code, output_file, dpi=300)
            if success:
                docling_success += 1
                formula['rendered_filename'] = os.path.basename(output_file)
            else:
                docling_fail += 1
                formula['rendered_filename'] = None
        
        print(f"Rendered {docling_success}/{len(docling_formulas)} Docling formulas successfully")
    else:
        print(f"\n[Step 8/9] Skipping Docling rendering (no formulas found)")
    
    # 9. Generate three-way quality comparison HTML
    print(f"\n[Step 9/9] Generating three-way quality comparison HTML...")
    comparison_folder = os.path.join(output_json_dir, "quality_comparison")
    comparison_html = os.path.join(comparison_folder, "comparison.html")
    try:
        generate_comparison_html(
            output_formula_latex_json_path,
            output_formula_png_folder,
            output_png_folder,
            comparison_html,
            docling_formulas=docling_formulas,
            docling_png_folder=docling_png_folder
        )
        print(f"Successfully generated comparison HTML at {comparison_html}")
        print(f"\n🎉 Pipeline complete! Open the comparison HTML in your browser to review transcription quality.")
    except Exception as e:
        print(f"Error generating comparison HTML: {e}")


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
