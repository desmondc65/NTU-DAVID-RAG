#!/bin/bash

# PDF Crawler Script
# Parses multiple PDF files and saves to their respective manuscript_parsed_docling directories
# Usage: ./pdf_crawler.sh [--skip-existing]

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Activate virtual environment
source "${PROJECT_ROOT}/.venv/bin/activate"

PDF_CRAWLER_PY="${SCRIPT_DIR}/pdf_crawler.py"

# Base data directory
DATA_DIR="${PROJECT_ROOT}/data"

# Parse arguments
SKIP_EXISTING=false

for arg in "$@"; do
    case $arg in
        --skip-existing)
        SKIP_EXISTING=true
        shift # Remove --skip-existing from processing
        ;;
    esac
done

echo "================================================"
echo "PDF Crawler - Processing manuscripts"
echo "================================================"
echo ""

# Iterate over each directory in data
for paper_dir in "$DATA_DIR"/*; do
    if [ -d "$paper_dir" ]; then
        paper_name=$(basename "$paper_dir")
        
        # 1. Find PDF in source/
        SOURCE_DIR="$paper_dir/source"
        if [ ! -d "$SOURCE_DIR" ]; then
             # echo "  [Skipping] 'source' directory not found in $paper_name"
             continue
        fi
        
        # Taking the first PDF found
        PDF_FILE=$(find "$SOURCE_DIR" -maxdepth 1 -name "Manuscript.pdf" | head -n 1)

        if [[ -z "$PDF_FILE" ]]; then
            # echo "  [Skipping] No PDF file found in $SOURCE_DIR for $paper_name"
            continue
        fi
        
        # 2. Define Output Paths
        OUTPUT_DIR="$paper_dir/manuscript_parsed_docling"
        OUTPUT_JSON="${OUTPUT_DIR}/Manuscript_parsed_docling.json"
        OUTPUT_MD="${OUTPUT_DIR}/Manuscript_parsed_docling.md"
        
        echo "Processing: $paper_name"

        # 3. Check Skip Condition
        if [ "$SKIP_EXISTING" = true ]; then
            if [ -f "$OUTPUT_JSON" ] && [ -f "$OUTPUT_MD" ]; then
                echo "  [Skipping] Output files already exist (JSON & MD)."
                echo ""
                continue
            fi
        fi

        # 4. Run Crawler
        mkdir -p "$OUTPUT_DIR"
        echo "  Input PDF: $PDF_FILE"
        echo "  Output JSON: $OUTPUT_JSON"
        
        # We use the python interpeter from venv explicitly or rely on 'python3' if venv activated
        # Using explicit path is safer in scripts
        "${PROJECT_ROOT}/.venv/bin/python3" "$PDF_CRAWLER_PY" "$PDF_FILE" -o "$OUTPUT_JSON"
        
        echo ""
    fi
done

echo "================================================"
echo "✓ PDF crawling complete!"
echo "================================================"
