# RAG Web Application

Flask backend + React frontend for the NTU-DAVID-RAG system. Serves a web UI and REST API for ingesting paper/code pairs, running Retrieval-Augmented Generation queries against a Qdrant vector store, and managing the paper registry.

## Layout

```
docker/RAG/
├── app.py              # Flask backend (API + static frontend serving)
├── Dockerfile          # Two-stage build: Vite frontend → Python backend
├── docker-compose.yml  # prod (rag-web) and dev (rag-web-dev + rag-frontend-dev) services
├── requirements.txt    # Backend Python deps (Flask, Qdrant, MinerU, sentence-transformers)
├── .env                # Runtime configuration (paths, ports, LLM endpoint, device)
├── .dockerignore
├── frontend/           # React + Vite + TypeScript UI
└── log.txt             # Container stdout/stderr (bind-mounted)
```

The container mounts the project's [utils/](../../utils/), [db/](../../db/), and [data/](../../data/) directories from the repo root, so the backend imports the live orchestrator code and writes to the shared vector store.

## Services

| Service             | Profile | Port           | Command                                   | Purpose                                           |
| ------------------- | ------- | -------------- | ----------------------------------------- | ------------------------------------------------- |
| `rag-web`           | default | `${RAG_PORT}`  | `gunicorn` (1 worker, 4 threads, 900s)   | Production server; serves built frontend + API.   |
| `rag-web-dev`       | `dev`   | `${RAG_PORT}`  | `python app.py` (Flask debug)            | Hot-reload backend for development.               |
| `rag-frontend-dev`  | `dev`   | `5173`         | `npm run dev`                             | Vite dev server, proxies `/api` to `rag-web-dev`. |

All backend services request GPU 1 via the NVIDIA runtime and expose `RAG_DEVICE` / `RAG_EMBEDDING_DEVICE` / `RAG_RERANKER_DEVICE` as `cuda:0` (remapped by `CUDA_VISIBLE_DEVICES=1`).

## Configuration (.env)

| Variable              | Default                                   | Purpose                                |
| --------------------- | ----------------------------------------- | -------------------------------------- |
| `PROJECT_ROOT`        | `/app`                                    | Container root; `sys.path` is set here.|
| `DB_PATH`             | `/app/db`                                 | Qdrant on-disk store + paper registry. |
| `DATA_PATH`           | `/app/data`                               | Uploads, ingest output, tmp staging.   |
| `PORT`                | `5000`                                    | Flask listen port inside the container.|
| `RAG_PORT`            | `3006`                                    | Host port mapped to `PORT`.            |
| `LOCAL_LLM_BASE_URL`  | `http://host.docker.internal:11434/v1`    | OpenAI-compatible LLM endpoint.        |
| `LOCAL_LLM_API_KEY`   | `ollama`                                  | API key for the local LLM.             |
| `LLM_MODEL_NAME`      | `gemma4:31b`                              | Model name served by the LLM backend.  |
| `RAG_*_DEVICE`        | `cuda:0`                                  | Torch device for engine/embed/rerank.  |

The LLM server is expected to run on the host (Ollama on `:11434`) or an adjacent Docker network; see [../local_llm/](../local_llm/).

## Running

> **Only one of `docker/RAG` or `docker/graphRag` can run at a time.** Both stacks pin `CUDA_VISIBLE_DEVICES=1` and reserve the same GPU, and they use separate databases ([db/](../../db/) vs. [graph_db/](../../graph_db/)). Bring one down before starting the other.

Build and start the production service:

```bash
cd docker/RAG
docker compose up -d --build rag-web
# UI + API at http://localhost:3006

# To switch to GraphRAG instead:
docker compose down
cd ../graphRag && docker compose up -d --build graphrag-web
# UI + API at http://localhost:3007
```

Development (hot-reload backend + Vite dev server):

```bash
docker compose --profile dev up --build
# Backend: http://localhost:3006
# Frontend dev: http://localhost:5173 (proxies /api to rag-web-dev)
```

Tail logs:

```bash
docker compose logs -f rag-web
# or view the persisted log
tail -f log.txt
```

## Querying with `curl`

Both services expose `POST /api/query` but with different request bodies. Only one is reachable at a time (see the note above).

**RAG** (port `3006`, default):

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG/docker/RAG
docker compose up -d --build rag-web
curl -X POST http://localhost:3006/api/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How is the labour supply elasticity estimated?",
    "top_k": 10,
    "history": []
  }'
```

**GraphRAG** (port `3007`, default; see [../graphRag/](../graphRag/)):

```bash
curl -X POST http://localhost:3007/api/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How is the labour supply elasticity estimated?",
    "mode": "auto",
    "n_hop": 1,
    "max_chunks": 20,
    "candidate_top_k": 12,
    "keep_top_k": 8
  }'
```

Health check (same path on either service):

```bash
curl http://localhost:3006/api/status   # RAG
curl http://localhost:3007/api/status   # GraphRAG
```

## API

| Method   | Path                            | Body / Params                                                      | Description                                            |
| -------- | ------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------ |
| `GET`    | `/api/status`                   | —                                                                  | Health check + paper count.                            |
| `GET`    | `/api/papers`                   | —                                                                  | Return the paper registry JSON.                        |
| `POST`   | `/api/papers`                   | multipart: `pdf`, `fortran`                                        | Ingest a PDF + Fortran pair, chunk, embed, store.      |
| `DELETE` | `/api/papers/<paper_title>`     | —                                                                  | Remove a paper's Qdrant points and registry entry.     |
| `POST`   | `/api/papers/retry_metadata`    | `{"paper_title": "..."}` or `{"paper_dir": "..."}`                | Re-run LLM title/author extraction; propagate updates. |
| `POST`   | `/api/query`                    | `{"query": "...", "top_k": 10, "history": [{role, content}, ...]}` | Run a RAG query; returns `answer` + `sources`.         |

The RAG engine ([utils/orchestrator/rag_query.py](../../utils/orchestrator/rag_query.py)) is lazily initialised on the first query and reloaded after any write operation under `_qdrant_access_lock`, which serialises Qdrant reader/writer access.

## Frontend

React 18 + TypeScript + Vite under [frontend/](./frontend/). Markdown answers render with `react-markdown` + `remark-math` + `rehype-katex` for LaTeX math. The production build (`vite build`) is emitted to `frontend/dist/` and served by Flask from `/`.

## Notes

- `privileged: true` is used so the container can access the NVIDIA GPU under the current host configuration.
- Image sources returned from `/api/query` are inlined as base64 `data:` URLs (truncated to the first 500 chars of text) to keep the frontend free of auxiliary file routes.
- `log.txt` is bind-mounted into the container and appended to via `tee`, so the host always has the latest stdout even across restarts.
