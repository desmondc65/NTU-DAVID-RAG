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

#### LaTeX Rendering Environment (for vlm_formula_to_latex)

If you plan to use the `vlm_formula_to_latex` tool with quality comparison features, you need to install LaTeX:

```bash
# On Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y texlive-latex-base texlive-latex-extra

# On macOS (using Homebrew)
brew install --cask mactex

# On Windows
# Download and install MiKTeX from https://miktex.org/download
```

This enables the tool to render transcribed LaTeX formulas back to PNG for visual quality comparison.

### 3. Verify Setup

```bash
# Test the Fortran parser
python3 utils/data_preprocess/fortran_parser.py --help
```

## Running Tests

All tests are located in the `tests/` directory and should be run **from the project root** with the virtual environment activated:

```bash
source .venv/bin/activate
```

### Phase 2: Embedding Pipeline

Tests chunking, embedding model, vector store, and end-to-end embed+query:

```bash
CUDA_VISIBLE_DEVICES=2 python -m tests.test_s2_embedding
```

### Phase 3: Hybrid RAG Retrieval

Tests BM25 retriever, dense retriever, reranker, RRF fusion, and the full hybrid pipeline:

```bash
CUDA_VISIBLE_DEVICES=2 python -m tests.test_s3_rag
```

### LLM Clients

Tests Gemini and GPT clients (text, JSON, and structured output generation). Requires API keys:

```bash
export GEMINI_API_KEY="your-key"
export OPENAI_API_KEY="your-key"
python -m tests.test_llm_clients
```

> **Note:** Phase 2 and Phase 3 tests require a GPU and an existing vector store at `data/[Paper Name]/vector_store/`. The LLM client tests require valid API keys.

### Local LLM Service (Qwen3-Next-80B Q8_0 on GPU 0 + 1)

This repository includes a Docker Compose setup for a local OpenAI-compatible LLM endpoint using `llama.cpp` server.

```bash
cd docker/local_llm
cp .env.example .env
# Edit .env and set MODEL_DIR + MODEL_FILE
docker compose --env-file .env -f docker-compose.qwen3-next-80b.yml up -d
```

Use it from scripts via `LocalLLMClient`:

```python
from utils.llm_clients.local_llm import LocalLLMClient

client = LocalLLMClient(
  model_name="qwen3-next-80b-instruct-q8_0",
  base_url="http://localhost:8000/v1",
  api_key="local-dev-key",
)

response = client.generate_response(
  user_prompt="Give me three key takeaways from this economics abstract.",
  response_mime_type="text/plain"
)
print(response)
```

For full setup and remote access details, see `docs/local_llm_qwen3_next_80b_docker.md`.

### RAGAS Evaluation for the Dockerized Original RAG

The repo now includes a reference-free Ragas runner for the original
Dockerized vector RAG in `RAG_quality_test/rag_ragas_eval.py`.

Use this sequence:

```bash
cd docker/graphRag && docker compose down
cd ../local_llm && docker compose -f docker-compose.gemma4_31b_ollama.yml up -d
cd ../RAG && docker compose up -d --build rag-web

cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
. .venv/bin/activate
pip install -r RAG_quality_test/requirements-ragas.txt
python RAG_quality_test/rag_ragas_eval.py
```

Only one RAG framework should be up at a time. Keep `docker/graphRag` down
while evaluating the original RAG. See `RAG_quality_test/README.md` for the
full evaluator notes and CLI options.

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

- **Purpose**: Uses Vision Language Models (VLMs) to accurately extract mathematical formulas as LaTeX, with quality verification.
- **Pipeline**:
  1. Convert PDF pages to PNG images
  2. Crop formulas using Docling bounding boxes
  3. Transcribe formulas to LaTeX using Gemini Vision API
  4. Render LaTeX back to PNG for quality comparison
  5. Generate interactive HTML comparison page
- **Conversion Script**: `run_all.sh`
  - Automates the complete pipeline from PDF to quality-verified LaTeX.

  ```bash
  # Run for all papers
  ./utils/data_preprocess/vlm_formula_to_latex/run_all.sh

  # Run for a specific paper
  ./utils/data_preprocess/vlm_formula_to_latex/run_all.sh --target-folder "Paper Name"

  # Skip already processed papers
  ./utils/data_preprocess/vlm_formula_to_latex/run_all.sh --skip-existing
  ```

- **Output Structure**:

  ```
  data/[Paper Name]/vlm_formula_latex/
  ├── formula_latex.json           # Transcribed formulas with metadata
  ├── formula_latex.md             # Human-readable markdown view
  ├── cost_info.log                # API cost tracking
  ├── accumulated_cost.json        # Cost summary
  ├── png/                         # Rendered LaTeX → PNG
  │   └── page_*_formula_*.png
  └── quality_comparison/          # Visual quality assessment
      └── comparison.html          # Interactive comparison page
  ```

- **Quality Comparison**: The generated HTML file displays original vs transcribed formulas side-by-side with LaTeX code, allowing visual verification of transcription accuracy. The HTML is self-contained and can be shared with others.

- **Requirements**:
  - Python packages: `pdf2image`, `Pillow`, `google-generativeai`
  - System: LaTeX distribution (texlive-latex-base, texlive-latex-extra)
  - API: Gemini API key

- **Cost**: ~$0.01–$0.05 per paper (varies by formula count)

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

The `utils/s2_embedding/` directory contains the embedding pipeline that chunks, embeds, and stores academic paper text and Fortran code into a local vector database for retrieval.

#### Architecture Overview

```
JSON Data Files ──→ Chunker ──→ Embedding Model ──→ ChromaDB Vector Store
                   (chunker.py)  (embedder.py)      (vector_store.py)
```

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Embedding Model** | `BAAI/bge-large-en-v1.5` | 1024-dim, strong on academic text + code, runs locally on GPU |
| **Vector Database** | ChromaDB (persistent) | Lightweight, local-first, zero-config, supports metadata filtering |
| **Chunking** | Section-aware (text) + Line-based (code) | Preserves semantic coherence for papers; summary-prefixed for code |

#### File Structure

```
utils/s2_embedding/
├── __init__.py          # Package init
├── chunker.py           # Chunking strategies for manuscript text and Fortran code
├── embedder.py          # BAAI/bge-large-en-v1.5 embedding model wrapper
├── vector_store.py      # ChromaDB persistent vector store wrapper
└── run_embed.py         # CLI orchestration script (chunk → embed → store → test)
```

#### Chunking Strategy

**Manuscript Text** (`Manuscript_content_list.json`):
- Filters `type == "text"` entries only (ignores headers, footers, page numbers)
- Merges consecutive paragraphs into chunks of ~384 tokens with 64-token overlap
- Preserves page index metadata for traceability

**Fortran Code** (`fortran_chunks.json`):
- Reads each code file referenced in the JSON
- Splits into sub-chunks of 150 lines with 30-line overlap
- Prepends the summary description to each chunk for retrieval context

#### Usage

**Prerequisites**: Install dependencies from the project root:

```bash
source .venv/bin/activate
pip install -r requirements.txt  # includes sentence-transformers and chromadb
```

**Run the embedding pipeline**:

```bash
# Using GPU #2 (adjust CUDA_VISIBLE_DEVICES as needed)
CUDA_VISIBLE_DEVICES=2 python -m utils.s2_embedding.run_embed \
  --manuscript "data/Accounting for Wealth Concentration in the United States/manuscript_parsed_mineru/Manuscript/hybrid_auto/Manuscript_content_list.json" \
  --fortran "data/Accounting for Wealth Concentration in the United States/RAG_Chunks/fortran_chunks.json" \
  --output "data/Accounting for Wealth Concentration in the United States/vector_store" \
  --device cuda:0 \
  --test-query
```

**CLI Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `--manuscript` | No* | Path to `Manuscript_content_list.json` |
| `--fortran` | No* | Path to `fortran_chunks.json` |
| `--output` | Yes | Output directory for ChromaDB persistent storage |
| `--model` | No | Embedding model name (default: `BAAI/bge-large-en-v1.5`) |
| `--device` | No | Device for inference, e.g. `cuda:0` (default: auto-detect) |
| `--test-query` | No | Run smoke queries after embedding to verify results |

\* At least one of `--manuscript` or `--fortran` must be specified.

**Output**: The vector store is saved to the `--output` directory and persists across runs:

```
data/[Paper Name]/vector_store/
├── chroma.sqlite3           # ChromaDB persistent storage
└── [collection files]       # HNSW index and metadata
```

#### Programmatic Usage

You can also use the components directly in Python:

```python
from utils.s2_embedding.chunker import chunk_manuscript, chunk_fortran
from utils.s2_embedding.embedder import EmbeddingModel
from utils.s2_embedding.vector_store import VectorStore

# Chunk
chunks = chunk_manuscript("path/to/Manuscript_content_list.json")

# Embed
model = EmbeddingModel(device="cuda:0")
embeddings = model.embed_documents([c["text"] for c in chunks])

# Store
store = VectorStore(persist_dir="path/to/vector_store")
store.add_documents(texts=..., embeddings=..., metadatas=..., ids=...)

# Query
query_emb = model.embed_query("What drives wealth concentration?")
results = store.query(query_emb, n_results=5, where_filter={"content_type": "manuscript"})
```

### [Phase 3] Hybrid Retrieval & Generation

#### Retrieval Pipeline (`utils/s3_RAG/`) ✅

The retrieval pipeline combines sparse and dense search with cross-encoder reranking:

```
Query
  ├──→ BM25 Sparse (top 50)  ──┐
  │     exact variable names,   │
  │     algorithm names         ├──→ RRF Fusion ──→ Cross-Encoder Reranker (top 10)
  └──→ Dense Vector (top 50) ──┘     (merge +       (BGE-Reranker-v2-m3)
        semantic intent               deduplicate)
```

| Component | Model / Library | Purpose |
|-----------|----------------|---------|
| **Sparse Retrieval** | BM25 (`rank-bm25`) | Lexical matching for exact Fortran identifiers like `REAL*8`, `NGRIDA`, subroutine names |
| **Dense Retrieval** | ChromaDB + `BAAI/bge-large-en-v1.5` | Semantic similarity for concept-level queries |
| **Fusion** | Reciprocal Rank Fusion (RRF) | Merges + deduplicates results from both retrievers |
| **Reranker** | `BAAI/bge-reranker-v2-m3` | Cross-encoder that rigorously scores each passage against the query |

##### Retrieval Strategy

**1. Reciprocal Rank Fusion (RRF)**

BM25 and dense retrieval produce scores on different scales (BM25 is unbounded, cosine similarity is 0–1), so raw scores can't be compared directly. RRF solves this by discarding scores entirely and using only **rank positions**:

```
RRF(doc) = Σ  1 / (k + rank_i)     where k = 60
```

- Documents found by **both** retrievers receive additive RRF contributions, boosting them above single-source results
- The constant `k = 60` (from [Cormack et al., 2009](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)) smooths out rank differences so neither retriever dominates
- Deduplication is built-in: each document appears once, keeping the first occurrence's metadata

**2. Cross-Encoder Reranking**

The top 50 RRF-fused results are refined by `BAAI/bge-reranker-v2-m3`, a cross-encoder that scores (query, passage) pairs jointly — unlike bi-encoders like BGE which embed query and passage independently. This makes it significantly more accurate at judging relevance, but too slow to run on the whole corpus (hence applied only to the fused top-50). The final top 10 results are returned sorted by `rerank_score`.

##### File Structure

```
utils/s3_RAG/
├── __init__.py            # Package init
├── bm25_retriever.py      # BM25Okapi sparse retrieval with Fortran-aware tokenization
├── dense_retriever.py     # ChromaDB + BGE dense vector retrieval
├── reranker.py            # BGE-Reranker-v2-m3 cross-encoder
├── hybrid_rag.py          # Full pipeline: BM25 + Dense + RRF + Reranker
└── run_rag.py             # Interactive CLI query interface
```

##### Usage

```bash
# Interactive query mode (GPU #2)
CUDA_VISIBLE_DEVICES=2 python -m utils.s3_RAG.run_rag \
  --vector-store "data/Accounting for Wealth Concentration in the United States/vector_store" \
  --device cuda:0

# With content type filter
CUDA_VISIBLE_DEVICES=2 python -m utils.s3_RAG.run_rag \
  --vector-store "data/.../vector_store" \
  --device cuda:0 \
  --filter code       # or 'manuscript' or 'all'
```

In the interactive prompt, you can also switch filters on the fly:

```
>>> filter:code
Filter: code
>>> REAL*8 dimension asset grid
  [1] rerank=0.9256 | type=code | ...
>>> filter:all
Filter: all (no filter)
```

##### Programmatic Usage

```python
from utils.s3_RAG.hybrid_rag import HybridRAG

rag = HybridRAG(
    vector_store_dir="data/.../vector_store",
    device="cuda:0",
)

results = rag.query("What drives wealth concentration?", final_top_k=5)
for r in results:
    print(r["rerank_score"], r["metadata"]["content_type"], r["text"][:100])
```

#### Generation 🔲 (To Be Implemented)

The generation component — using Multimodal LLMs to produce context-aware answers from retrieved passages — is planned for future development.

### Solving the Global Query Problem

Chunk-level retrieval is strong on *local* questions ("what is the Euler equation used in this paper?") but fails on *global*, cross-document ones ("which papers share the same mathematical model?", "how do these papers differ in their computational methods?"). A query like this needs paper-level identity, not a bag of passages — top-k dense + BM25 results from a single paper's chunks can drown out the smaller evidence from other papers, and chunk text rarely contains the canonical model/method terms needed to compare papers.

The orchestrator under [utils/orchestrator/](utils/orchestrator/) addresses this through a **profile-first retrieval path** backed by a second Qdrant collection (`paper_profiles`) that stores one structured record per paper.

#### 1. Paper-level identity index — [paper_profiler.py](utils/orchestrator/paper_profiler.py)

`build_paper_profile()` runs the LLM over each paper's full manuscript + Fortran digest and emits a structured JSON profile with canonical fields:

| Field | Purpose |
|-------|---------|
| `research_question`, `summary` | One-line identity of the paper |
| `mathematical_models` | Canonicalised model families (e.g. `overlapping-generations`, `heterogeneous-agent Bewley`) |
| `key_equations` | Distinctive equations (`Euler`, `Bellman`, `HJB`) |
| `economic_concepts` | Central concepts (wealth inequality, idiosyncratic risk) |
| `computational_methods` | Numerical methods (VFI, EGM, Krusell-Smith) |
| `data_sources`, `main_findings`, `keywords` | Empirical + narrative anchors |

`profile_to_embed_text()` composes these fields into a dense embedding input, and `profile_to_payload()` stores the lists as Qdrant payload for filter-based lookup. A deterministic `compute_profile_overlap()` uses canonicalisation tables (`_MODEL_CANON`, `_METHOD_CANON`) to collapse synonyms (`OLG` = `overlapping-generations` = `life-cycle`) and emit pairwise overlap text **before** the LLM sees any chunks — so cross-paper comparisons quote concrete shared fields instead of hallucinating them.

#### 2. Query scope router — [query_router.py](utils/orchestrator/query_router.py)

`classify_query()` decides whether a query is `local` or `global`:

- A **heuristic regex** (`_GLOBAL_PATTERNS`) catches obviously comparative phrasing: *"which papers…"*, *"compare"*, *"differ"*, *"share the same model"*, *"across papers"*. This avoids an LLM call for clear cases.
- Otherwise an **LLM classifier** returns `{scope, focus_concepts}`, where `focus_concepts` are canonicalised concept phrases that steer profile retrieval.

Global queries trigger the profile-first path; local queries go through the original chunk-first pipeline unchanged.

#### 3. Paper-profile injection at ingestion — [ingest_paper.py](utils/orchestrator/ingest_paper.py)

The ingestion pipeline extracts `paper_title` and `authors` from the first 600 words of the MinerU markdown and injects them into every output JSON (`_inject_metadata_into_json`). This is the prerequisite that makes all downstream paper-level operations possible — diversification, inventory listing, and per-paper grouping in the context builder all key off `paper_title`.

#### 4. Retrofitting existing databases — [backfill_profiles.py](utils/orchestrator/backfill_profiles.py)

For databases created before the profile collection existed, `backfill()` reads `paper_registry.json`, regenerates each paper's profile via the LLM, and upserts it into the `paper_profiles` Qdrant collection. `--skip-existing` makes it idempotent so repeated runs only fill gaps.

```bash
python -m utils.orchestrator.backfill_profiles --db-path ./db
```

#### 5. Profile-aware query engine — [rag_query.py](utils/orchestrator/rag_query.py)

`RAGQueryEngine` detects the `paper_profiles` collection at startup and enables global-query routing. When `classify_query` returns `scope="global"`, the engine:

1. **Retrieves from the profile collection first** — top candidate papers by profile-level similarity to the query + focus concepts.
2. **Drills into each candidate paper's chunks** with filtered retrieval (`where_filter={"paper_title": ...}`), so evidence is gathered *per paper* instead of being dominated by a single dense match.
3. **Diversifies chunks via round-robin** (`_diversify_results`) across `paper_title` groups, guaranteeing top-k contains representatives from every candidate paper.
4. **Builds a profile-aware context** (`_build_context` with `profiles=...`): the prompt now starts with a `# PAPER PROFILES` section rendered by `format_profile_block`, followed by a deterministic `# CROSS-PAPER OVERLAP ANALYSIS` from `compute_profile_overlap`, and only then the individual passages grouped under `# PAPER: <title>` headers.

The result is that the LLM anchors on paper identity *first* (who is who, what models they use, which concepts they share), reads pre-computed overlaps *second*, and drops into passage-level detail *third* — the order that comparative reasoning actually requires.

#### Summary

```
User query
    │
    ▼
query_router.classify_query  ── scope? ──► local ──► original chunk pipeline
    │
    ▼ global
profile collection (paper_profiles)  ──► candidate papers
    │
    ▼
per-paper filtered chunk retrieval + round-robin diversification
    │
    ▼
context: PAPER PROFILES  →  OVERLAP ANALYSIS  →  per-paper passages
    │
    ▼
LLM answer grounded in paper identity, not just chunks
```
