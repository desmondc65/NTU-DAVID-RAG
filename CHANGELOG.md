# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Unified Docker stack** (`docker/docker-compose.yml`) — one
	`embedding-server` container owns the GPU and serves `rag-web` over
	HTTP, fronted by an nginx proxy that exposes `/rag/` under a single port.
- **Remote-HTTP mode for embedding + reranking** — `EmbeddingModel` and
	`Reranker` can call the shared `embedding-server` instead of loading
	weights locally, so the 7B `gte-Qwen2-7B-instruct` embedder occupies a
	single GPU slot across the whole stack.
- **React + Vite + TypeScript chat UI** for the vector RAG, rendering
	tables, math (KaTeX), and source passages inline.
- **URL-prefix hosting** — the frontend builds with a `VITE_BASE_PATH` so
	it can be served under `/rag/`.
- **Additional local-LLM runners** — compose files for `Gemma4 31B`
	(Ollama) and `Qwen3-Next-80B Q8_0` (llama.cpp) under `docker/local_llm/`,
	with environment templates and warm-up scripts.
- **Paper-profile retrieval path in `utils/orchestrator/`** — profile-first
	retrieval for global/comparative queries, a `query_router.classify_query()`
	that picks between local and global flows, and `backfill_profiles.py` for
	upgrading pre-existing databases idempotently.
- **Quality evaluation suite** (`RAG_quality_test/`) — report-style runner
	and reference-free Ragas evaluator for the vector RAG, with `local` /
	`openai` / `gemini` judge providers, plus gold-question packs and a
	markdown→PDF utility.
- **TikZ architecture diagram** under `docs/tikz/` for the vector RAG
	pipeline, committed as both `.tex` source and rendered PDF.
- **Shared `hf_cache` volume** across all services so Hugging Face weights
	are downloaded once per host.

### Changed

- **Default embedder** is now `Alibaba-NLP/gte-Qwen2-7B-instruct` (3584-dim)
	in place of `BAAI/bge-large-en-v1.5`, with asymmetric query/passage
	prefixes applied server-side.
- **Vector store** migrated to Qdrant (persistent on-disk) throughout;
	ChromaDB paths remain only for legacy scripts.
- **Stage-1 ingestion** consolidated from `utils/data_preprocess/*` into
	`utils/s1_data_ingestion/` (`fortran_code_digest.py`, `pdf_extract.py`).
- **`LocalLLMClient`** now speaks Ollama's OpenAI-compatible API cleanly;
	JSON parsing is lenient with repair support, and model/env-var defaults
	match the Ollama stack out of the box.
- **Manuscript chunking and model configuration** refined — chunk sizes,
	overlaps, and vector-size defaults aligned with the 3584-dim embedder.
- **`README.md` rewritten** to reflect completed Phase 1/2/3 implementation
	and current module ownership:
	- phase 1 in `utils/s1_data_ingestion`
	- phase 2 in `utils/s2_embedding`
	- phase 3 in `utils/s3_RAG`
	- orchestration in `utils/orchestrator`
	- the unified Docker stack and shared embedding server in `docker/`
- **Operations documentation** added for running and maintaining services:
	local LLM service in `docker/local_llm`, RAG service in `docker/RAG`,
	environment variables, startup order, API endpoints, and maintenance
	runbook.

### Fixed

- Embedding/storage `vector_size` defaults now match the active embedder,
	so freshly-created Qdrant collections no longer silently reject the
	first upsert.

### Removed

- **GraphRAG retrieval stack** — the `graphRag/` package, its
	`docker/graphRag/` service, the `graph_backend` proxy route, and the
	GraphRAG/RAG service-switcher in the frontend were removed. Scalability
	limitations made this path no longer worth maintaining; vector RAG with
	the orchestrator's profile-first global-query path covers the use case.
- `utils/data_preprocess/` subtree with the standalone `Dolphin`,
	`pdf_crawler`, `vlm_formula_to_latex`, `s2orc-doc2json`, and
	`Paper2Code` trees — the parts still in use are now invoked from
	`utils/s1_data_ingestion/`, and MinerU is installed separately
	(expected at `utils/data_preprocess/MinerU/`).
- `updates.md` — historical dev notes superseded by this changelog and
	the per-package `readme.md`s.

## [1.0.1] - 2026-01-18

### Added

- paper2code implemented with gemini, ran with 5 available papers.

## [1.0.0] - 2026-01-12

### Added

- Initial release.
