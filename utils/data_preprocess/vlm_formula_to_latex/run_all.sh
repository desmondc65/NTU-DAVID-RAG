#!/bin/bash

# Determine the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Define paths
DATA_DIR="${PROJECT_ROOT}/data"
SCRIPT_PATH="${SCRIPT_DIR}/main.py"
PYTHON_EXEC="${PROJECT_ROOT}/.venv/bin/python3"

# Check if python exec exists, fallback to python3 if not
if [ ! -f "$PYTHON_EXEC" ]; then
    PYTHON_EXEC="python3"
fi

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Python script not found at $SCRIPT_PATH"
    exit 1
fi

echo "Starting batch processing of papers in $DATA_DIR..."

# Parse arguments
SKIP_EXISTING=false
TARGET_FOLDER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-existing)
            SKIP_EXISTING=true
            shift # Remove --skip-existing from processing
            ;;
        --target-folder)
            TARGET_FOLDER="$2"
            shift # Remove --target-folder
            shift # Remove the value
            ;;
        *)
            shift # Unknown option
            ;;
    esac
done

# Iterate over each directory in data
for paper_dir in "$DATA_DIR"/*; do
    if [ -d "$paper_dir" ]; then
        paper_name=$(basename "$paper_dir")
        
        # Check if we should process this folder
        if [ -n "$TARGET_FOLDER" ] && [ "$paper_name" != "$TARGET_FOLDER" ]; then
            continue
        fi

        echo "==================================================="
        echo "Processing: $paper_name"
        
        # Define Output Paths early to check for existence
        SOURCE_DIR="$paper_dir/source"
        OUTPUT_DIR="$paper_dir/vlm_formula_latex"
        JSON_OUTPUT="$OUTPUT_DIR/formula_latex.json"

        if [ "$SKIP_EXISTING" = true ] && [ -f "$JSON_OUTPUT" ]; then
            echo "  [Skipping] Output already exists at $JSON_OUTPUT"
            continue
        fi
        
        # 1. Find PDF in source/
        # Assumes there is at least one PDF, takes the first one found.
        if [ ! -d "$SOURCE_DIR" ]; then
             echo "  [Skipping] 'source' directory not found in $paper_dir"
             continue
        fi
        
        PDF_FILE=$(find "$SOURCE_DIR" -maxdepth 1 -name "Manuscript.pdf" | head -n 1)
        
        # 2. Find JSON in manuscript_parsed_docling/
        DOCLING_DIR="$paper_dir/manuscript_parsed_docling"
        if [ ! -d "$DOCLING_DIR" ]; then
             echo "  [Skipping] 'manuscript_parsed_docling' directory not found in $paper_dir"
             continue
        fi
        
        JSON_FILE=$(find "$DOCLING_DIR" -maxdepth 1 -name "*.json" | head -n 1)

        # Validate inputs
        if [[ -z "$PDF_FILE" ]]; then
            echo "  [Skipping] No PDF file found in $SOURCE_DIR"
            continue
        fi
        
        if [[ -z "$JSON_FILE" ]]; then
            echo "  [Skipping] No JSON file found in $DOCLING_DIR"
            continue
        fi

        echo "  PDF: $PDF_FILE"
        echo "  JSON: $JSON_FILE"

        # 3. Define Output Paths (rest of them)
        MS_PNG_FOLDER="$SOURCE_DIR/manuscript_png"
        FORMULA_PNG_FOLDER="$SOURCE_DIR/formula_png"
        
        MD_OUTPUT="$OUTPUT_DIR/formula_latex.md"

        # 4. Execute the Python script
        echo "  Running VLM extraction..."
        "$PYTHON_EXEC" "$SCRIPT_PATH" \
            "$PDF_FILE" \
            "$JSON_FILE" \
            "$MS_PNG_FOLDER" \
            "$FORMULA_PNG_FOLDER" \
            "$JSON_OUTPUT" \
            --output_formula_latex_md_path "$MD_OUTPUT"
            
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            echo "  [Success] Processed $paper_name"
        else
            echo "  [Error] Failed to process $paper_name (Exit Code: $STATUS)"
        fi
    fi
done

echo "==================================================="
echo "Batch processing complete."
