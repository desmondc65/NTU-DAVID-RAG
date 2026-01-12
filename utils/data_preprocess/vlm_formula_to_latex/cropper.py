import json
import os
import sys
from PIL import Image

def crop_formulas(json_path, png_folder, output_folder):
    """
    Crops formula images from page PNGs based on bounding boxes in a JSON file.

    Args:
        json_path (str): Path to the parsed Docling JSON file.
        png_folder (str): Path to the folder containing page PNGs (named page_x.png).
        output_folder (str): Path to saving the cropped formula images.
    """
    if not os.path.exists(json_path):
        print(f"Error: JSON file not found at {json_path}")
        sys.exit(1)

    if not os.path.exists(png_folder):
        print(f"Error: PNG folder not found at {png_folder}")
        sys.exit(1)

    if not os.path.exists(output_folder):
        os.makedirs(output_folder, exist_ok=True)
        print(f"Created output directory: {output_folder}")

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        sys.exit(1)

    # Check for 'text' or 'texts' key or if root is list
    content_list = []
    if isinstance(data, dict):
        if "text" in data:
            content_list = data["text"]
        elif "texts" in data:
            content_list = data["texts"]
        else:
            # Fallback: maybe specific docling structure
            print("Warning: Could not find 'text' or 'texts' key in JSON. Checking keys...")
            print(f"Keys found: {list(data.keys())}")
            return
    elif isinstance(data, list):
        content_list = data
    
    # Dictionary to track formula count per page: page_no -> count
    page_formula_counts = {}

    # PDF DPI vs Image DPI
    # Standard PDF point is 1/72 inch.
    # The generated PNGs are 450 DPI.
    PROJECT_DPI = 450
    PDF_POINT_DPI = 72
    SCALE_FACTOR = PROJECT_DPI / PDF_POINT_DPI

    print(f"Processing {len(content_list)} items...")
    
    processed_count = 0
    
    for item in content_list:
        if item.get("label") == "formula":
            # "prov" is quite likely 'prov' as mentioned by user (or 'provenance')
            # User said: use "bbox" in "prove" (likely typo for prov)
            provenance = item.get("prov", [])
            
            # Handle if provenance is a single dict instead of list (rare but possible)
            if isinstance(provenance, dict):
                provenance = [provenance]
            
            for prov_entry in provenance:
                page_no = prov_entry.get("page_no")
                bbox = prov_entry.get("bbox")
                
                if page_no is None or bbox is None:
                    continue
                
                # Update counters
                if page_no not in page_formula_counts:
                    page_formula_counts[page_no] = 0
                page_formula_counts[page_no] += 1
                formula_idx = page_formula_counts[page_no]
                
                # Image Path
                image_name = f"page_{page_no}.png"
                image_path = os.path.join(png_folder, image_name)
                
                if not os.path.exists(image_path):
                    print(f"Warning: Image file {image_name} not found for formula on page {page_no}. Skipping.")
                    continue
                
                try:
                    with Image.open(image_path) as img:
                        width, height = img.size
                        
                        # Handle Dict bbox (Docling v2) or List bbox (Docling v1)
                        if isinstance(bbox, dict):
                            l = bbox.get('l', 0)
                            t = bbox.get('t', 0)
                            r = bbox.get('r', 0)
                            b = bbox.get('b', 0)
                            coord_origin = bbox.get('coord_origin', 'BOTTOMLEFT')
                            
                            # If origin is BOTTOMLEFT, we must flip Y-axis
                            # PDF Bottom-Left (0,0) -> Image Top-Left (0,0)
                            # t (top) in PDF is further from 0, so it's numerically larger than b (bottom)
                            # But in Image coords (Top-Left), top is numerically smaller than bottom.
                            
                            if coord_origin == "BOTTOMLEFT":
                                # PDF coords:
                                # y=0 is bottom, y=MAX is top.
                                # t is "top" Y value (e.g. 700), b is "bottom" Y value (e.g. 650)
                                # To convert to Image (Top-Left 0):
                                # new_y = PAGE_HEIGHT - old_y
                                
                                # Attempt to find page dimensions from Docling JSON
                                # Docling JSON usually has a "pages" dict: { "1": { "size": {"width": ..., "height": ...} } }
                                # or similar structure.
                                # Let's try to lookup the page height for this page_no.
                                true_pdf_height = None
                                
                                # Access 'pages' from the root 'data' object captured in outer scope
                                if isinstance(data, dict) and "pages" in data:
                                    # pages keys might be strings or ints
                                    p_key = str(page_no)
                                    if p_key in data["pages"]:
                                        p_data = data["pages"][p_key]
                                        if "size" in p_data:
                                             true_pdf_height = p_data["size"].get("height")
                                        elif "height" in p_data:
                                             true_pdf_height = p_data.get("height")

                                if true_pdf_height:
                                     # Scale factor is still needed to go from PDF points to Image Pixels
                                     # But we should rely on the ratio of ImageHeight / PDFHeight if we want to be exact
                                     # instead of assuming 72 DPI vs 450 DPI, although they should match if generated correctly.
                                     
                                     # Recalculate scale factor precisely for this page
                                     current_scale = height / true_pdf_height
                                     pdf_height_pt = true_pdf_height
                                else:
                                     # Fallback to fixed DPI assumption
                                     # PDF points (72dpi) -> Image (450dpi)
                                     current_scale = SCALE_FACTOR
                                     pdf_height_pt = height / current_scale

                                # Convert Bottom-Origin Y to Top-Origin Y
                                img_t = (pdf_height_pt - t) * current_scale
                                img_b = (pdf_height_pt - b) * current_scale
                                
                                # Assign to final crop variables (t must be < b in image coords)
                                # In bottom-origin: t is usually > b (e.g. 700 vs 600)
                                # (Height - 700) is smaller than (Height - 600). So img_t < img_b. 
                                # Correct.
                                final_t = img_t
                                final_b = img_b
                                
                                # scale x directly
                                final_l = l * current_scale
                                final_r = r * current_scale
                                
                            else:
                                # Default to TOPLEFT behavior
                                final_l = l * SCALE_FACTOR
                                final_t = t * SCALE_FACTOR
                                final_r = r * SCALE_FACTOR
                                final_b = b * SCALE_FACTOR
                                
                        else:
                            # List fallback (previous logic)
                            l, t, r, b = bbox[:4]
                            final_l = l * SCALE_FACTOR
                            final_t = t * SCALE_FACTOR
                            final_r = r * SCALE_FACTOR
                            final_b = b * SCALE_FACTOR

                        # Cast to int
                        final_l = int(final_l)
                        final_t = int(final_t)
                        final_r = int(final_r)
                        final_b = int(final_b)

                        # Add Padding
                        PADDING_PX = 20
                        final_l -= PADDING_PX
                        final_t -= PADDING_PX
                        final_r += PADDING_PX
                        final_b += PADDING_PX

                        # Validate and fix boundaries
                        final_l = max(0, final_l)
                        final_t = max(0, final_t)
                        final_r = min(width, final_r)
                        final_b = min(height, final_b)
                        
                        # Ensure Top < Bottom and Left < Right
                        if final_t > final_b:
                            final_t, final_b = final_b, final_t
                        if final_l > final_r:
                            final_l, final_r = final_r, final_l

                        if final_l >= final_r or final_t >= final_b:
                             print(f"Warning: Invalid crop dimensions for page {page_no}, formula {formula_idx}: l={final_l}, t={final_t}, r={final_r}, b={final_b}")
                             continue

                        cropped_img = img.crop((final_l, final_t, final_r, final_b))
                        
                        # Save
                        out_name = f"page_{page_no}_formula_{formula_idx}.png"
                        out_path = os.path.join(output_folder, out_name)
                        cropped_img.save(out_path)
                        processed_count += 1
                        
                except Exception as e:
                    print(f"Failed to process formula on page {page_no}: {e}")
                    # traceback.print_exc()

    print(f"Done. Cropped {processed_count} formulas.")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 cropper.py <json_path> <png_folder> <output_folder>")
        sys.exit(1)
    
    crop_formulas(sys.argv[1], sys.argv[2], sys.argv[3])
