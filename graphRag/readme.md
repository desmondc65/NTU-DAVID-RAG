# graphRag

A knowledge-graph retrieval layer for the economics corpus. Designed for
comparative / global queries ("which papers use similar mathematical models?",
"what methods are shared across these papers?") that chunk-level vector RAG
cannot reliably answer.

## Overview

**GraphRAG owns its own database.** Artefacts are written to `graph_db/`
at the repository root (sibling to the vector RAG's `db/`), with a parallel
data directory `graph_data/` for ingest outputs. The two systems can be
populated, rebuilt, and deleted independently.

Papers must be ingested into the GraphRAG DB first (either via
`python -m graphRag.ingest …` or `POST /api/papers`) before the graph
can be built. Ingestion reuses `utils/orchestrator/ingest_paper.py` and
`utils/orchestrator/store_to_db.py` — the only thing that changes is the
target `db_path`.

### Pipeline

1. **Extract** — `entity_extractor.py` runs the LLM over each chunk and
   produces typed entities (model / concept / method / dataset / variable
   / theorem / author / paper) plus relationships
   (uses / extends / compares / applies_to / causes / contains / measures
   / authored / mentions).
2. **Build graph** — `graph_builder.py` merges extractions into a
   `networkx.DiGraph`. Node attributes carry the source `chunk_ids` and
   `paper_titles` so every graph element is traceable back to evidence.
3. **Detect communities** — Leiden via `graspologic` when installed,
   otherwise NetworkX's greedy modularity.
4. **Summarise** — `community_summarizer.py` generates `{title, theme,
   summary, key_entities, paper_titles}` per community.
5. **Embed entities** — entity name + description is embedded once so
   local search can resolve query-mentioned entities into graph nodes
   via cosine similarity.
6. **Persist** — `graph_store.py` writes everything to
   `<db_path>/graph_rag/` as pickle + JSON + NumPy.

### Query paths

- **Local search** (`local_search.py`) — entity-anchored. The LLM
  extracts seed entities from the query, each is resolved to its closest
  graph node, an *n*-hop subgraph is grown, and the attached chunks are
  pulled from Qdrant to ground the final answer.
- **Global search** (`global_search.py`) — community map-reduce. For
  each relevant community summary, the LLM is asked "what does this
  contribute to the question?"; partial contributions are merged into
  the final answer.
- `GraphRAGEngine.query(..., mode="auto")` picks local vs global via a
  regex heuristic over query phrasing.

## Usage

```python
from graphRag import GraphRAGEngine

engine = GraphRAGEngine(db_path="graph_db/")
engine.build(skip_fortran=False)   # one-off after papers are ingested
result = engine.query("which papers use overlapping-generations models?")
print(result["answer"])
```

### Ingest papers (CLI)

```bash
python -m graphRag.ingest \
    --pdf path/to/paper.pdf \
    --fortran path/to/code.f90 \
    # --db-path graph_db/     (default)
    # --data-dir graph_data/  (default)
```

### Build the graph (CLI)

```bash
python -m graphRag.build_graph --db-path graph_db/
```

Optional flags:

- `--paper "TITLE"` (repeatable) — restrict extraction to named papers
- `--skip-fortran` — drop `fortran_*` content types
- `--max-chunks N` — debug cap

## Artefacts

Everything lives under `graph_db/`:

```
graph_db/
├── paper_registry.json       # GraphRAG's own paper list
├── qdrant_data/              # its own Qdrant collections
│   ├── rag_embeddings        # chunk embeddings
│   └── paper_profiles        # per-paper structured profiles
└── graph_rag/
    ├── graph.pickle
    ├── graph.json            # human-inspectable
    ├── communities.json      # per-community summaries
    ├── entity_embeddings.npy # (N, D) float32
    ├── entity_order.json     # node keys parallel to the matrix
    └── build_meta.json
```

## Requirements

`networkx>=3.0` is added to `requirements.txt`. Leiden via
`graspologic` is optional; the greedy-modularity fallback requires
nothing beyond NetworkX.

## Deployment

A self-contained Flask service lives under `docker/graphRag/`,
mirroring the structure of `docker/RAG/` but bound to the separate
`graph_db/` and `graph_data/` volumes. It exposes:

- `GET  /api/status`  — whether the graph is built, with build stats
- `POST /api/papers`  — upload a (PDF, Fortran) pair into GraphRAG's DB
- `DELETE /api/papers/<title>` — remove a paper from GraphRAG's DB
- `GET  /api/papers`  — GraphRAG paper registry
- `POST /api/build`   — (re)build the graph (body: `{paper_filter,
  skip_fortran, max_chunks}`)
- `POST /api/query`   — answer a question (body: `{query, mode, ...}`
  where `mode` ∈ `auto, local, global`)
- `GET  /api/graph`, `GET /api/communities` — inspection endpoints
