# NTU DAVID RAG

Economics-focused Retrieval-Augmented Generation (RAG) system for:
- Academic paper PDFs
- Companion Fortran code
- Hybrid retrieval and grounded answer generation

Project status: all three phases are implemented and integrated.

![System Design](docs/initial_system_desgin.png)

## What Is Implemented

### Phase 1: Data Ingestion
Location: `utils/s1_data_ingestion`

Implemented capabilities:
- PDF extraction via MinerU
- Image/equation/table description enrichment
- Fortran code digestion and summary generation
- Paper metadata extraction (title/authors) through local LLM

Orchestration entrypoint:
- `utils/orchestrator/ingest_paper.py`

### Phase 2: Embedding and Storage
Location: `utils/s2_embedding`

Implemented capabilities:
- Chunking of manuscript and Fortran digest outputs
- Embedding generation (sentence-transformers)
- Vector persistence in Qdrant local store
- Paper registry maintenance (`db/paper_registry.json`)

Orchestration entrypoint:
- `utils/orchestrator/store_to_db.py`

### Phase 3: Retrieval and Generation
Location: `utils/s3_RAG`

Implemented capabilities:
- Dense retrieval (Qdrant)
- Sparse retrieval (BM25)
- Reciprocal Rank Fusion (RRF)
- Cross-encoder reranking
- Context assembly and answer generation through local LLM

Orchestration entrypoint:
- `utils/orchestrator/rag_query.py`

## Runtime Components

- Orchestration logic: `utils/orchestrator`
- Local LLM server stack: `docker/local_llm`
- End-to-end RAG web service (Flask + frontend): `docker/RAG`

## Repository Map

- `utils/s1_data_ingestion`: phase 1 ingestion modules
- `utils/s2_embedding`: phase 2 embedding/vector-store modules
- `utils/s3_RAG`: phase 3 retrieval/reranker modules
- `utils/orchestrator`: pipeline orchestration between phases
- `docker/local_llm`: Docker Compose for llama.cpp OpenAI-compatible LLM endpoint
- `docker/RAG`: Dockerized RAG backend and frontend
- `db`: persistent vector store data and paper registry
- `data`: uploads and ingestion outputs
- `tests`: script-style tests for each stage and orchestrators
- `docs`: workflow diagrams and phase docs

## Prerequisites

- Linux host with Docker and Docker Compose
- NVIDIA GPU + NVIDIA Container Toolkit (for GPU containers)
- Python 3.10+ for local script execution

## Environment Configuration

### 1. Local LLM config
File: `docker/local_llm/.env`

Minimum required fields:
- `MODEL_DIR`: absolute directory containing GGUF model files
- `MODEL_FILE`: GGUF model filename under `MODEL_DIR`
- `MODEL_ALIAS`: model name expected by clients (for example `qwen2.5-vl-72b-instruct`)
- `SERVICE_PORT`: LLM API port on host (default `8000`)
- `LOCAL_LLM_API_KEY`: API key used by clients

Optional performance fields:
- `TENSOR_SPLIT`, `CTX_SIZE`, `BATCH_SIZE`, `UBATCH_SIZE`, `THREADS`, `PARALLEL`, `MM_PROJ_FILE`

### 2. RAG app config
File: `docker/RAG/.env`

Key fields:
- `DB_PATH=/app/db`
- `DATA_PATH=/app/data`
- `PORT=5000`
- `RAG_PORT=3006`
- `LOCAL_LLM_BASE_URL=http://host.docker.internal:8000/v1`
- `LOCAL_LLM_API_KEY` (must match local LLM)
- `LLM_MODEL_NAME` (must match `MODEL_ALIAS`)
- `RAG_DEVICE`, `RAG_EMBEDDING_DEVICE`, `RAG_RERANKER_DEVICE`

## Run Services

### Start local LLM service
```bash
cd docker/local_llm
docker compose -f docker-compose.qwen3-next-80b.yml up -d
```

Health check:
```bash
curl http://localhost:8000/health
```

View logs:
```bash
docker compose -f docker-compose.qwen3-next-80b.yml logs -f
```

### Start RAG web service (production profile)
```bash
cd docker/RAG
docker compose up -d rag-web
```

Access:
- App/API host port: `http://localhost:3006`
- API health: `http://localhost:3006/api/status`

View logs:
```bash
docker compose logs -f rag-web
```

### Start RAG dev profile (hot reload backend + Vite frontend)
```bash
cd docker/RAG
docker compose --profile dev up -d rag-web-dev rag-frontend-dev
```

Access:
- Frontend dev server: `http://localhost:5173`
- Backend dev API: `http://localhost:3006/api/status`

## API Endpoints (RAG service)

Base URL: `http://localhost:3006`

- `GET /api/status`: health and paper count
- `GET /api/papers`: list ingested papers
- `POST /api/papers`: upload pair (`pdf` + `fortran` multipart fields), ingest, embed, and store
- `DELETE /api/papers/<paper_title>`: delete vectors and registry entry for one paper
- `POST /api/query`: run RAG query

Example query request:
```bash
curl -X POST http://localhost:3006/api/query \
	-H "Content-Type: application/json" \
	-d '{"query":"What drives wealth concentration in the U.S.?","top_k":5}'
```

## Run Pipeline Locally (Without Web API)

If you want direct orchestration in Python:

1. Run ingestion via `utils/orchestrator/ingest_paper.py`
2. Pass its output dict into `utils/orchestrator/store_to_db.py`
3. Query with `utils/orchestrator/rag_query.py`

Example scripts are in module `if __name__ == "__main__"` sections and in `tests/`.

## Testing

Representative stage/orchestrator tests:
- `tests/test_orch_ingest_paper_n_code.py`
- `tests/test_orch_store_to_db.py`
- `tests/test_orch_rag_query.py`
- `tests/test_s1_pdf_extract.py`
- `tests/test_s2_embedding.py`
- `tests/test_s3_rag.py`

Run a test script:
```bash
python3 tests/test_orch_rag_query.py
```

## Maintenance Runbook

### Stop services
```bash
cd docker/local_llm && docker compose -f docker-compose.qwen3-next-80b.yml down
cd docker/RAG && docker compose down
```

### Rebuild RAG image after dependency/code changes
```bash
cd docker/RAG
docker compose build --no-cache rag-web
docker compose up -d rag-web
```

### Clear vector DB (full reset)
This removes all indexed vectors:
```bash
rm -rf db/qdrant_data
rm -f db/paper_registry.json
```

### Common integration checks
- Local LLM reachable from host: `curl http://localhost:8000/health`
- RAG API reachable: `curl http://localhost:3006/api/status`
- `LLM_MODEL_NAME` in `docker/RAG/.env` equals `MODEL_ALIAS` in `docker/local_llm/.env`
- `LOCAL_LLM_API_KEY` matches in both env files

## Workflow Docs

- `docs/phase2_embedding_workflow.md`
- `docs/phase3_rag_workflow.md`
- `docs/rag_pipeline_flow.mermaid`
