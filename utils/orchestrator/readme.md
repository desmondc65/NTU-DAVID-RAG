# Orchestrator Directory Deep Dive

This directory contains the high-level orchestration layer for the project.  
The orchestrator modules do not implement low-level extraction, embedding, or retrieval algorithms themselves. Instead, they coordinate those lower-level components from other packages and enforce a consistent end-to-end workflow.

## Directory Contents

- `__init__.py`
- `ingest_paper.py`
- `store_to_db.py`
- `rag_query.py`
- `readme.md`

Non-source artifact:

- `__pycache__/` (Python bytecode cache generated automatically at runtime)

---

## Architectural Role Of This Package

At a system level, these files split into three orchestration phases:

1. Ingestion orchestration: `ingest_paper.py`
2. Storage orchestration: `store_to_db.py`
3. Query orchestration: `rag_query.py`

Typical lifecycle:

1. `ingest_paper_and_code(...)` extracts and enriches paper/code artifacts.
2. `store_ingested_data(...)` chunks + embeds + upserts artifacts into Qdrant.
3. `RAGQueryEngine.query(...)` retrieves, reranks, builds context, and calls the LLM.

This separation keeps responsibilities clear:

- Ingestion deals with files and metadata.
- Storage deals with chunking/embedding/vector persistence.
- Query deals with retrieval quality and answer generation.

## Models Used (Including Embeddings)

This orchestrator package uses three model categories: generation LLMs, embedding models, and rerankers.

Default model values in current code:

- Generation LLM (metadata extraction, summaries, answer generation):
	- `qwen2.5-vl-72b-instruct`
	- Configurable via function arguments and/or:
		- `LLM_MODEL_NAME`
		- `LOCAL_LLM_BASE_URL`
		- `LOCAL_LLM_API_KEY`

- Embedding model (vector creation for storage and dense query retrieval):
	- `BAAI/bge-large-en-v1.5`
	- Used in:
		- `store_to_db.py` (`store_ingested_data(..., embedding_model=...)`)
		- `rag_query.py` (`RAGQueryEngine(..., embedding_model=...)`)

- Reranker model (post-retrieval relevance reranking):
	- `BAAI/bge-reranker-v2-m3`
	- Used in:
		- `rag_query.py` (`RAGQueryEngine(..., reranker_model=...)`)

Device controls (query-time embedding/reranking):

- `RAG_DEVICE`
- `RAG_EMBEDDING_DEVICE`
- `RAG_RERANKER_DEVICE`

Notes:

- Storage and query defaults are aligned on the same embedding family (`BAAI/bge-large-en-v1.5`), which helps keep retrieval spaces consistent.
- Embedding and reranker model names are constructor parameters, so runtime callers can swap models without editing source files.

---

## File-By-File Details

## `__init__.py`

Current state:

- Empty module initializer.

Purpose:

- Marks `utils.orchestrator` as a Python package.
- Enables imports such as `from utils.orchestrator.ingest_paper import ingest_paper_and_code`.

Operational impact:

- No runtime logic.
- No side effects.

---

## `ingest_paper.py`

### What this file does

This module performs end-to-end ingestion of one PDF paper plus one companion Fortran source file. It creates a canonical paper folder, enriches extracted assets, generates metadata, and produces a normalized artifact set ready for chunking and indexing.

It orchestrates the Stage-1 ingestion utilities from:

- `utils.s1_data_ingestion.pdf_extract`
- `utils.s1_data_ingestion.fortran_code_digest`

And metadata extraction through:

- `utils.llm_clients.local_llm.LocalLLMClient`

### Core public API

- `ingest_paper_and_code(pdf_path, fortran_path, output_dir, db_path=None, ..., model_name=None, base_url=None, api_key=None) -> Dict[str, str]`

Primary return fields:

- `paper_dir`
- `md_path`
- `content_list_json`
- `metadata_json`
- `fortran_digest_json`
- `source_pdf_path`
- `source_fortran_path`

### Pipeline behavior (5 explicit steps)

1. PDF extraction via MinerU
- Runs `extract_pdf_mineru(...)` on a staged copy of the input PDF.
- Produces markdown (`.md`) and content list JSON (`_content_list.json`) under a temporary extract directory.

2. Paper metadata extraction via LLM
- Reads first 600 words of the markdown.
- Calls `LocalLLMClient.generate_response(...)` with JSON response mode.
- Extracts and normalizes:
	- `paper_title`
	- `authors`

3. Asset enrichment for non-text content
- Calls:
	- `describe_mineru_images(...)`
	- `describe_mineru_equations(...)`
	- `describe_mineru_tables(...)`
- These enrich `_content_list.json` entries so non-text objects become queryable/indexable later.

4. Fortran digestion and summary
- Reads Fortran source text.
- Calls `digest_fortran_code(...)` to produce function-level structured digest JSON.
- Calls `summarize_fortran_digest(...)` to add higher-level summaries suitable for indexing.

5. Metadata injection into output JSONs
- Ensures manuscript content JSON and Fortran digest JSON include shared top-level metadata keys (`paper_title`, `authors`, and additional path metadata).

### Staging and final output layout strategy

This module uses a safe two-phase write strategy:

- Temporary workspace under: `output_dir/_tmp_ingest/<uuid>/...`
- Final canonical directory under: `output_dir/<safe-paper-title>/...`

Key safety goals:

- Avoid partially-written final directories if any step fails.
- Keep source copies (`source/`) and extraction outputs (`ingest_output/`) together inside a paper-specific folder.
- Guarantee cleanup of temporary data in `finally` via `shutil.rmtree(...)`.

### Naming and collision handling

- `_safe_title_dirname(title)` sanitizes title into filesystem-safe folder names.
- `_unique_dir(base_dir)` appends numeric suffixes (`-2`, `-3`, ...) when the paper directory already exists.

### Helper functions and roles

- `_first_n_words(text, n=600)`:
	- Limits prompt size for metadata extraction.

- `extract_paper_metadata(md_path, ...)`:
	- LLM-backed metadata extraction contract.
	- Expects JSON output.
	- Applies defaults from environment if model/base URL/API key not supplied.

- `_inject_metadata_into_json(json_path, metadata)`:
	- Adds metadata to JSON outputs.
	- Special-cases list JSON by wrapping into object with `items`.

### Environment variables consumed

- `LLM_MODEL_NAME`
- `LOCAL_LLM_BASE_URL`
- `LOCAL_LLM_API_KEY`

### Side effects and outputs

- Copies and moves input files.
- Writes multiple JSON artifacts.
- Mutates generated content JSON in-place to inject metadata.
- Logs progress at each pipeline step.

### Notable implementation choices

- Uses UTF-8 with `ensure_ascii=False` when writing JSON, preserving non-ASCII metadata.
- Records many path fields into metadata (`paper_dir`, source paths, ingest output paths), which helps downstream systems avoid path reconstruction.
- Includes CLI smoke-test block under `if __name__ == "__main__":` for local manual execution.

---

## `store_to_db.py`

### What this file does

This module transforms ingestion artifacts into vector-store documents and writes them to Qdrant. It also maintains a paper registry for discoverability.

It orchestrates Stage-2 components:

- `utils.s2_embedding.embedder.EmbeddingModel`
- `utils.s2_embedding.qdrant_store.QdrantVectorStore`

### Core public API

- `store_ingested_data(ingest_result, db_path, collection_name="rag_embeddings", embedding_model="BAAI/bge-large-en-v1.5", embedding_device=None) -> Dict[str, int]`

Expected `ingest_result` keys:

- `content_list_json`
- `fortran_digest_json`
- optionally `metadata_json` for registry update

Return fields:

- `manuscript_chunks`
- `fortran_chunks`
- `total_in_db`

### Main workflow stages

1. Chunking
- `chunk_content_list(...)` for manuscript/non-text artifacts.
- `chunk_fortran_digest(...)` for function summaries.

2. Embedding
- Builds text list from all chunks.
- Calls `EmbeddingModel.embed_documents(...)`.

3. Store/upsert in Qdrant
- Creates deterministic IDs with `_make_id(...)`.
- Writes texts + embeddings + metadata via `QdrantVectorStore.add_documents(...)`.

4. Update registry
- Reads title/authors from `metadata_json`.
- Upserts a record in `paper_registry.json`.

### Manuscript chunking model (`chunk_content_list`)

Input assumptions:

- Content JSON may be either:
	- object with `items`, `paper_title`, `authors`
	- or plain list (legacy fallback)

Type handling:

- `text`:
	- Merged into rolling chunks using token estimate and overlap.
	- Metadata includes `content_type="manuscript"`, page indices, sequence index, and source file.

- `image`, `equation`, `table`:
	- One document per item.
	- Uses `description` as searchable/indexed text.
	- Stores rich typed metadata:
		- image: absolute/relative image path
		- equation: original LaTeX text
		- table: caption and table body

- `discarded`:
	- Skipped.

Order preservation:

- Tracks original item order using `sequence_idx`.
- Flushes pending text before emitting non-text item docs, preserving document sequence.

### Fortran digest chunking model (`chunk_fortran_digest`)

- One vector doc per key function.
- Uses `summary_index` as embedding text.
- Carries metadata such as function name, core purpose, dependencies, key variables, source file, and sequence index.

### Deterministic document IDs

- `_make_id(content_type, source, index)` computes MD5 over stable tuple-like string.
- Benefits:
	- repeat ingestion of same source/index yields same ID
	- supports idempotent updates at vector-store level

### Registry maintenance (`_update_paper_registry`)

- Maintains JSON list at `<db_path>/paper_registry.json`.
- Upserts by `paper_title`.
- Refreshes ingest timestamp and canonical paths on updates.

### Environment and dependencies

- Loads `.env` via `dotenv.load_dotenv()`.
- Embedding model/device passed through to sentence-transformers wrapper.

Embedding model details:

- Default: `BAAI/bge-large-en-v1.5`
- Override path: `store_ingested_data(..., embedding_model=...)`
- Device override: `store_ingested_data(..., embedding_device=...)`

### Side effects and outputs

- Creates DB directory if missing.
- Writes/updates Qdrant persisted data.
- Writes/updates registry JSON.
- Logs stage timing and throughput for embedding step.

### Notable implementation details

- Uses rough token estimation helper `_estimate_tokens(...)` with factor 1.33 words-to-tokens.
- Chooses vector size dynamically from first produced embedding.
- Ensures store closure in `finally` to release Qdrant resources.
- Includes manual CLI test block.

---

## `rag_query.py`

### What this file does

This module provides the online retrieval-and-generation engine used at query time. It combines dense retrieval, lexical retrieval, rank fusion, reranking, context assembly, and LLM answer generation.

It orchestrates Stage-2 and Stage-3 components:

- Dense retrieval: `EmbeddingModel` + `QdrantVectorStore`
- Sparse retrieval: `BM25Retriever`
- Relevance reranking: `Reranker`
- Generation: `LocalLLMClient`

### Main classes and functions

- `_resolve_torch_device(preferred, fallback="cpu")`
- `QdrantDenseRetriever`
- `_reciprocal_rank_fusion(result_lists, k=60)`
- `_build_context(results, max_context_tokens=4000)`
- `RAGQueryEngine`

### Device resolution behavior

`_resolve_torch_device(...)` protects runtime stability:

- If a CUDA device is requested but unavailable, it falls back to CPU.
- If torch import or CUDA check fails, it falls back safely.
- Prevents initialization crashes in environments without functional GPU runtime.

### Dense retriever wrapper (`QdrantDenseRetriever`)

Responsibilities:

- Owns Qdrant store connection.
- Owns embedding model for query-time vectorization.
- Implements:
	- `retrieve(...)`: similarity search result normalization to list-of-dicts.
	- `get_all_documents(...)`: full collection scroll for BM25 indexing bootstrap.
	- `close()`: resource cleanup.

### Fusion and reranking strategy

Hybrid retrieval path in `RAGQueryEngine.retrieve(...)`:

1. BM25 top-N lexical retrieval.
2. Dense vector top-N retrieval.
3. Merge with Reciprocal Rank Fusion.
4. Keep top candidates (currently 50).
5. Rerank with cross-encoder and return final top-K.

Why this design helps:

- BM25 catches exact keyword/identifier matches.
- Dense retrieval captures semantic similarity.
- RRF gives robust blending without requiring score calibration.
- Cross-encoder reranker improves final precision.

### Context builder (`_build_context`)

This function does substantial prompt-assembly logic:

- Groups retrieved passages by `paper_title` first.
- Sorts each paper group by `sequence_idx` to preserve source ordering.
- Appends non-paper items afterward.
- Formats each block with typed headers and content-specific metadata.

Type-aware formatting examples:

- `fortran_function`: function name, purpose, dependencies, key variables.
- `equation`: includes `equation_latex`.
- `table`: includes caption and table body.
- `image`: includes image path metadata.

Token budgeting:

- Uses rough block token estimate (`words * 1.33`).
- Stops adding blocks once `max_context_tokens` would be exceeded.

### End-to-end query API (`RAGQueryEngine.query`)

Flow:

1. Retrieve source passages.
2. Build formatted context.
3. Create strict system prompt embedding that context.
4. Call LLM with user query + system context.
5. Return answer, sources, and context.

Returned object:

- `answer`: LLM text output.
- `sources`: reranked source list.
- `context`: exact assembled context string sent to LLM.

### Paper registry integration

- On initialization, loads `paper_registry.json` if present.
- Exposes `list_papers()` for frontend/API paper lists.

### Environment variables consumed

- `RAG_DEVICE`
- `RAG_EMBEDDING_DEVICE`
- `RAG_RERANKER_DEVICE`
- `LLM_MODEL_NAME`
- `LOCAL_LLM_BASE_URL`
- `LOCAL_LLM_API_KEY`

Model defaults in this module:

- Dense embedding model: `BAAI/bge-large-en-v1.5`
- Cross-encoder reranker model: `BAAI/bge-reranker-v2-m3`
- Generation model: resolved from `LLM_MODEL_NAME` (fallback `qwen2.5-vl-72b-instruct`)

### Side effects and operational notes

- Opens local Qdrant connection.
- Builds BM25 index in memory from all Qdrant docs at engine startup.
- Includes a debug `print(system_prompt)` call before generation.
- Provides `close()` for retriever resource cleanup.

### Notable implementation detail

- Constructor logs selected devices and component-loading stages to improve traceability during startup.

---

## `readme.md`

Current role:

- Human documentation for this directory.

Recommended future additions:

- Minimal usage snippets for each public orchestrator entrypoint.
- Failure-mode troubleshooting matrix (missing files, malformed JSON, empty retrieval results, unavailable CUDA).
- Contract examples for expected JSON schemas (content list, digest, registry).

---

## Cross-File Contracts And Data Interfaces

### Contract A: Ingestion output into storage

`ingest_paper_and_code(...)` returns paths consumed by `store_ingested_data(...)`.

Critical fields:

- `content_list_json`
- `fortran_digest_json`
- `metadata_json`

### Contract B: Stored metadata into query context

Metadata fields written during chunking/storage become retrieval-time prompt features in `rag_query.py`:

- `content_type`
- `paper_title`
- `authors`
- `sequence_idx`
- rich item fields (`equation_latex`, `table_caption`, `img_path`, etc.)

### Contract C: Registry as discoverability layer

`store_to_db.py` writes `paper_registry.json`, and `rag_query.py` reads it through `list_papers()`.

---

## Operational Summary

- `ingest_paper.py` creates high-quality, metadata-rich artifacts from raw PDF + Fortran inputs.
- `store_to_db.py` converts those artifacts to typed vector documents and persists them.
- `rag_query.py` retrieves and synthesizes answers from those stored documents using a hybrid retrieval stack.

Together, these three modules are the orchestration backbone for the repository's retrieval-augmented paper/code analysis workflow.
