# NTU DAVID RAG

**Project Status**: Active Development — all three planned phases are implemented end-to-end on the vector RAG retrieval path.

This project builds a retrieval-augmented generation system specialised for economics research papers and their accompanying Fortran codebases. It ingests PDFs and source code, stores structured artefacts plus embeddings, and answers both focused ("what is the Euler equation in this paper?") and comparative ("which papers share the same mathematical model?") questions.

![System Design](docs/initial_system_desgin.png)

Architecture diagram for the retrieval stack lives under [docs/tikz/](docs/tikz/):

- [docs/tikz/vector_rag.pdf](docs/tikz/vector_rag.pdf) — hybrid BM25 + dense + reranker pipeline.

## Repository layout

```
NTU-DAVID-RAG/
├── utils/
│   ├── s1_data_ingestion/   # Fortran digestion + MinerU-based PDF extraction
│   ├── s2_embedding/        # Chunking, embedder, Qdrant vector store, CLI
│   ├── s3_RAG/              # BM25, dense, RRF fusion, cross-encoder rerank
│   ├── orchestrator/        # Ingestion pipeline + profile-aware query engine
│   └── llm_clients/         # Gemini, OpenAI, and local (OpenAI-compatible) clients
├── docker/
│   ├── docker-compose.yml   # Unified stack: embedding-server + rag-web + proxy
│   ├── embedding_server/    # Shared HTTP embedder + reranker (owns the GPU)
│   ├── RAG/                 # Flask API + React chat UI for the vector RAG
│   ├── proxy/               # nginx that fronts the UI under one port
│   └── local_llm/           # Ollama compose file for the answer LLM
├── RAG_quality_test/        # Report-style and Ragas-based evaluators
├── tests/                   # Pytest suites per stage
├── docs/                    # Diagrams and workflow notes
├── db/                      # Per-user Qdrant + registry, scoped under `users/<user_id>/`
├── data/                    # Per-user paper/code artefacts, scoped under `users/<user_id>/`
├── CHANGELOG.md
└── README.md
```

Each subpackage ships its own `readme.md` with module-level detail — the sections below point into them rather than duplicating their contents.

## Architecture at a glance

| Stage | Package | Key modules |
|-------|---------|-------------|
| **Ingestion** | [`utils/s1_data_ingestion/`](utils/s1_data_ingestion/) | `fortran_code_digest.py`, `pdf_extract.py` (MinerU-backed) |
| **Embedding & storage** | [`utils/s2_embedding/`](utils/s2_embedding/) | `chunker.py`, `embedder.py`, `qdrant_store.py`, `run_embed.py` |
| **Hybrid retrieval** | [`utils/s3_RAG/`](utils/s3_RAG/) | `bm25_retriever.py`, `dense_retriever.py`, `reranker.py`, `hybrid_rag.py` |
| **Orchestration** | [`utils/orchestrator/`](utils/orchestrator/) | `ingest_paper.py`, `store_to_db.py`, `rag_query.py`, `paper_profiler.py`, `query_router.py` |

Default models (overridable per service):

- **Embedder**: `Alibaba-NLP/gte-Qwen2-7B-instruct` (3584-dim, asymmetric query/passage prefixes applied server-side).
- **Reranker**: `BAAI/bge-reranker-v2-m3` (cross-encoder, scores the top-50 fused candidates).
- **Vector store**: Qdrant on-disk, isolated per user — `db/users/<user_id>/`.

## Running the stack

The canonical way to bring up the retrieval service is the unified Docker compose in [docker/docker-compose.yml](docker/docker-compose.yml). A single `embedding-server` container owns the GPU and loads the 7B embedder + reranker once; `rag-web` is a CPU-only Flask backend that calls it over HTTP.

```bash
cd docker
docker compose up --build
```

Endpoints exposed by the nginx proxy (default `UNIFIED_PORT=3006`):

| Path | Served by |
|------|-----------|
| `/`        | Redirects to `/rag/` |
| `/rag/`    | Vector RAG chat UI |

Every authenticated user gets their own Qdrant store, paper registry, and ingest output under `users/<user_id>/`, so two users running side-by-side never see each other's papers or vectors. The per-service compose file under `docker/RAG/` remains usable for running the backend standalone with its own embedder — see its `readme.md` for details.

An answer LLM is still required. Start one from `docker/local_llm/` — the Gemma4-31B (Ollama) compose file is wired to the `OPENAI_API_BASE` that the web backend expects.

## Quick Start (Python environment)

Use this path when working on `utils/` modules directly — chunking, retrieval, the orchestrator — outside the Docker stack.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

MinerU (used by `utils/s1_data_ingestion/pdf_extract.py`) is installed separately into `utils/data_preprocess/MinerU/`; see its upstream docs. For LaTeX-rendered comparison outputs, install a TeX distribution:

```bash
# Ubuntu/Debian
sudo apt-get install -y texlive-latex-base texlive-latex-extra
# macOS
brew install --cask mactex
```

Embed a paper into the vector store:

```bash
CUDA_VISIBLE_DEVICES=2 python -m utils.s2_embedding.run_embed \
  --manuscript "data/<Paper>/manuscript_parsed_mineru/Manuscript/hybrid_auto/Manuscript_content_list.json" \
  --fortran    "data/<Paper>/RAG_Chunks/fortran_chunks.json" \
  --output     "data/<Paper>/vector_store" \
  --device cuda:0 \
  --test-query
```

Query it interactively:

```bash
CUDA_VISIBLE_DEVICES=2 python -m utils.s3_RAG.run_rag \
  --vector-store "data/<Paper>/vector_store" \
  --device cuda:0
```

## Running tests

All tests assume the virtual environment is active and run from the project root.

```bash
source .venv/bin/activate

# Stage 1 — Fortran digestion, PDF extract, local-LLM smoke tests
python -m tests.test_s1_fortran_preprocess
python -m tests.test_s1_pdf_extract
python -m tests.test_s1_llm

# Stage 2 — chunking + embedder + ChromaDB round-trip (legacy CLI)
CUDA_VISIBLE_DEVICES=2 python -m tests.test_s2_embedding

# Stage 3 — BM25 / dense / RRF / reranker full pipeline
CUDA_VISIBLE_DEVICES=2 python -m tests.test_s3_rag

# Orchestrator — end-to-end ingest, store, and query
python -m tests.test_orch_ingest_paper_n_code
python -m tests.test_orch_store_to_db
python -m tests.test_orch_rag_query

# LLM clients (needs GEMINI_API_KEY / OPENAI_API_KEY)
python -m tests.test_llm_clients
```

Stage-2 and Stage-3 tests require a GPU and an existing vector store under `data/<paper>/vector_store/`.

## Unified RAG Stack (Recommended)

The top-level [docker/docker-compose.yml](docker/docker-compose.yml) brings up the vector RAG service behind an nginx proxy, sharing one GPU-resident embedding/reranker container.

Architecture (see also the TikZ diagram [docs/tikz/vector_rag.pdf](docs/tikz/vector_rag.pdf)):

```
                    ┌───────────────────────────────┐
                    │  nginx proxy  (one port)      │
                    │  /  →  /rag/                  │
                    └──────────────┬────────────────┘
                                   │
                            ┌──────▼─────┐
                            │  rag-web   │   CPU-only Flask backend,
                            │  (Flask)   │   chat-style React frontend
                            └──────┬─────┘
                                   │
                    ┌──────────────▼────────────────┐
                    │  embedding-server (GPU)       │   gte-Qwen2-7B +
                    │  HTTP /embed, /rerank         │   bge-reranker-v2-m3,
                    └───────────────────────────────┘   loaded once
```

Per-service internals (container layout + query pipeline):

<p align="center">
  <img src="docs/tikz/vector_rag.png" alt="Vector RAG — container architecture and query workflow" width="640">
  <br>
  <em>Vector RAG: nginx → Flask → shared embedding server, with BM25 + dense + RRF + cross-encoder rerank feeding the LLM.</em>
</p>

Key points:

- **Shared GPU embedder.** `EmbeddingModel` and `Reranker` have a remote HTTP mode (enabled by `RAG_EMBEDDING_SERVER_URL` / `RAG_RERANKER_SERVER_URL`). The backend delegates all encoding/scoring to the embedding container, so the 7B embedder loads once.
- **Isolated databases.** `rag-web` uses `db/` + `data/`, partitioned per authenticated user under `users/<user_id>/`, so users never share Qdrant collections, registries, or ingest output. The per-service compose file under [docker/RAG/](docker/RAG/) still works standalone.
- **Chat-style UI.** The frontend is a persistent chat shell: message bubbles, follow-up questions, stop / regenerate / delete, localStorage-backed history, Markdown export.
- **URL-prefix aware.** The frontend is built with `VITE_BASE_PATH` so assets and API calls resolve correctly when served under `/rag/` behind the proxy.

Start it:

```bash
cd docker
cp .env.example .env
# Edit .env if defaults don't fit: UNIFIED_PORT (default 3006),
# EMBEDDING_GPU (default 1), EMBEDDING_MODEL, RERANKER_MODEL, etc.
docker compose up --build
```

Then open `http://<host>:3006/`. The embedding server has a long startup grace (~10 min on a cold HF cache) while the 7B weights download.

## Quality evaluation

[RAG_quality_test/](RAG_quality_test/) contains two complementary evaluators for the vector RAG:

- `rag_quality_test.py` — report-style regression runner.
- `rag_ragas_eval.py` — reference-free Ragas metrics, with `local` / `openai` / `gemini` judges.

```bash
cd docker/local_llm && docker compose -f docker-compose.gemma4_31b_ollama.yml up -d
cd ../RAG && docker compose up -d --build rag-web

source .venv/bin/activate
pip install -r RAG_quality_test/requirements-ragas.txt
python RAG_quality_test/rag_ragas_eval.py
```

See [RAG_quality_test/README.md](RAG_quality_test/README.md) for the full evaluator notes and CLI options.

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
├── docker/                         # Dockerized stack
│   ├── docker-compose.yml          # Unified RAG + shared embedding server
│   ├── embedding_server/           # GPU container: gte-Qwen2-7B + bge-reranker HTTP service
│   ├── proxy/                      # nginx (/ → /rag/)
│   ├── RAG/                        # Standalone vector-RAG service (Flask + React)
│   └── local_llm/                  # Local OpenAI-compatible LLM endpoint (Ollama)
├── docs/
│   └── tikz/                       # Architecture diagrams (vector_rag)
├── utils/
│   ├── s1_data_ingestion/          # Fortran digestion + MinerU PDF extraction
│   ├── s2_embedding/               # Chunking + embedding (Qdrant; legacy ChromaDB CLI)
│   ├── s3_RAG/                     # Hybrid BM25 + dense + reranker pipeline
│   ├── orchestrator/               # Profile-first global-query router (production retrieval)
│   ├── llm_clients/                # Gemini, OpenAI, and local (OpenAI-compatible) clients
│   └── auth/                       # Shared Flask auth blueprint + Alembic migrations
└── README.md
```

## Tools Documentation

### [Phase 1] Data Ingestion (`utils/s1_data_ingestion/`)

Two stage-1 modules feed every paper into the RAG pipeline:

- [`fortran_code_digest.py`](utils/s1_data_ingestion/fortran_code_digest.py) — extracts Fortran source files from a mixed input directory and emits a JSON digest of routines, global variables, and dependency graph used downstream by the chunker.
- [`pdf_extract.py`](utils/s1_data_ingestion/pdf_extract.py) — wraps [MinerU](https://github.com/opendatalab/MinerU) (layout-aware PDF parser) to produce a structured `Manuscript_content_list.json` with text, figures, tables, and bounding boxes.

MinerU is **not** in `requirements.txt` because of its heavy CUDA dependencies — install it separately into `utils/data_preprocess/MinerU/` per the upstream instructions before running ingestion.

Older standalone preprocessing trees (Dolphin, pdf_crawler, vlm_formula_to_latex, s2orc-doc2json, Paper2Code) were removed; see [CHANGELOG.md](CHANGELOG.md). The bits still in use are now invoked from `utils/s1_data_ingestion/` and from the orchestrator.

### [Phase 2] RAG Database & Embeddings

The `utils/s2_embedding/` directory contains the embedding pipeline that chunks, embeds, and stores academic paper text and Fortran code into a local vector database for retrieval.

#### Architecture Overview

```
JSON Data Files ──→ Chunker ──→ Embedding Model ──→ Qdrant Vector Store
                   (chunker.py)  (embedder.py)      (qdrant_store.py)
```

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Embedding Model** | `Alibaba-NLP/gte-Qwen2-7B-instruct` (default) | Top-tier MTEB retrieval scores on academic text + code; `BAAI/bge-large-en-v1.5` still selectable via `--model` |
| **Vector Database** | Qdrant (persistent on-disk, production) | Per-user isolation under `db/users/<user_id>/`; metadata filtering, payload indices, on-disk HNSW. A legacy ChromaDB wrapper (`vector_store.py`) is still in the tree for the standalone CLI in `run_embed.py` but is not used by the orchestrator. |
| **Chunking** | Section-aware (text) + Line-based (code) | Preserves semantic coherence for papers; summary-prefixed for code |

#### File Structure

```
utils/s2_embedding/
├── __init__.py          # Package init
├── chunker.py           # Chunking strategies for manuscript text and Fortran code
├── embedder.py          # Embedding model wrapper (gte-Qwen2-7B-instruct by default; supports remote HTTP mode)
├── qdrant_store.py      # Qdrant on-disk vector store wrapper (production)
├── vector_store.py      # Legacy ChromaDB persistent vector store wrapper
└── run_embed.py         # Legacy CLI (chunk → embed → store via ChromaDB)
```

Production ingest goes through [`utils/orchestrator/ingest_paper.py`](utils/orchestrator/ingest_paper.py) → [`store_to_db.py`](utils/orchestrator/store_to_db.py), which writes to Qdrant via `qdrant_store.py`. The standalone `run_embed.py` CLI still uses the legacy ChromaDB path and is kept for offline experimentation.

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
pip install -r requirements.txt  # includes sentence-transformers and qdrant-client
```

**Run the embedding pipeline (legacy ChromaDB CLI — production goes through the orchestrator)**:

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
| `--model` | No | Embedding model name (default: `Alibaba-NLP/gte-Qwen2-7B-instruct`) |
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
| **Dense Retrieval** | Qdrant + `Alibaba-NLP/gte-Qwen2-7B-instruct` (production via `orchestrator/rag_query.py`); a legacy ChromaDB-backed `DenseRetriever` is still in the tree for the standalone CLI | Semantic similarity for concept-level queries |
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
├── dense_retriever.py     # Legacy ChromaDB-based dense retriever (standalone CLI only)
├── reranker.py            # BGE-Reranker-v2-m3 cross-encoder
├── hybrid_rag.py          # Legacy pipeline: BM25 + Dense (ChromaDB) + RRF + Reranker
└── run_rag.py             # Legacy interactive CLI query interface
```

Production retrieval lives in [`utils/orchestrator/rag_query.py`](utils/orchestrator/rag_query.py), which uses `qdrant_store.QdrantVectorStore` for dense retrieval, plus `bm25_retriever` and `reranker` from this package. `dense_retriever.py`, `hybrid_rag.py`, and `run_rag.py` are kept for the offline ChromaDB-backed CLI and are not part of the Docker stack.

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

#### Generation ✅

Answer generation is shipped end-to-end through the Dockerized RAG service (see **Unified RAG Stack** above). It uses the retrieval pipeline above, feeds the top passages into an LLM (local or API), and returns a streamed, Markdown-rendered answer in a chat-style web UI.

### Solving the Global Query Problem

Chunk-level retrieval is strong on *local* questions ("what is the Euler equation used in this paper?") but fails on *global*, cross-document ones ("which papers share the same mathematical model?", "how do these papers differ in their computational methods?"). A query like this needs paper-level identity, not a bag of passages — top-k dense + BM25 results from a single paper's chunks can drown out the smaller evidence from other papers, and chunk text rarely contains the canonical model/method terms needed to compare papers.

The project tackles this through profile-first retrieval in [`utils/orchestrator/`](utils/orchestrator/).

A second Qdrant collection, `paper_profiles`, stores one structured record per paper:

| Field | Purpose |
|-------|---------|
| `research_question`, `summary` | One-line identity of the paper |
| `mathematical_models` | Canonicalised model families (e.g. `overlapping-generations`, `heterogeneous-agent Bewley`) |
| `key_equations` | Distinctive equations (`Euler`, `Bellman`, `HJB`) |
| `economic_concepts` | Central concepts (wealth inequality, idiosyncratic risk) |
| `computational_methods` | Numerical methods (VFI, EGM, Krusell-Smith) |
| `data_sources`, `main_findings`, `keywords` | Empirical + narrative anchors |

`paper_profiler.build_paper_profile()` emits these via the LLM; `compute_profile_overlap()` uses canonicalisation tables (`_MODEL_CANON`, `_METHOD_CANON`) to collapse synonyms (`OLG` = `overlapping-generations` = `life-cycle`) so cross-paper comparisons quote concrete shared fields instead of hallucinating them.

`query_router.classify_query()` decides whether a query is `local` or `global` — a cheap regex catches obvious comparative phrasing, and an LLM classifier handles the rest. Global queries route through `RAGQueryEngine`, which retrieves from `paper_profiles` first, drills into each candidate paper's chunks with a `paper_title` filter, round-robin-diversifies the top-k, and builds a context ordered `PAPER PROFILES → OVERLAP ANALYSIS → per-paper passages`. Local queries go through the original chunk pipeline unchanged.

For databases created before the profile collection existed, `utils/orchestrator/backfill_profiles.py` regenerates and upserts profiles idempotently:

```bash
python -m utils.orchestrator.backfill_profiles --db-path ./db
```

## Change history

See [CHANGELOG.md](CHANGELOG.md) for the user-visible change log.
