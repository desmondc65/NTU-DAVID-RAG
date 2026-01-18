import os
import sys
import json
import base64
from typing import List, Dict

def image_to_base64(image_path: str) -> str:
    """Convert image to base64 string for embedding in HTML."""
    try:
        with open(image_path, 'rb') as f:
            return base64.b64encode(f.read()).decode('utf-8')
    except Exception as e:
        print(f"Error encoding image {image_path}: {e}")
        return ""


def generate_comparison_html(
    json_path: str,
    original_folder: str,
    transcribed_folder: str,
    output_html: str,
    docling_formulas: List[Dict] = None,
    docling_png_folder: str = None
):
    """
    Generates an HTML file comparing original, VLM transcribed, and Docling formula images.
    
    Args:
        json_path (str): Path to formula_latex.json
        original_folder (str): Folder containing original formula PNGs
        transcribed_folder (str): Folder containing VLM transcribed formula PNGs
        output_html (str): Path to save the output HTML file
        docling_formulas (List[Dict], optional): List of Docling formulas with metadata
        docling_png_folder (str, optional): Folder containing Docling rendered PNGs
    """
    # Load formula data
    if not os.path.exists(json_path):
        raise FileNotFoundError(f"JSON file not found: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        formulas = json.load(f)
    
    # Load cost information if available
    cost_data = None
    cost_json_path = os.path.join(os.path.dirname(json_path), "accumulated_cost.json")
    if os.path.exists(cost_json_path):
        try:
            with open(cost_json_path, 'r', encoding='utf-8') as f:
                cost_data = json.load(f)
        except Exception as e:
            print(f"Warning: Could not load cost data: {e}")

    
    # Start building HTML
    html_content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Formula Transcription Quality Comparison</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 40px 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        h1 {
            color: white;
            text-align: center;
            margin-bottom: 40px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        
        .stats {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            gap: 20px;
        }
        
        .stat-item {
            text-align: center;
        }
        
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
        
        .comparison-grid {
            display: grid;
            gap: 30px;
        }
        
        .comparison-card {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .comparison-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 48px rgba(0,0,0,0.15);
        }
        
        .card-header {
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }
        
        .card-title {
            font-size: 1.3em;
            color: #333;
            margin-bottom: 5px;
        }
        
        .card-meta {
            color: #999;
            font-size: 0.9em;
        }
        
        .image-comparison {
            display: grid;
            grid-template-columns: 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .image-box {
            text-align: center;
        }
        
        .image-label {
            font-weight: 600;
            color: #555;
            margin-bottom: 10px;
            font-size: 1.1em;
        }
        
        .image-container {
            background: #f8f9fa;
            border: 2px solid #e9ecef;
            border-radius: 8px;
            padding: 20px;
            min-height: 150px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .image-container img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
        }
        
        .missing-image {
            color: #dc3545;
            font-style: italic;
        }
        
        .latex-code {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 15px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            overflow-x: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        
        .latex-label {
            font-weight: 600;
            color: #555;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Formula Transcription Quality Comparison</h1>
        
        <div class="stats">
            <div class="stat-item">
                <div class="stat-value">{total_formulas}</div>
                <div class="stat-label">Total Formulas</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">{success_count}</div>
                <div class="stat-label">Successfully Rendered</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">{fail_count}</div>
                <div class="stat-label">Failed to Render</div>
            </div>
            {cost_stats}
        </div>

        
        <div class="comparison-grid">
"""
    
    success_count = 0
    fail_count = 0
    
    # Create a lookup for Docling formulas by page
    docling_by_page = {}
    if docling_formulas:
        for df in docling_formulas:
            page = df.get('page_no', -1)
            if page not in docling_by_page:
                docling_by_page[page] = []
            docling_by_page[page].append(df)
    
    # Generate comparison cards
    for formula in formulas:
        image_name = formula.get('image_name', '')
        latex_code = formula.get('latex', '')
        page_no = formula.get('page_no', 'N/A')
        formula_idx = formula.get('formula_index', 'N/A')
        
        original_path = os.path.join(original_folder, image_name)
        transcribed_path = os.path.join(transcribed_folder, image_name)
        
        # Check if images exist
        original_exists = os.path.exists(original_path)
        transcribed_exists = os.path.exists(transcribed_path)
        
        if transcribed_exists:
            success_count += 1
        else:
            fail_count += 1
        
        # Encode images to base64
        original_b64 = image_to_base64(original_path) if original_exists else ""
        transcribed_b64 = image_to_base64(transcribed_path) if transcribed_exists else ""
        
        # Find matching Docling formula
        docling_match = None
        docling_b64 = ""
        docling_latex = ""
        
        if page_no in docling_by_page and isinstance(formula_idx, int):
            docling_on_page = docling_by_page[page_no]
            if 0 <= formula_idx - 1 < len(docling_on_page):
                docling_match = docling_on_page[formula_idx - 1]
                docling_latex = docling_match.get('latex', '')
                rendered_filename = docling_match.get('rendered_filename')
                if rendered_filename and docling_png_folder:
                    docling_path = os.path.join(docling_png_folder, rendered_filename)
                    if os.path.exists(docling_path):
                        docling_b64 = image_to_base64(docling_path)
        
        # Build card HTML
        html_content += f"""
            <div class="comparison-card">
                <div class="card-header">
                    <div class="card-title">Formula {formula_idx}</div>
                    <div class="card-meta">Page {page_no} • {image_name}</div>
                </div>
                
                <div class="image-comparison">
                    <div class="image-box">
                        <div class="image-label">Original</div>
                        <div class="image-container">
"""
        
        if original_exists and original_b64:
            html_content += f'                            <img src="data:image/png;base64,{original_b64}" alt="Original formula">\n'
        else:
            html_content += '                            <div class="missing-image">Image not found</div>\n'
        
        html_content += """                        </div>
                    </div>
                    
                    <div class="image-box">
                        <div class="image-label">VLM Transcribed (VLM → LaTeX → PNG)</div>
                        <div class="image-container">
"""
        
        if transcribed_exists and transcribed_b64:
            html_content += f'                            <img src="data:image/png;base64,{transcribed_b64}" alt="VLM transcribed formula">\n'
        else:
            html_content += '                            <div class="missing-image">Rendering failed</div>\n'
        
        html_content += """                        </div>
                    </div>
"""
        
        # Add Docling column if available
        if docling_match:
            html_content += """                    
                    <div class="image-box">
                        <div class="image-label">Docling Extracted (Docling → LaTeX → PNG)</div>
                        <div class="image-container">
"""
            if docling_b64:
                html_content += f'                            <img src="data:image/png;base64,{docling_b64}" alt="Docling extracted formula">\n'
            else:
                html_content += '                            <div class="missing-image">Rendering failed</div>\n'
            
            html_content += """                        </div>
                    </div>
"""
        
        html_content += """                </div>
                
                <div class="latex-label">VLM LaTeX Code:</div>
                <div class="latex-code">{vlm_latex}</div>
""".format(vlm_latex=latex_code if latex_code else 'N/A')
        
        # Add Docling LaTeX if available
        if docling_match and docling_latex:
            html_content += f"""                
                <div class="latex-label" style="margin-top: 15px;">Docling LaTeX Code:</div>
                <div class="latex-code">{docling_latex}</div>
"""
        
        html_content += """            </div>
"""
    
    # Close HTML
    html_content += """        </div>
    </div>
</body>
</html>
"""
    
    # Replace placeholders
    html_content = html_content.replace('{total_formulas}', str(len(formulas)))
    html_content = html_content.replace('{success_count}', str(success_count))
    html_content = html_content.replace('{fail_count}', str(fail_count))
    
    # Generate cost stats HTML if cost data is available
    cost_stats_html = ""
    if cost_data and 'total_cost' in cost_data:
        total_cost = cost_data['total_cost']
        cost_per_formula = total_cost / len(formulas) if len(formulas) > 0 else 0
        
        cost_stats_html = f"""
            <div class="stat-item">
                <div class="stat-value">${total_cost:.4f}</div>
                <div class="stat-label">Total API Cost</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">${cost_per_formula:.4f}</div>
                <div class="stat-label">Cost per Formula</div>
            </div>
        """
    
    html_content = html_content.replace('{cost_stats}', cost_stats_html)

    
    # Ensure output directory exists
    output_dir = os.path.dirname(output_html)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)
    
    # Write HTML file
    with open(output_html, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"✓ Generated comparison HTML: {output_html}")
    print(f"  Total formulas: {len(formulas)}")
    print(f"  Successfully rendered: {success_count}")
    print(f"  Failed to render: {fail_count}")


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python3 generate_comparison.py <formula_latex.json> <original_folder> <transcribed_folder> <output_html>")
        print("Example: python3 generate_comparison.py formula_latex.json ../source/formula_png ./png ./quality_comparison/comparison.html")
        sys.exit(1)
    
    json_path = sys.argv[1]
    original_folder = sys.argv[2]
    transcribed_folder = sys.argv[3]
    output_html = sys.argv[4]
    
    try:
        generate_comparison_html(json_path, original_folder, transcribed_folder, output_html)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
