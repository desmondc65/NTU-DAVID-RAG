"""
Persistence layer for the GraphRAG artifacts.

On-disk layout (under ``<db_path>/graph_rag/``)::

    graph.pickle           # NetworkX DiGraph
    graph.json             # human-inspectable node/edge dump
    communities.json       # list of community summaries
    entity_embeddings.npy  # (N, D) float32 matrix
    entity_order.json      # list of node keys parallel to the matrix
    build_meta.json        # build timestamp, version, model, stats

Loading is lazy — callers use :class:`GraphStore` which memoises its
attributes.
"""
from __future__ import annotations

import json
import logging
import pickle
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import networkx as nx
import numpy as np

logger = logging.getLogger(__name__)


GRAPH_DIR_NAME = "graph_rag"


def graph_dir(db_path: Path) -> Path:
    return Path(db_path) / GRAPH_DIR_NAME


@dataclass
class GraphStore:
    db_path: Path
    _graph: Optional[nx.DiGraph] = None
    _communities: Optional[List[Dict[str, Any]]] = None
    _entity_embeddings: Optional[np.ndarray] = None
    _entity_order: Optional[List[str]] = None

    # ── Directory / existence ───────────────────────────────────────────
    @property
    def dir(self) -> Path:
        return graph_dir(self.db_path)

    @property
    def exists(self) -> bool:
        return (self.dir / "graph.pickle").exists()

    # ── Save ────────────────────────────────────────────────────────────
    def save(
        self,
        graph: nx.DiGraph,
        communities: List[Dict[str, Any]],
        entity_embeddings: Optional[np.ndarray] = None,
        entity_order: Optional[List[str]] = None,
        build_meta: Optional[Dict[str, Any]] = None,
    ) -> None:
        self.dir.mkdir(parents=True, exist_ok=True)

        with open(self.dir / "graph.pickle", "wb") as f:
            pickle.dump(graph, f)

        # Human-readable dump
        dump = {
            "nodes": [
                {"key": k, **{ak: av for ak, av in g_attrs.items()}}
                for k, g_attrs in graph.nodes(data=True)
            ],
            "edges": [
                {"source": u, "target": v, **{ak: av for ak, av in attrs.items()}}
                for u, v, attrs in graph.edges(data=True)
            ],
        }
        with open(self.dir / "graph.json", "w", encoding="utf-8") as f:
            json.dump(dump, f, indent=2, ensure_ascii=False)

        with open(self.dir / "communities.json", "w", encoding="utf-8") as f:
            json.dump(communities, f, indent=2, ensure_ascii=False)

        if entity_embeddings is not None and entity_order is not None:
            np.save(self.dir / "entity_embeddings.npy", entity_embeddings.astype(np.float32))
            with open(self.dir / "entity_order.json", "w", encoding="utf-8") as f:
                json.dump(entity_order, f, ensure_ascii=False)

        meta = {
            "built_at": datetime.now(timezone.utc).isoformat(),
            "n_nodes": graph.number_of_nodes(),
            "n_edges": graph.number_of_edges(),
            "n_communities": len(communities),
            **(build_meta or {}),
        }
        with open(self.dir / "build_meta.json", "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2, ensure_ascii=False)

        logger.info("Graph artifacts saved to %s", self.dir)

    # ── Load ────────────────────────────────────────────────────────────
    def graph(self) -> nx.DiGraph:
        if self._graph is None:
            path = self.dir / "graph.pickle"
            if not path.exists():
                raise FileNotFoundError(f"No graph at {path}; build it first.")
            with open(path, "rb") as f:
                self._graph = pickle.load(f)
        return self._graph

    def communities(self) -> List[Dict[str, Any]]:
        if self._communities is None:
            path = self.dir / "communities.json"
            if not path.exists():
                self._communities = []
            else:
                with open(path, "r", encoding="utf-8") as f:
                    self._communities = json.load(f)
        return self._communities

    def entity_embeddings(self) -> Tuple[Optional[np.ndarray], Optional[List[str]]]:
        if self._entity_embeddings is None:
            emb_path = self.dir / "entity_embeddings.npy"
            order_path = self.dir / "entity_order.json"
            if emb_path.exists() and order_path.exists():
                self._entity_embeddings = np.load(emb_path)
                with open(order_path, "r", encoding="utf-8") as f:
                    self._entity_order = json.load(f)
        return self._entity_embeddings, self._entity_order

    def build_meta(self) -> Dict[str, Any]:
        path = self.dir / "build_meta.json"
        if not path.exists():
            return {}
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
