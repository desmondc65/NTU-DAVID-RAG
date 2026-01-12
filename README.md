# NTU DAVID RAG

**Project Status**: Active Development

This project aims to build an efficient and high-quality Retrieval-Augmented Generation (RAG) system specialized for economics-related academic papers and their associated codebases (specifically Fortran).

![System Design](docs/initial_system_desgin.png)

## Project Plan & Roadmap

The development is divided into three key phases, focusing on deep parsing, storage architecture, and advanced retrieval.

### Phase 1: Document Parsing and Retrieval (In Progress)
Focus on parsing and retrieving context from academic paper PDFs and Fortran code.
- **Deep Parsing**: Processing Thesis PDF Corpus (text, tables, figures).
- **Code Extraction**: Parsing Fortran code, extracting global variables, and summarization.
- **Visual Extraction**: Using VLMs (Gemini 1.5 / GPT-4o) for image captioning.
- **Goal**: Efficiently parse heterogeneous data sources into structured formats.

### Phase 2: Building RAG Database [To Be Done]
Focus on embedding strategies and database architecture.
- **Storage Architecture**: Designing Multi-Vector Storage (Doc Store for raw content + Vector DB for embeddings).
- **Embedding Models**: Selecting optimal models (e.g., text-embedding-3, CLIP).
- **Metadata & Chunking**: Defining strategies for storing and chunking different context types to maximize retrieval performance.

### Phase 3: Hybrid Retrieval and Generation [To Be Done]
Focus on retrieval quality and answer generation.
- **Hybrid Retrieval**: Combining keyword and semantic search with metadata filtering.
- **Reranking**: Implementing Cross-Encoder Rerankers (e.g., bge-reranker) to refine search results.
- **Generation**: Utilizing Multimodal LLMs to generate meaningful, context-aware answers.

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

The root `requirements.txt` covers the base dependencies (e.g. for `fortran_preprocess` and `pdf_crawler`).

```bash
# Install base required Python packages
pip install -r requirements.txt

# If requirements.txt doesn't exist, install manually:
# pip install pathlib  # Usually included in Python 3.4+
```

> **Note:** Advanced tools located in `utils/data_preprocess/` (specifically `Dolphin`, `Paper2Code`, and `s2orc-doc2json`) have their own `requirements.txt` or setup files. **It is highly recommended to create and use separate virtual environments for these tools** to prevent dependency conflicts. Please refer to the `README.md` within each tool's directory for specific installation instructions.

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
- **Key Tools & Usage**:
  - `remove_non_fortran.py` - Extract Fortran files from mixed directories
  - `fortran_parser.py` - Parse Fortran into structured JSON with dependency tracking
  - **Conversion Scripts**:
    - `retrieve_fortran_codes.sh`: Batch script to extract Fortran source files.
    - `parse_fortrain.sh`: Batch script to parse extracted Fortran files into JSON.
- **Output**: JSON files with global variables, subroutines, and dependencies
- **GPU**: Not required

#### 2. **Dolphin/** - Advanced PDF Parsing
- **Purpose**: Parse PDFs using Dolphin v2 model (layout-aware, handles digital & scanned docs)
- **Best For**: Complex layouts, tables, figures, multi-column documents
- **Conversion Script**: `parse_manuscript.sh`
  - Reference this script to see how to run `demo_page.py` for specific PDF files.
- **Output**: Structured JSON with document elements, layout information
- **GPU**: Required (vision model inference)

#### 3. **pdf_crawler/** - Basic PDF Parsing
- **Purpose**: Extract structured content from PDFs using Docling
- **Best For**: Standard academic papers with text and formulas
- **Conversion Script**: `pdf_crawler.sh`
  - A bash wrapper around `pdf_crawler.py` that processes specific input PDFs defined within the script.
- **Features**: LaTeX formula extraction, table detection
- **Output**: JSON with text, formulas, and metadata
- **GPU**: Optional (faster with GPU, works on CPU)

#### 4. **s2orc-doc2json/** - Scientific Paper Parsing
- **Purpose**: Convert PDFs/LaTeX to S2ORC JSON format using Grobid
- **Best For**: Academic papers requiring bibliographic data and citations
- **Conversion Script**: `process_all_manuscripts.sh`
  - Iterates through a defined list of papers and runs the Grobid-to-JSON conversion.
- **Output**: S2ORC-formatted JSON with sections, citations, bibliography
- **GPU**: Not required

#### 5. **Paper2Code/** - Code Generation from Papers
- **Purpose**: Multi-agent LLM system to generate code repositories from papers
- **Best For**: Reproducing ML/computational methods from manuscripts
- **Conversion Scripts**:
  - `scripts/run_econs.sh`: Specialized script for data/ directory
- **Pipeline**: Planning → Analysis → Code Generation
- **GPU**: Optional (uses LLM APIs by default, can use local models with GPU)
