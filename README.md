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
│   │   └── codes_fortran_json/     # Parsed JSON outputs
│   ├── Consumption Smoothing.../   # Research project 2
│   └── The Welfare Implications.../# Research project 3
├── utils/
│   └── data_preprocess/
│       ├── remove_non_fortran.py      # Extract Fortran files
│       ├── fortran_parser.py          # Parse for RAG
│       ├── retrieve_fortran_codes.sh  # Batch extraction
│       └── parse_fortrain.sh          # Batch parsing
└── README.md
```

## Tools Documentation

### Tool 1: Fortran File Extractor

**File:** `utils/data_preprocess/remove_non_fortran.py`

**Purpose:** Recursively searches directories for Fortran files and copies them to a clean output folder.

**What it does:**
- Finds all files with Fortran extensions: `.f`, `.f90`, `.f95`, `.f03`, `.for`
- Copies them to output directory (flattened structure, no subdirectories)
- Handles filename conflicts by skipping duplicates

**Usage:**

```bash
# Single directory
python3 utils/data_preprocess/remove_non_fortran.py <input_dir> -o <output_dir>

# Example
python3 utils/data_preprocess/remove_non_fortran.py \
    "data/Project/coding" \
    -o "data/Project/codes_fortran"
```

**Arguments:**
- `input_dir` (required): Directory to search recursively
- `-o, --output` (optional): Output directory for Fortran files

---

### Tool 2: Scope-Aware Fortran Parser

**File:** `utils/data_preprocess/fortran_parser.py`

**Purpose:** Parses Fortran programs into structured JSON for RAG systems, solving the "implicit scoping" problem.

**The Problem it Solves:**

Traditional RAG systems fail on Fortran code like this:

```fortran
PROGRAM wealth_accounting
    REAL :: bendy = 0.5     ! Line 50
    REAL :: tau_l = 0.3     ! Line 51
    
    CONTAINS                ! Line 1000
    
    SUBROUTINE SRCHFIVE01   ! Line 5000
        ! Uses bendy and tau_l without declaring them!
        yd = MIN(bendy * income, ...)
    END SUBROUTINE
END PROGRAM
```

If RAG retrieves only `SRCHFIVE01`, the LLM doesn't know what `bendy` is. This parser tracks these dependencies.

**What it does:**
1. **Extracts Global Context**: All variable declarations (PARAMETER, REAL, INTEGER, ALLOCATABLE)
2. **Maps Subroutines**: Each subroutine with its arguments and global dependencies
3. **Segments Main Logic**: Breaks down main program into logical blocks
4. **Creates JSON**: Structured output with all relationships preserved

**Usage:**

```bash
# Parse single file
python3 utils/data_preprocess/fortran_parser.py <file.f90> -o <output_dir>

# Parse entire directory
python3 utils/data_preprocess/fortran_parser.py <directory> -o <output_dir>

# Example
python3 utils/data_preprocess/fortran_parser.py \
    "data/Project/codes_fortran" \
    -o "data/Project/codes_fortran_json"
```

**Arguments:**
- `path` (required): Fortran file or directory
- `-o, --output` (optional): Output directory for JSON files

**Output Files:**
- `{filename}_parsed.json` - Full structured data with:
  - `global_context`: All variable declarations
  - `global_variables`: Each variable with type, value, line number
  - `subroutines`: Each function with dependencies
  - `main_logic`: Main program segmented into blocks
- `{filename}_summary.txt` - Human-readable summary

**Example Output Structure:**

```json
{
  "program_name": "wealth_accounting",
  "global_variables": [
    {
      "name": "bendy",
      "type": "REAL",
      "value": "0.5",
      "line": 50
    }
  ],
  "subroutines": [
    {
      "name": "SRCHFIVE01",
      "arguments": ["income", "age"],
      "dependencies": [
        {"variable": "BENDY", "type": "global_reference"},
        {"variable": "TAU_L", "type": "global_reference"}
      ]
    }
  ]
}
```

---

### Tool 3: Batch Extraction Script

**File:** `utils/data_preprocess/retrieve_fortran_codes.sh`

**Purpose:** Automates extraction of Fortran files from all research projects.

**Usage:**

```bash
# Make executable (first time only)
chmod +x utils/data_preprocess/retrieve_fortran_codes.sh

# Run
./utils/data_preprocess/retrieve_fortran_codes.sh
```

**What it does:**
- Extracts Fortran files from all three research project directories
- Outputs to `codes_fortran/` subdirectories
- Processes all projects in one command

---

### Tool 4: Batch Parsing Script

**File:** `utils/data_preprocess/parse_fortrain.sh`

**Purpose:** Automates parsing of all extracted Fortran files into JSON.

**Usage:**

```bash
# Make executable (first time only)
chmod +x utils/data_preprocess/parse_fortrain.sh

# Run
./utils/data_preprocess/parse_fortrain.sh
```

**What it does:**
- Parses all Fortran files in `codes_fortran/` directories
- Outputs JSON to `codes_fortran_json/` subdirectories
- Processes all projects in one command

---

## Complete Workflow

### Step-by-Step Guide

```bash
# 1. Activate virtual environment
source .venv/bin/activate

# 2. Extract all Fortran files
./utils/data_preprocess/retrieve_fortran_codes.sh

# 3. Parse all Fortran files to JSON
./utils/data_preprocess/parse_fortrain.sh

# 4. Check results
ls -R data/*/codes_fortran_json/
```

### Expected Output

After running the complete workflow:

```
data/
├── Accounting for Wealth Concentration in the United States/
│   ├── codes_fortran/           # 80 Fortran files
│   └── codes_fortran_json/      # 80 JSON + 80 summary files
├── Consumption Smoothing and Welfare Implications.../
│   ├── codes_fortran/           # Fortran files
│   └── codes_fortran_json/      # JSON files
└── The Welfare Implications of Top Marginal Tax Reform in Taiwan/
    ├── codes_fortran/           # Fortran files
    └── codes_fortran_json/      # JSON files
```

## How to Use Parsed Data for RAG

### 1. Context Injection Strategy

When your RAG system retrieves a subroutine:

```python
# Retrieve subroutine
subroutine = retrieve("SRCHFIVE01")

# Check dependencies
if subroutine['dependencies']:
    # Inject global context
    global_vars = get_global_variables(subroutine['dependencies'])
    
    # Send to LLM
    prompt = f"""
    Global Variable Definitions:
    {global_vars}
    
    Subroutine Code:
    {subroutine['code']}
    
    Question: {user_question}
    """
```

### 2. Embedding Strategy

For each subroutine, create embeddings with context:

```python
# Bad (will fail)
embed(subroutine['code'])

# Good (includes context)
embed({
    'code': subroutine['code'],
    'dependencies': subroutine['dependencies'],
    'global_context': get_required_globals(subroutine)
})
```

### Key Features

1. **Dependency Tracking**: Maps which global variables each subroutine uses
2. **Logic Segmentation**: Breaks main program into meaningful blocks
3. **Metadata Preservation**: Line numbers, variable types, parameter values
4. **Batch Processing**: Handles entire directories of Fortran files

## Troubleshooting

### Virtual Environment Issues

```bash
# If activation fails
python3 -m venv .venv --clear

# If pip is outdated
python3 -m pip install --upgrade pip
```

### Script Permission Errors

```bash
# Make scripts executable
chmod +x utils/data_preprocess/*.sh
```

### File Not Found Errors

Ensure you're in the project root directory:

```bash
cd /path/to/NTU-DAVID-RAG
```

## Advanced Usage

### Parse Specific File

```bash
python3 utils/data_preprocess/fortran_parser.py \
    "data/Project/codes_fortran/specific_file.f90" \
    -o "output/"
```

### Custom Output Location

```bash
python3 utils/data_preprocess/remove_non_fortran.py \
    "source_directory/" \
    -o "/custom/output/path"
```


