#!/bin/bash

# export OPENAI_API_KEY=""

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Activate Paper2Code virtual environment
PAPER2CODE_DIR="${SCRIPT_DIR}/.."
source "${PAPER2CODE_DIR}/.venv/bin/activate"

GPT_VERSION="o3-mini"

# Base data directory
DATA_DIR="${PROJECT_ROOT}/data"

# Path to s2orc-doc2json (adjust if needed)
DOC2JSON_DIR="${PROJECT_ROOT}/utils/data_preprocess/s2orc-doc2json"

# Activate s2orc virtual environment for PDF processing
S2ORC_VENV="${DOC2JSON_DIR}/.venv"

echo "================================================"
echo "Paper2Code - Processing manuscripts"
echo "================================================"
echo ""

# Check if s2orc-doc2json exists
if [ ! -d "$DOC2JSON_DIR" ]; then
    echo "ERROR: s2orc-doc2json not found at: ${DOC2JSON_DIR}"
    echo "Please clone it first:"
    echo "  cd ${SCRIPT_DIR}/.."
    echo "  git clone https://github.com/allenai/s2orc-doc2json.git"
    exit 1
fi

# Check if grobid service is running (optional check)
echo "Note: Make sure grobid service is running:"
echo "  cd ${DOC2JSON_DIR}/grobid-0.7.3 && ./gradlew run"
echo ""

# Counter for processed papers
PAPER_COUNT=0
TOTAL_PAPERS=$(find "${DATA_DIR}" -path "*/source/*.pdf" -type f | wc -l)

# Find all PDF files in data/[paper]/source/ directories
find "${DATA_DIR}" -path "*/source/*.pdf" -type f | sort | while read -r PDF_PATH; do
    PAPER_COUNT=$((PAPER_COUNT + 1))
    
    # Extract project directory and name
    SOURCE_DIR=$(dirname "$PDF_PATH")
    PROJECT_DIR=$(dirname "$SOURCE_DIR")
    PAPER_NAME=$(basename "$PROJECT_DIR")
    
    echo "[${PAPER_COUNT}/${TOTAL_PAPERS}] Processing: ${PAPER_NAME}"
    echo "Project directory: ${PROJECT_DIR}"
    echo "PDF file: $(basename "$PDF_PATH")"
    
    # Set up paths - everything goes under manuscript_paper2code
    PDF_BASENAME=$(basename "$PDF_PATH" .pdf)
    OUTPUT_BASE="${PROJECT_DIR}/manuscript_paper2code"
    PDF_JSON_CLEANED_PATH="${OUTPUT_BASE}/${PDF_BASENAME}_cleaned.json"
    OUTPUT_DIR="${OUTPUT_BASE}/outputs"
    OUTPUT_REPO_DIR="${OUTPUT_BASE}/repository"
    
    # Check for existing s2orc JSON file
    S2ORC_JSON_DIR="${PROJECT_DIR}/manuscript_parsed_s2orc"
    S2ORC_JSON_PATH="${S2ORC_JSON_DIR}/Manuscript.json"
    
    # Create output directories
    mkdir -p "$OUTPUT_BASE"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_REPO_DIR"
    
    # Step 1: Use existing s2orc JSON or convert PDF to JSON
    echo "------- Checking for s2orc JSON -------"
    if [ -f "$S2ORC_JSON_PATH" ]; then
        echo "✓ Using existing s2orc JSON: ${S2ORC_JSON_PATH}"
        PDF_JSON_PATH="$S2ORC_JSON_PATH"
    else
        echo "No s2orc JSON found, converting PDF..."
        PDF_JSON_PATH="${OUTPUT_BASE}/${PDF_BASENAME}.json"
        
        # Temporarily switch to s2orc venv for PDF processing
        deactivate
        source "${S2ORC_VENV}/bin/activate"
        
        python "${DOC2JSON_DIR}/doc2json/grobid2json/process_pdf.py" \
            -i "${PDF_PATH}" \
            -t "${OUTPUT_BASE}/temp_dir/" \
            -o "${OUTPUT_BASE}/"
        
        # Switch back to Paper2Code venv
        deactivate
        source "${PAPER2CODE_DIR}/.venv/bin/activate"
        
        # Rename output to expected filename
        GENERATED_JSON="${OUTPUT_BASE}/$(basename "$PDF_PATH" .pdf).json"
        if [ -f "$GENERATED_JSON" ] && [ "$GENERATED_JSON" != "$PDF_JSON_PATH" ]; then
            mv "$GENERATED_JSON" "$PDF_JSON_PATH"
        fi
        
        echo "✓ PDF converted to JSON: ${PDF_JSON_PATH}"
    fi
    
    # Check if JSON was created or found
    if [ ! -f "$PDF_JSON_PATH" ]; then
        echo "ERROR: No JSON file available (neither s2orc nor generated)"
        echo "Skipping this paper..."
        echo ""
        continue
    fi
    
    echo "------- Preprocess -------"
    python "${SCRIPT_DIR}/../codes_gemini/0_pdf_process.py" \
        --input_json_path "${PDF_JSON_PATH}" \
        --output_json_path "${PDF_JSON_CLEANED_PATH}"
    
    echo "------- PaperCoder -------"
    
    python "${SCRIPT_DIR}/../codes_gemini/1_planning.py" \
        --paper_name "$PAPER_NAME" \
        --gpt_version "${GPT_VERSION}" \
        --pdf_json_path "${PDF_JSON_CLEANED_PATH}" \
        --output_dir "${OUTPUT_DIR}"
    
    python "${SCRIPT_DIR}/../codes_gemini/1.1_extract_config.py" \
        --paper_name "$PAPER_NAME" \
        --output_dir "${OUTPUT_DIR}"
    
    cp -rp "${OUTPUT_DIR}/planning_config.yaml" "${OUTPUT_REPO_DIR}/config.yaml"
    
    python "${SCRIPT_DIR}/../codes_gemini/2_analyzing.py" \
        --paper_name "$PAPER_NAME" \
        --gpt_version "${GPT_VERSION}" \
        --pdf_json_path "${PDF_JSON_CLEANED_PATH}" \
        --output_dir "${OUTPUT_DIR}"
    
    python "${SCRIPT_DIR}/../codes_gemini/3_coding.py" \
        --paper_name "$PAPER_NAME" \
        --gpt_version "${GPT_VERSION}" \
        --pdf_json_path "${PDF_JSON_CLEANED_PATH}" \
        --output_dir "${OUTPUT_DIR}" \
        --output_repo_dir "${OUTPUT_REPO_DIR}"
    
    echo "✓ Completed: ${PAPER_NAME}"
    echo "✓ Output saved to: ${OUTPUT_BASE}"
    echo ""
done

echo "================================================"
echo "✓ Paper2Code processing complete!"
echo "================================================"
