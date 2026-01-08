# NTU DAVID RAG - Economics Fortran Code Parser

A specialized toolkit for extracting, parsing, and preparing Fortran economic model code for Retrieval-Augmented Generation (RAG) systems.

## Overview

This project handles the unique challenges of parsing monolithic Fortran programs where:
- Subroutines use global variables without explicit parameter passing
- Standard text chunking would lose critical context
- Variable definitions are separated from their usage by thousands of lines

## Quick Start

### 1. Environment Setup

Create and activate a Python virtual environment:

```bash
# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
# On Linux/Mac:
source .venv/bin/activate

# On Windows:
# .venv\Scripts\activate

# Upgrade pip
pip install --upgrade pip
```

### 2. Install Dependencies

```bash
# Install required Python packages
pip install -r requirements.txt

# If requirements.txt doesn't exist, install manually:
# pip install pathlib  # Usually included in Python 3.4+
```

### 3. Verify Setup

```bash
# Test the Fortran parser
python3 utils/data_preprocess/fortran_parser.py --help
```

## Project Structure

```
NTU-DAVID-RAG/
├── data/                           # Raw and processed data
│   ├── Accounting for Wealth.../   # Research project 1
│   │   ├── coding/                 # Original mixed files
│   │   ├── codes_fortran/          # Extracted Fortran files
│   │   ├── codes_fortran_json/     # Parsed JSON outputs
│   │   └── manuscript_parsed_*/    # Parsed manuscript outputs
│   ├── Consumption Smoothing.../   # Research project 2
│   └── The Welfare Implications.../# Research project 3
├── utils/
│   └── data_preprocess/
│       ├── fortran_preprocess/     # Fortran code extraction & parsing
│       ├── Dolphin/                # PDF parsing with Dolphin (layout-aware)
│       ├── pdf_crawler/            # PDF parsing with Docling (structured)
│       ├── s2orc-doc2json/         # PDF/LaTeX to S2ORC JSON format
│       └── Paper2Code/             # Auto-generate code from papers
└── README.md
```

## Tools Documentation

### Data Preprocessing Tools Overview

The `utils/data_preprocess/` directory contains specialized tools for extracting and parsing economic research materials:

#### 1. **fortran_preprocess/** - Fortran Code Processing
- **Purpose**: Extract and parse Fortran economic model code for RAG systems
- **Key Tools**:
  - `remove_non_fortran.py` - Extract Fortran files from mixed directories
  - `fortran_parser.py` - Parse Fortran into structured JSON with dependency tracking
  - `retrieve_fortran_codes.sh` - Batch extraction script
  - `parse_fortrain.sh` - Batch parsing script
- **Output**: JSON files with global variables, subroutines, and dependencies
- **GPU**: Not required

#### 2. **Dolphin/** - Advanced PDF Parsing
- **Purpose**: Parse PDFs using Dolphin v2 model (layout-aware, handles digital & scanned docs)
- **Best For**: Complex layouts, tables, figures, multi-column documents
- **Output**: Structured JSON with document elements, layout information
- **GPU**: Required (vision model inference)

#### 3. **pdf_crawler/** - Basic PDF Parsing
- **Purpose**: Extract structured content from PDFs using Docling
- **Best For**: Standard academic papers with text and formulas
- **Features**: LaTeX formula extraction, table detection
- **Output**: JSON with text, formulas, and metadata
- **GPU**: Optional (faster with GPU, works on CPU)

#### 4. **s2orc-doc2json/** - Scientific Paper Parsing
- **Purpose**: Convert PDFs/LaTeX to S2ORC JSON format using Grobid
- **Best For**: Academic papers requiring bibliographic data and citations
- **Output**: S2ORC-formatted JSON with sections, citations, bibliography
- **GPU**: Not required

#### 5. **Paper2Code/** - Code Generation from Papers
- **Purpose**: Multi-agent LLM system to generate code repositories from papers
- **Best For**: Reproducing ML/computational methods from manuscripts
- **Pipeline**: Planning → Analysis → Code Generation
- **GPU**: Optional (uses LLM APIs by default, can use local models with GPU)
