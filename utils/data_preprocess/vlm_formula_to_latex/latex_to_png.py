import os
import sys
import subprocess
import tempfile
import json
from pdf2image import convert_from_path
from typing import Optional

def render_latex_to_png(latex_code: str, output_file: str, dpi: int = 300) -> bool:
    """
    Renders LaTeX code to PNG using pdflatex and pdf2image.
    
    Args:
        latex_code (str): The LaTeX code to render
        output_file (str): Path to save the output PNG
        dpi (int): DPI for the output image (default: 300)
        
    Returns:
        bool: True if successful, False otherwise
    """
    # Create a temporary directory for intermediate files
    with tempfile.TemporaryDirectory() as temp_dir:
        # 1. Wrap the snippet in a standalone document class
        # 'standalone' automatically crops the page to the content size
        tex_template = r"""
\documentclass[preview,border=2pt]{standalone}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{amsfonts}
\usepackage{mathtools}
\begin{document}
%s
\end{document}
""" % latex_code

        # 2. Write to a .tex file in temp directory
        tex_file = os.path.join(temp_dir, "temp.tex")
        pdf_file = os.path.join(temp_dir, "temp.pdf")
        
        try:
            with open(tex_file, "w", encoding="utf-8") as f:
                f.write(tex_template)
        except Exception as e:
            print(f"Error writing LaTeX file: {e}")
            return False

        # 3. Compile using system pdflatex
        try:
            result = subprocess.run(
                ["pdflatex", "-interaction=nonstopmode", "-output-directory", temp_dir, tex_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30
            )
            
            # Check if PDF was created
            if not os.path.exists(pdf_file):
                print(f"Error: pdflatex failed to create PDF")
                print(f"LaTeX code: {latex_code[:100]}...")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"Error: pdflatex timed out")
            return False
        except FileNotFoundError:
            print(f"Error: pdflatex not found. Please install texlive or mactex.")
            return False
        except Exception as e:
            print(f"Error running pdflatex: {e}")
            return False

        # 4. Convert PDF to PNG using pdf2image
        try:
            images = convert_from_path(pdf_file, dpi=dpi)
            if images:
                # Ensure output directory exists
                output_dir = os.path.dirname(output_file)
                if output_dir and not os.path.exists(output_dir):
                    os.makedirs(output_dir, exist_ok=True)
                    
                images[0].save(output_file, "PNG")
                return True
            else:
                print(f"Error: No images generated from PDF")
                return False
        except Exception as e:
            print(f"Error converting PDF to PNG: {e}")
            return False


def batch_render_formulas(json_path: str, output_folder: str, dpi: int = 300):
    """
    Batch renders all formulas from a JSON file to PNG images.
    
    Args:
        json_path (str): Path to the formula_latex.json file
        output_folder (str): Folder to save the rendered PNG images
        dpi (int): DPI for the output images (default: 300)
    """
    if not os.path.exists(json_path):
        raise FileNotFoundError(f"JSON file not found: {json_path}")
    
    # Load the JSON data
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            formulas = json.load(f)
    except Exception as e:
        raise ValueError(f"Error loading JSON: {e}")
    
    # Create output folder if it doesn't exist
    os.makedirs(output_folder, exist_ok=True)
    
    print(f"Rendering {len(formulas)} formulas to PNG...")
    
    success_count = 0
    fail_count = 0
    
    for formula in formulas:
        latex_code = formula.get('latex', '')
        image_name = formula.get('image_name', '')
        
        # Skip empty LaTeX
        if not latex_code or latex_code.strip() == '':
            print(f"Skipping {image_name}: Empty LaTeX code")
            fail_count += 1
            continue
        
        # Generate output filename (same as original image name)
        output_file = os.path.join(output_folder, image_name)
        
        # Render the LaTeX to PNG
        success = render_latex_to_png(latex_code, output_file, dpi=dpi)
        
        if success:
            success_count += 1
            print(f"✓ Rendered: {image_name}")
        else:
            fail_count += 1
            print(f"✗ Failed: {image_name}")
    
    print(f"\nRendering complete:")
    print(f"  Success: {success_count}")
    print(f"  Failed: {fail_count}")
    print(f"  Total: {len(formulas)}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 latex_to_png.py <formula_latex.json> <output_folder> [dpi]")
        print("Example: python3 latex_to_png.py formula_latex.json ./png/ 300")
        sys.exit(1)
    
    json_path = sys.argv[1]
    output_folder = sys.argv[2]
    dpi = int(sys.argv[3]) if len(sys.argv) > 3 else 300
    
    try:
        batch_render_formulas(json_path, output_folder, dpi)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
