#!/bin/bash

# Script to process all manuscript PDFs using s2orc-doc2json
# Output will be saved as manuscript_parsed_s2orc in each paper folder

# Base data directory
DATA_DIR="/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data"

# S2ORC directory
S2ORC_DIR="/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/utils/data_preprocess/s2orc-doc2json"

# Activate virtual environment
source "${S2ORC_DIR}/.venv/bin/activate"

# Temporary directory for processing
TEMP_DIR="${S2ORC_DIR}/temp"
mkdir -p "${TEMP_DIR}"

# Array of paper directories
PAPERS=(
    "Accounting for Wealth Concentration in the United States"
    "Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems"
    "The Joint Labor Supply Decision of Married Couples and the Social Security Pension System"
    "The Welfare Implications of Top Marginal Tax Reform in Taiwan"
    "Transitional Dynamics and the Optimal Progressivity of Income Redistribution"
)

echo "Starting PDF processing with s2orc-doc2json..."
echo "================================================"
echo ""

# Process each paper
for paper in "${PAPERS[@]}"; do
    echo "Processing: $paper"
    
    # Define paths
    PDF_PATH="${DATA_DIR}/${paper}/source/Manuscript.pdf"
    OUTPUT_DIR="${DATA_DIR}/${paper}/manuscript_parsed_s2orc"
    PAPER_TEMP_DIR="${TEMP_DIR}/$(echo "$paper" | tr ' ' '_')"
    
    # Check if PDF exists
    if [ ! -f "$PDF_PATH" ]; then
        echo "  ⚠️  PDF not found: $PDF_PATH"
        echo ""
        continue
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$PAPER_TEMP_DIR"
    
    # Process the PDF
    echo "  📄 Processing PDF..."
    cd "$S2ORC_DIR"
    python3 doc2json/grobid2json/process_pdf.py \
        -i "$PDF_PATH" \
        -t "$PAPER_TEMP_DIR" \
        -o "$OUTPUT_DIR"
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully processed and saved to: $OUTPUT_DIR"
        # Clean up temp directory for this paper
        rm -rf "$PAPER_TEMP_DIR"
    else
        echo "  ✗ Error processing PDF"
    fi
    
    echo ""
done

# Clean up temp directory
rm -rf "${TEMP_DIR}"

echo "================================================"
echo "Processing complete!"
echo ""
echo "Output locations:"
for paper in "${PAPERS[@]}"; do
    OUTPUT_DIR="${DATA_DIR}/${paper}/manuscript_parsed_s2orc"
    if [ -d "$OUTPUT_DIR" ]; then
        JSON_COUNT=$(find "$OUTPUT_DIR" -name "*.json" | wc -l)
        echo "  - $paper: $JSON_COUNT JSON file(s)"
    fi
done
