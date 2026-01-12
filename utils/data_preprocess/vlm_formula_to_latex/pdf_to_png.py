import argparse
import os
import sys
from pdf2image import convert_from_path

def convert_pdf_to_png(pdf_path, output_folder):
    """
    Converts a PDF file to a series of PNG images, one per page.

    Args:
        pdf_path (str): Path to the input PDF file.
        output_folder (str): Path to the output directory where images will be saved.
    """
    if not os.path.exists(pdf_path):
        print(f"Error: PDF file not found at {pdf_path}")
        sys.exit(1)

    # Create output directory if it doesn't exist
    if not os.path.exists(output_folder):
        try:
            os.makedirs(output_folder)
            print(f"Created output directory: {output_folder}")
        except OSError as e:
            print(f"Error creating output directory: {e}")
            sys.exit(1)

    print(f"Converting '{pdf_path}' to PNGs in '{output_folder}'...")

    try:
        # Convert PDF to list of images
        # using a default dpi of 200 for reasonable quality/size trade-off
        images = convert_from_path(pdf_path, dpi=450)

        for i, image in enumerate(images):
            # Page numbers usually start at 1
            page_number = i + 1
            image_name = f"page_{page_number}.png"
            image_path = os.path.join(output_folder, image_name)
            
            image.save(image_path, "PNG")
            print(f"Saved {image_name}")

        print(f"Successfully converted {len(images)} pages.")

    except Exception as e:
        print(f"An error occurred during conversion: {e}")
        # Hint about poppler usage if that is likely the cause (common issue with pdf2image)
        if "poppler" in str(e).lower():
            print("Hint: Ensure poppler-utils is installed on your system.")
            print("For Ubuntu/Debian: sudo apt-get install poppler-utils")
            print("For MacOS: brew install poppler")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Convert PDF pages to PNG images.")
    parser.add_argument("input_pdf", help="Path to the input PDF file")
    parser.add_argument("output_folder", help="Path to the folder where PNGs will be saved")

    args = parser.parse_args()

    convert_pdf_to_png(args.input_pdf, args.output_folder)

if __name__ == "__main__":
    main()
