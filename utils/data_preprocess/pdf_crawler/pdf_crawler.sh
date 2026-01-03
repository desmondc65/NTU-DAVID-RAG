#!/bin/bash

# PDF Crawler Script
# Parses multiple PDF files and saves to their respective manuscript_parsed_docling directories

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Activate virtual environment
source "${PROJECT_ROOT}/.venv/bin/activate"

PDF_CRAWLER_PY="${SCRIPT_DIR}/pdf_crawler.py"

# Base data directory
DATA_DIR="${PROJECT_ROOT}/data"

echo "================================================"
echo "PDF Crawler - Processing manuscripts"
echo "================================================"
echo ""

# Project 1: Consumption Smoothing
PROJECT_1="${DATA_DIR}/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems"
PDF_1="${PROJECT_1}/Manuscript.pdf"
OUTPUT_DIR_1="${PROJECT_1}/manuscript_parsed_docling"
OUTPUT_1="${OUTPUT_DIR_1}/Manuscript_parsed_docling.json"

if [ -f "$PDF_1" ]; then
    echo "[1/2] Processing: Consumption Smoothing manuscript"
    mkdir -p "$OUTPUT_DIR_1"
    "${PROJECT_ROOT}/.venv/bin/python3" "$PDF_CRAWLER_PY" "$PDF_1" -o "$OUTPUT_1"
    echo ""
else
    echo "[1/2] WARNING: PDF not found: $PDF_1"
    echo ""
fi

# Project 2: The Welfare Implications
PROJECT_2="${DATA_DIR}/The Welfare Implications of Top Marginal Tax Reform in Taiwan"
PDF_2="${PROJECT_2}/Manuscript.pdf"
OUTPUT_DIR_2="${PROJECT_2}/manuscript_parsed_docling"
OUTPUT_2="${OUTPUT_DIR_2}/Manuscript_parsed_docling.json"

if [ -f "$PDF_2" ]; then
    echo "[2/2] Processing: Top Marginal Tax Reform manuscript"
    mkdir -p "$OUTPUT_DIR_2"
    "${PROJECT_ROOT}/.venv/bin/python3" "$PDF_CRAWLER_PY" "$PDF_2" -o "$OUTPUT_2"
    echo ""
else
    echo "[2/2] WARNING: PDF not found: $PDF_2"
    echo ""
fi

echo "================================================"
echo "✓ PDF crawling complete!"
echo "================================================"
