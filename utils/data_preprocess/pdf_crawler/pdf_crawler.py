#!/usr/bin/env python3
"""
PDF Crawler using Docling
Extracts structured content from PDF files and outputs as JSON.
"""

import argparse
import json
from pathlib import Path
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling.datamodel.pipeline_options import PdfPipelineOptions, EasyOcrOptions
from docling.datamodel.base_models import InputFormat


def crawl_pdf(pdf_path, output_path=None, extract_formulas=True):
    """
    Extract content from PDF using Docling and save as JSON.
    
    Args:
        pdf_path (str or Path): Path to the PDF file
        output_path (str or Path, optional): Output JSON file path
        extract_formulas (bool): Enable formula extraction as LaTeX
    
    Returns:
        dict: Extracted document content
    """
    pdf_path = Path(pdf_path)
    
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF file not found: {pdf_path}")
    
    print(f"Processing PDF: {pdf_path}")
    if extract_formulas:
        print("Formula extraction: Enabled (will extract equations as LaTeX)")
    print("-" * 60)
    
    # Configure pipeline options
    pipeline_options = PdfPipelineOptions()
    pipeline_options.do_ocr = True
    pipeline_options.do_table_structure = True
    pipeline_options.do_formula_enrichment = extract_formulas
    pipeline_options.generate_page_images = True
    pipeline_options.generate_picture_images = True
    
    # Initialize Docling converter with options
    converter = DocumentConverter(
        format_options={
            InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
        }
    )
    
    # Convert PDF to document
    result = converter.convert(str(pdf_path))
    
    # Export to dict
    doc_dict = result.document.export_to_dict()
    
    # Export to markdown to get LaTeX formulas
    markdown_content = result.document.export_to_markdown()
    
    # Add markdown version to the output for LaTeX formulas
    doc_dict['markdown'] = markdown_content
    
    # Determine output path
    if output_path is None:
        output_path = pdf_path.parent / f"{pdf_path.stem}_parsed.json"
    else:
        output_path = Path(output_path)
    
    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Save to JSON
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(doc_dict, f, indent=2, ensure_ascii=False)
    
    # Also save markdown version for easy LaTeX formula access
    markdown_path = output_path.parent / f"{output_path.stem}.md"
    with open(markdown_path, 'w', encoding='utf-8') as f:
        f.write(markdown_content)

    # Save generated images
    if pipeline_options.generate_page_images:
        pages_dir = output_path.parent / "page_images"
        pages_dir.mkdir(parents=True, exist_ok=True)
        for page_no, page in result.document.pages.items():
            if page.image:
                page.image.save(pages_dir / f"page_{page_no}.png")
        print(f"✓ Saved page images to: {pages_dir.absolute()}")

    if pipeline_options.generate_picture_images:
        try:
            images_dir = output_path.parent / "extracted_images"
            images_dir.mkdir(parents=True, exist_ok=True)
            saved_imgs = 0
            for item, _ in result.document.iterate_items():
                if hasattr(item, "image") and item.image:
                     item.image.save(images_dir / f"img_{saved_imgs}.png")
                     saved_imgs += 1
            print(f"✓ Saved {saved_imgs} extracted images to: {images_dir.absolute()}")
        except Exception as e:
            print(f"⚠ Failed to save extracted images: {e}")
    
    print(f"\n✓ Successfully parsed PDF")
    print(f"✓ Output saved to: {output_path.absolute()}")
    print(f"✓ Markdown with LaTeX formulas: {markdown_path.absolute()}")
    
    # Print summary
    if 'text' in doc_dict:
        text_length = len(doc_dict['text'])
        print(f"✓ Extracted {text_length:,} characters")
    
    if 'pages' in doc_dict:
        page_count = len(doc_dict['pages'])
        print(f"✓ Processed {page_count} pages")
    
    return doc_dict


def main():
    """Main function to run the PDF crawler."""
    parser = argparse.ArgumentParser(
        description='Extract content from PDF files using Docling.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python pdf_crawler.py input.pdf
  python pdf_crawler.py input.pdf -o output.json
  python pdf_crawler.py "data/Project/Manuscript.pdf"
        '''
    )
    
    parser.add_argument(
        'pdf_path',
        type=str,
        help='Path to the PDF file to process'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=str,
        default=None,
        help='Output JSON file path (default: same name as PDF with _parsed.json suffix)'
    )
    
    parser.add_argument(
        '--no-formulas',
        action='store_true',
        help='Disable formula extraction (faster processing)'
    )
    
    args = parser.parse_args()
    
    try:
        crawl_pdf(args.pdf_path, args.output, extract_formulas=not args.no_formulas)
    except Exception as e:
        print(f"\n✗ Error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
