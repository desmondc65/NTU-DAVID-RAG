import os
import sys
import json
from typing import List, Dict, Tuple

def extract_docling_formulas(docling_json_path: str) -> List[Dict]:
    """
    Extract formulas from Docling parsed JSON.
    
    Args:
        docling_json_path: Path to the Docling JSON file
        
    Returns:
        List of formula dictionaries with metadata
    """
    if not os.path.exists(docling_json_path):
        raise FileNotFoundError(f"Docling JSON not found: {docling_json_path}")
    
    with open(docling_json_path, 'r', encoding='utf-8') as f:
        docling_data = json.load(f)
    
    formulas = []
    
    # Extract formulas from the "texts" section
    texts = docling_data.get('texts', [])
    
    for item in texts:
        if item.get('label') == 'formula':
            # Get LaTeX text
            latex_text = item.get('text', '')
            orig_text = item.get('orig', '')
            
            # Get page number and bounding box from prov
            prov = item.get('prov', [])
            if prov:
                page_no = prov[0].get('page_no', -1)
                bbox = prov[0].get('bbox', {})
            else:
                page_no = -1
                bbox = {}
            
            formulas.append({
                'latex': latex_text,
                'orig': orig_text,
                'page_no': page_no,
                'bbox': bbox,
                'self_ref': item.get('self_ref', '')
            })
    
    return formulas


def match_formulas_by_page_and_position(
    vlm_formulas: List[Dict],
    docling_formulas: List[Dict]
) -> List[Tuple[Dict, Dict]]:
    """
    Match VLM formulas with Docling formulas based on page number and position.
    
    Args:
        vlm_formulas: List of VLM formula dictionaries
        docling_formulas: List of Docling formula dictionaries
        
    Returns:
        List of tuples (vlm_formula, docling_formula or None)
    """
    matched = []
    
    # Group Docling formulas by page
    docling_by_page = {}
    for df in docling_formulas:
        page = df['page_no']
        if page not in docling_by_page:
            docling_by_page[page] = []
        docling_by_page[page].append(df)
    
    # Sort Docling formulas on each page by vertical position (top coordinate)
    for page in docling_by_page:
        docling_by_page[page].sort(key=lambda x: x['bbox'].get('t', 0))
    
    # Match VLM formulas
    for vlm_f in vlm_formulas:
        page = vlm_f.get('page_no', -1)
        formula_idx = vlm_f.get('formula_index', -1)
        
        # Try to match with Docling formula on same page
        docling_match = None
        if page in docling_by_page:
            docling_on_page = docling_by_page[page]
            # Use formula_index to match (assuming they're in same order)
            if 0 <= formula_idx - 1 < len(docling_on_page):
                docling_match = docling_on_page[formula_idx - 1]
        
        matched.append((vlm_f, docling_match))
    
    return matched


def save_matched_formulas(matched: List[Tuple[Dict, Dict]], output_path: str):
    """
    Save matched formulas to JSON for later use.
    
    Args:
        matched: List of (vlm_formula, docling_formula) tuples
        output_path: Path to save the matched formulas JSON
    """
    output_data = []
    
    for vlm_f, docling_f in matched:
        entry = {
            'vlm': vlm_f,
            'docling': docling_f if docling_f else None
        }
        output_data.append(entry)
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"✓ Saved matched formulas to: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python3 extract_docling_formulas.py <vlm_json> <docling_json> <output_json>")
        print("Example: python3 extract_docling_formulas.py formula_latex.json ../../manuscript_parsed_docling/Manuscript_parsed_docling.json matched_formulas.json")
        sys.exit(1)
    
    vlm_json_path = sys.argv[1]
    docling_json_path = sys.argv[2]
    output_json_path = sys.argv[3]
    
    try:
        # Load VLM formulas
        with open(vlm_json_path, 'r', encoding='utf-8') as f:
            vlm_formulas = json.load(f)
        
        # Extract Docling formulas
        docling_formulas = extract_docling_formulas(docling_json_path)
        
        print(f"Found {len(vlm_formulas)} VLM formulas")
        print(f"Found {len(docling_formulas)} Docling formulas")
        
        # Match formulas
        matched = match_formulas_by_page_and_position(vlm_formulas, docling_formulas)
        
        # Save matched formulas
        save_matched_formulas(matched, output_json_path)
        
        print(f"Matched {len(matched)} formulas")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
