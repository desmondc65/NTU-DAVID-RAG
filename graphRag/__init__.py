"""
GraphRAG: a knowledge-graph retrieval layer for the economics corpus.

Builds a graph of entities (models, methods, concepts, datasets, authors,
variables) and relationships extracted from paper chunks, detects
communities, summarises them, and exposes two query paths:

- **Local search** — entity-anchored: the query is mapped to a set of
  seed entities in the graph; the engine walks a small neighbourhood and
  pulls their source chunks to ground the answer.

- **Global search** — community map-reduce: each community summary is
  inspected by the LLM ("what does this community contribute to the
  answer?"), partial contributions are then merged. Designed for
  comparative / aggregate queries such as "which papers share similar
  mathematical models?".

The package reuses ``utils.llm_clients.local_llm``, the embedding model
in ``utils.s2_embedding.embedder`` and the existing Qdrant chunk store
so it can operate on the database built by ``utils.orchestrator.store_to_db``.

The top-level :class:`GraphRAGEngine` is imported lazily so modules that
only need graph utilities (e.g. :mod:`graphRag.graph_builder`) do not
pull in torch / sentence-transformers at import time.
"""
from __future__ import annotations

__all__ = ["GraphRAGEngine"]


def __getattr__(name):  # PEP 562
    if name == "GraphRAGEngine":
        from .graph_rag import GraphRAGEngine
        return GraphRAGEngine
    raise AttributeError(f"module 'graphRag' has no attribute {name!r}")
