# docker/graphRag

Self-contained Flask service that exposes the `graphRag` package over HTTP.
Designed to run alongside `docker/RAG` — but on its **own** database.

## Separate database

GraphRAG does **not** share storage with the vector RAG at `docker/RAG`.
It mounts:

- `../../graph_db` → `/app/db`  (GraphRAG's Qdrant + graph artefacts + registry)
- `../../graph_data` → `/app/data` (GraphRAG's ingest outputs, paper sources)

Both directories are created on first run. Papers uploaded via this
service populate only the GraphRAG DB; papers in `docker/RAG` are
unaffected and vice versa.

## Build & run

```bash
cd docker/graphRag
# .env is pre-populated (see the file). Edit LLM connection if needed.
docker compose up --build
```

The service binds `${GRAPHRAG_PORT:-3007}:5000`. The `utils/` and
`graphRag/` packages are mounted read-only.

## Environment

```
GRAPHRAG_PORT=3007
RAG_DEVICE=cuda:0
RAG_EMBEDDING_DEVICE=cuda:0
LOCAL_LLM_BASE_URL=http://host.docker.internal:11434/v1
LOCAL_LLM_API_KEY=ollama
LLM_MODEL_NAME=gemma4:31b
```

Put these in `.env` next to `docker-compose.yml`.

## Endpoints

| Method  | Path                      | Purpose                                                |
|---------|---------------------------|--------------------------------------------------------|
| GET     | `/api/status`             | Is the graph built? Build stats.                       |
| GET     | `/api/papers`             | GraphRAG paper registry                                |
| POST    | `/api/papers`             | Upload a (PDF, Fortran) pair into GraphRAG's DB        |
| DELETE  | `/api/papers/<title>`     | Remove a paper's chunks + profile from GraphRAG's DB   |
| POST    | `/api/build`              | (Re)build the graph from chunks already in GraphRAG    |
| POST    | `/api/query`              | Run a GraphRAG query                                   |
| GET     | `/api/graph`              | Full node/edge dump (inspection / viz)                 |
| GET     | `/api/communities`        | Community summaries                                    |

### Upload a paper

```bash
curl -X POST http://localhost:3007/api/papers \
     -F 'pdf=@./paper.pdf' \
     -F 'fortran=@./code.f90'
```

### Build

```bash
curl -X POST http://localhost:3007/api/build \
     -H 'content-type: application/json' \
     -d '{"skip_fortran": false}'
```

Rebuild after every new upload — the graph is not incremental.

### Query

```bash
curl -X POST http://localhost:3007/api/query \
     -H 'content-type: application/json' \
     -d '{"query":"which papers use overlapping-generations models?","mode":"auto"}'
```

Response (abridged):

```jsonc
{
  "answer": "...",
  "mode": "global",
  "communities": [
    {"community_id": 3, "title": "Life-cycle models", "score": 8, "contribution": "..."}
  ]
}
```

## Frontend

A React/Vite UI ships with this service (mirrors `docker/RAG`):

- **Manage Papers** — drag-and-drop PDF + Fortran upload, list, delete.
  Uploading or deleting only updates GraphRAG's own database — no
  effect on `docker/RAG`.
- **Graph** — Build/Rebuild button with options (skip-fortran, max-chunks,
  paper filter), plus a browsable list of detected communities
  (title, theme, summary, key entities, source papers).
- **Query** — Segmented mode selector (`auto` / `local` / `global`),
  answer rendered with KaTeX math, and an evidence drawer showing either
  retrieved chunks (local) or per-community contributions (global).

The production build (`docker compose up --build`) bakes the UI into
the container's `/app/frontend/dist/` and Flask serves it at `/`.

## Dev profile

```bash
docker compose --profile dev up
```

Brings up three services:

- `graphrag-web-dev` — Flask backend on port `${GRAPHRAG_PORT:-3007}`
  (runs `python app.py` for hot reload of the Python code).
- `graphrag-frontend-dev` — Vite dev server on port **5174** with HMR,
  proxying `/api/*` to the backend.

Point your browser at `http://localhost:5174`.
