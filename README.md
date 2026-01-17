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
│       ├── vlm_formula_to_latex/   # VLM-based formula extraction
│       ├── s2orc-doc2json/         # PDF/LaTeX to S2ORC JSON format
│       └── Paper2Code/             # Auto-generate code from papers
└── README.md
```

## Tools Documentation

### [Phase 1] Data Preprocessing Tools Overview

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

#### 4. **vlm_formula_to_latex/** - VLM Formula to LaTeX

- **Purpose**: Uses Vision Language Models (VLMs) to accurately extract mathematical formulas as LaTeX.
- **Conversion Script**: `run_all.sh`
  - Automates batch processing to convert formulas.

  ```bash
  # Run for all papers
  ./utils/data_preprocess/vlm_formula_to_latex/run_all.sh

  # Run for a specific paper
  ./utils/data_preprocess/vlm_formula_to_latex/run_all.sh --target-folder "Paper Name"

  # Skip already processed papers
  ./utils/data_preprocess/vlm_formula_to_latex/run_all.sh --skip-existing
  ```

- **Output**: JSON and Markdown files with corrected LaTeX formulas.

#### 5. **s2orc-doc2json/** - Scientific Paper Parsing

- **Purpose**: Convert PDFs/LaTeX to S2ORC JSON format using Grobid
- **Best For**: Academic papers requiring bibliographic data and citations
- **Conversion Script**: `process_all_manuscripts.sh`
  - Iterates through a defined list of papers and runs the Grobid-to-JSON conversion.
- **Output**: S2ORC-formatted JSON with sections, citations, bibliography
- **GPU**: Not required

#### 6. **Paper2Code/** - Code Generation from Papers

- **Purpose**: Multi-agent LLM system to generate code repositories from papers
- **Best For**: Reproducing ML/computational methods from manuscripts
- **Pipeline**: Planning → Analysis → Code Generation
- **GPU**: Optional (uses LLM APIs by default, can use local models with GPU)

##### Installation

Paper2Code requires its own virtual environment to avoid dependency conflicts:

```bash
# Navigate to Paper2Code directory
cd utils/data_preprocess/Paper2Code

# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt
```

##### API Key Configuration

Paper2Code supports both **Gemini API** (recommended for this project) and **OpenAI API**:

**Using Gemini API (Recommended):**

```bash
# Export your Gemini API key to the shell environment
export GEMINI_API_KEY="your-gemini-api-key-here"

# Verify the key is set
echo $GEMINI_API_KEY
```

**Using OpenAI API (Alternative):**

```bash
# Export your OpenAI API key to the shell environment
export OPENAI_API_KEY="your-openai-api-key-here"

# Verify the key is set
echo $OPENAI_API_KEY
```

> **Note**: The API key must be exported in the same terminal session where you run the scripts. To make it persistent across sessions, add the export command to your `~/.bashrc` or `~/.zshrc` file.

##### Execution

**Option 1: Process Economics Papers (Automated)**

The `run_econs.sh` script automatically processes all papers in the `data/` directory:

```bash
# Make sure you're in the Paper2Code directory with the virtual environment activated
cd utils/data_preprocess/Paper2Code
source .venv/bin/activate

# Export your API key (if not already done)
export GEMINI_API_KEY="your-gemini-api-key-here"

# Run the economics paper processing script
./scripts/run_econs.sh
```

This script will:

1. Find all PDF files in `data/[paper]/source/` directories
2. Convert PDFs to JSON format (or use existing s2orc JSON if available)
3. Run the Paper2Code pipeline (planning → analysis → code generation)
4. Save outputs to `data/[paper]/manuscript_paper2code/`

**Option 2: Process a Single Paper (Manual)**

For processing individual papers with more control:

```bash
# Using Gemini API with PDF-based JSON
export GEMINI_API_KEY="your-gemini-api-key-here"
cd scripts
bash run.sh

# Using OpenAI API with PDF-based JSON
export OPENAI_API_KEY="your-openai-api-key-here"
cd scripts
bash run.sh

# Using LaTeX source (if available)
export GEMINI_API_KEY="your-gemini-api-key-here"
cd scripts
bash run_latex.sh
```

**Option 3: Using Open Source Models with vLLM**

For local model inference (requires GPU):

```bash
# Using PDF-based JSON
cd scripts
bash run_llm.sh

# Using LaTeX source
cd scripts
bash run_latex_llm.sh
```

##### Output Structure

After processing, outputs are organized as follows:

```
data/[Paper Name]/manuscript_paper2code/
├── [Paper]_cleaned.json          # Preprocessed paper JSON
├── outputs/
│   ├── planning_artifacts/       # Planning stage outputs
│   ├── analyzing_artifacts/      # Analysis stage outputs
│   └── coding_artifacts/         # Code generation outputs
└── repository/                   # Final generated code repository
    ├── config.yaml               # Extracted configuration
    └── [generated code files]
```

##### Cost Estimates

- **Gemini API (gemini-3-flash-preview)**: ~$0.30–$0.50 per paper
  - Input: $0.50 per 1M tokens
  - Output: $3.00 per 1M tokens
- **OpenAI API (o3-mini)**: ~$0.50–$0.70 per paper

##### Troubleshooting

- **Missing s2orc-doc2json**: If you see an error about missing s2orc-doc2json, ensure it's installed in `utils/data_preprocess/s2orc-doc2json/`
- **Grobid service not running**: Start the Grobid service for PDF processing:
  ```bash
  cd utils/data_preprocess/s2orc-doc2json/grobid-0.7.3
  ./gradlew run
  ```
- **API key not found**: Ensure you've exported the API key in the current terminal session
- **Virtual environment issues**: Always activate the Paper2Code virtual environment before running scripts

### [Phase 2] RAG Database & Embeddings

(To be implemented)

### [Phase 3] Hybrid Retrieval & Generation

(To be implemented)
