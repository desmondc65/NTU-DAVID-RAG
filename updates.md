# NTU DAVID RAG - Presentation Source (Repo Overview)

## Slide 1 - Project Title
**NTU DAVID RAG**  
Economics-focused Retrieval-Augmented Generation (RAG) platform for paper+code understanding.

Core idea: ingest economics PDFs and companion Fortran code, store structured knowledge in a vector database, and answer user questions with grounded citations.

---

## Slide 2 - Problem Statement
Economics research materials are hard to query end-to-end because information is split across:
- Long academic manuscripts (text, equations, tables, figures)
- Legacy Fortran implementations
- Heterogeneous file formats and metadata quality

This project solves that by creating a unified retrieval and generation pipeline that can answer questions grounded in both paper narrative and implementation logic.

---

## Slide 3 - Project Goals
- Build a complete 3-phase RAG pipeline (ingest -> embed/store -> retrieve/generate)
- Preserve multimodal paper content (text, image/equation/table descriptions)
- Integrate Fortran code understanding into retrieval
- Provide both script-level orchestration and web application usage
- Support local deployment with GPU acceleration

---

## Slide 4 - High-Level Architecture
**Data flow:**
1. Upload PDF + Fortran source
2. Extract and enrich paper structure with MinerU + local LLM
3. Chunk and embed content
4. Store vectors + metadata in local Qdrant
5. Run hybrid retrieval (dense + BM25)
6. Fuse + rerank candidates
7. Generate grounded answer via local OpenAI-compatible LLM endpoint

**Runtime services:**
- Local LLM service (llama.cpp server in Docker)
- RAG web service (Flask + Gunicorn, Dockerized)
- Frontend UI (React + Vite)

---

## Slide 5 - Tech Stack
### Core Languages
- Python (pipeline, backend, orchestration)
- TypeScript/React (frontend)
- Fortran (ingested target codebase)

### Backend and APIs
- Flask, Flask-CORS, Gunicorn
- Pydantic (data handling)
- python-dotenv (config)

### Ingestion and Parsing
- MinerU (`mineru[all]`) for PDF structure extraction
- `pdf2image` for visual-related processing support

### Embedding and Retrieval
- `sentence-transformers`
	- Embedding model: `BAAI/bge-large-en-v1.5`
	- Reranker model: `BAAI/bge-reranker-v2-m3`
- `rank-bm25` for sparse lexical retrieval
- `qdrant-client` with local persistent storage

### Frontend
- React 18 + Vite + TypeScript
- `react-markdown`, `remark-math`, `rehype-katex`, `katex`

### Infrastructure
- Docker Compose for both LLM and RAG services
- NVIDIA GPU runtime configuration for acceleration

---

## Slide 6 - Repository Structure (What Each Folder Does)
- `utils/s1_data_ingestion`: PDF extraction, multimodal description generation, Fortran digestion
- `utils/s2_embedding`: chunking, embedding, Qdrant storage wrappers
- `utils/s3_RAG`: BM25 retriever, dense retriever, fusion/reranking, RAG orchestration helpers
- `utils/orchestrator`: end-to-end stage connectors
	- `ingest_paper.py`
	- `store_to_db.py`
	- `rag_query.py`
- `docker/local_llm`: local OpenAI-compatible LLM serving stack (llama.cpp)
- `docker/RAG`: Flask API + frontend + compose setup
- `db/`: persistent Qdrant data + `paper_registry.json`
- `data/`: upload and ingestion outputs
- `tests/`: stage-level and orchestrator-level test scripts
- `docs/`: workflow diagrams and phase docs

---

## Slide 7 - Phase 1 Workflow (Ingestion)
Primary orchestrator: `utils/orchestrator/ingest_paper.py`

Pipeline detail:
1. Copy input PDF and Fortran into temporary ingest workspace
2. Parse PDF with MinerU into markdown + content list JSON
3. Extract paper metadata (title/authors) from first ~600 words via local LLM
4. Generate retrieval-oriented descriptions for:
	 - Images
	 - Equations
	 - Tables
5. Digest Fortran code and generate function-level summaries
6. Inject paper metadata into generated JSON artifacts
7. Move outputs into title-based canonical directory (collision-safe naming)

Output artifacts include:
- Manuscript markdown
- Content list JSON with enriched multimodal descriptors
- Metadata JSON
- Fortran digest JSON

---

## Slide 8 - Phase 2 Workflow (Chunk, Embed, Store)
Primary orchestrator: `utils/orchestrator/store_to_db.py`

Pipeline detail:
1. Chunk manuscript content list
	 - Merge text with token window and overlap
	 - Keep non-text items as individual retrieval units
2. Process Fortran digest
	 - One retrieval document per key function summary
3. Generate embeddings using BGE model
4. Upsert vectors + metadata into Qdrant local collection (`rag_embeddings`)
5. Update paper registry (`db/paper_registry.json`)

Metadata strategy includes content type, source path, sequence ordering, and paper identifiers to support filtering and context assembly.

---

## Slide 9 - Phase 3 Workflow (Hybrid RAG Query)
Primary orchestrator: `utils/orchestrator/rag_query.py`

Query pipeline:
1. Dense retrieval from Qdrant using query embedding
2. Sparse retrieval via BM25 over indexed corpus
3. Reciprocal Rank Fusion (RRF) to merge both ranked lists
4. Cross-encoder reranking (`bge-reranker-v2-m3`) for final relevance ordering
5. Context assembly with metadata-aware formatting
6. Answer generation via local LLM client

Important design points:
- Device fallback logic prevents hard crash when CUDA is unavailable
- Context builder preserves paper order using `sequence_idx`
- Non-text content carries rich fields (LaTeX, table body, image paths)

---

## Slide 10 - Web Application and API Layer
Backend entrypoint: `docker/RAG/app.py`

Main REST endpoints:
- `GET /api/status`: service health + paper count
- `GET /api/papers`: list ingested papers
- `POST /api/papers`: upload PDF + Fortran and run ingest/store pipeline
- `DELETE /api/papers/<paper_title>`: remove paper vectors + registry entry
- `POST /api/query`: run full RAG query

Operational behavior:
- Lazy initialization of heavy RAG engine
- Access lock to protect read/write coordination with Qdrant
- Image source payload can be returned as base64 data URL for UI rendering

---

## Slide 11 - Deployment and Runtime Topology
### Local LLM stack (`docker/local_llm`)
- Runs `llama.cpp` CUDA server image
- Exposes OpenAI-compatible endpoint (`/v1`)
- Uses configurable model alias/API key
- Includes startup checks for GPU visibility and model file existence

### RAG stack (`docker/RAG`)
- `rag-web` production container (Gunicorn)
- `rag-web-dev` + `rag-frontend-dev` profile for development
- Mounts `utils`, `db`, and `data` from host for persistence/integration
- GPU environment variables for embedding/reranking acceleration

---

## Slide 12 - Data and Persistence Model
- Vector storage: `db/qdrant_data`
- Registry: `db/paper_registry.json`
- Upload staging: `data/tmp_uploads`
- Canonical ingest outputs: `data/ingest_output` and title-based directories

Why this matters:
- Enables paper lifecycle operations (add/list/delete)
- Keeps retrieval index and UI paper list synchronized
- Supports reproducible local development and demos

---

## Slide 13 - Testing Strategy
Representative tests:
- Orchestrator flow tests:
	- `tests/test_orch_ingest_paper_n_code.py`
	- `tests/test_orch_store_to_db.py`
	- `tests/test_orch_rag_query.py`
- Stage tests:
	- `tests/test_s1_pdf_extract.py`
	- `tests/test_s2_embedding.py`
	- `tests/test_s3_rag.py`

Current style is script-oriented integration checks rather than strict unit-test isolation.

---

## Slide 14 - Strengths of Current Design
- End-to-end working pipeline across all 3 phases
- Practical handling of multimodal academic content
- Hybrid retrieval architecture improves recall and relevance
- Local-first deployment preserves data control
- Clear orchestration entrypoints simplify maintenance

---

## Slide 15 - Known Gaps / Risks (Good to Mention in Presentation)
- Some docs still describe older Chroma-based flow while runtime code now uses Qdrant
- Heavy models require strong GPU resources; CPU fallback exists but is slower
- Test suite is mostly script/integration style, leaving room for deeper automated regression coverage
- Operational complexity around multi-container GPU runtime and environment consistency

---

## Slide 16 - Suggested Roadmap
Short-term:
- Align all docs/diagrams with current Qdrant implementation
- Add structured benchmark metrics (latency, retrieval quality, answer grounding)
- Expand automated tests for failure modes and edge-case ingestion

Mid-term:
- Introduce configurable retrieval strategies per paper/domain
- Add richer source attribution UX and confidence diagnostics
- Improve ingestion robustness for noisy PDF layouts

Long-term:
- Multi-user/project tenancy
- Model routing (cost/performance-aware)
- Continuous evaluation pipeline for retrieval and generation quality

---

## Slide 17 - One-Slide Demo Script (Optional)
1. Start local LLM and RAG services
2. Open web UI
3. Upload one economics paper PDF + companion Fortran file
4. Wait for ingestion/indexing completion
5. Ask a methodological question about model assumptions or equations
6. Show grounded answer and retrieved sources
7. Delete paper to demonstrate lifecycle management

---

## Slide 18 - Closing Summary
NTU DAVID RAG is a complete, local-first, economics-oriented RAG platform that:
- Bridges academic manuscripts and legacy Fortran code
- Uses modern hybrid retrieval and reranking
- Ships with practical Dockerized deployment and web interface

It is already strong for research demos and can be productionized further through documentation alignment, deeper testing, and evaluation automation.
