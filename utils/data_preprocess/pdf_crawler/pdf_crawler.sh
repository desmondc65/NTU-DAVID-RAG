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

# Project 1: The Joint Labor Supply Decision
PROJECT_1="${DATA_DIR}/The Joint Labor Supply Decision of Married Couples and the Social Security Pension System"
PDF_1="${PROJECT_1}/source/Manuscript.pdf"
OUTPUT_DIR_1="${PROJECT_1}/manuscript_parsed_docling"
OUTPUT_1="${OUTPUT_DIR_1}/Manuscript_parsed_docling.json"

if [ -f "$PDF_1" ]; then
    echo "[1/2] Processing: Joint Labor Supply Decision manuscript"
    mkdir -p "$OUTPUT_DIR_1"
    "${PROJECT_ROOT}/.venv/bin/python3" "$PDF_CRAWLER_PY" "$PDF_1" -o "$OUTPUT_1"
    echo ""
else
    echo "[1/2] WARNING: PDF not found: $PDF_1"
    echo ""
fi

# Project 2: Transitional Dynamics
PROJECT_2="${DATA_DIR}/Transitional Dynamics and the Optimal Progressivity of Income Redistribution"
PDF_2="${PROJECT_2}/source/Manuscript.pdf"
OUTPUT_DIR_2="${PROJECT_2}/manuscript_parsed_docling"
OUTPUT_2="${OUTPUT_DIR_2}/Manuscript_parsed_docling.json"

if [ -f "$PDF_2" ]; then
    echo "[2/2] Processing: Transitional Dynamics manuscript"
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
