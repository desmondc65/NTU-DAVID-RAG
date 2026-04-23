"""
Top-level GraphRAG engine.

Responsibilities:
- Build the knowledge graph (scroll chunks from Qdrant → extract →
  build graph → detect communities → summarise → embed entity names →
  persist).
- Answer queries by dispatching to local or global search based on a
  lightweight router.

The engine shares its Qdrant client across the chunk collection and any
other collection it reads (Qdrant's local path acquires a filesystem
lock, so sibling collections must share one client).
"""
from __future__ import annotations

import logging
import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import networkx as nx
import numpy as np

from utils.llm_clients.local_llm import LocalLLMClient
from utils.s2_embedding.embedder import EmbeddingModel, _DEFAULT_MODEL
from utils.s2_embedding.qdrant_store import QdrantVectorStore

from .entity_extractor import EntityExtractor, ChunkExtraction
from .graph_builder import (
    build_graph,
    detect_communities,
    community_members,
    collect_community_evidence,
)
from .community_summarizer import CommunitySummarizer
from .global_search import GlobalSearch
from .graph_store import GraphStore
from .local_search import LocalSearch

logger = logging.getLogger(__name__)


_GLOBAL_PATTERNS = re.compile(
    r"(which papers|across papers|compare|comparison|differ|similar|"
    r"in common|overlap|what papers|share the same|shared)",
    re.IGNORECASE,
)


def _looks_global(query: str) -> bool:
    return bool(_GLOBAL_PATTERNS.search(query))


def _scroll_all_chunks(store: QdrantVectorStore) -> List[Dict[str, Any]]:
    records: List[Dict[str, Any]] = []
    offset = None
    while True:
        points, next_offset = store.client.scroll(
            collection_name=store.collection_name,
            limit=256,
            offset=offset,
            with_payload=True,
            with_vectors=False,
        )
        for pt in points:
            payload = dict(pt.payload) if pt.payload else {}
            text = payload.pop("document", "")
            records.append({
                "id": pt.id,
                "text": text,
                "metadata": payload,
            })
        if next_offset is None:
            break
        offset = next_offset
    return records


def _entity_embedding_text(node_key: str, attrs: Dict[str, Any]) -> str:
    name = attrs.get("name", node_key)
    typ = attrs.get("type", "")
    descs = attrs.get("descriptions") or []
    desc = descs[0] if descs else ""
    return f"{typ}: {name}. {desc}".strip()


class GraphRAGEngine:
    """
    Reads (and optionally writes) GraphRAG artefacts under
    ``<db_path>/graph_rag/``. Initialise with ``db_path`` pointing at
    the same directory used by the vector-RAG pipeline.
    """

    def __init__(
        self,
        db_path: Union[str, Path],
        chunk_collection: str = "rag_embeddings",
        embedding_model: str = _DEFAULT_MODEL,
        llm_client: Optional[LocalLLMClient] = None,
        device: Optional[str] = None,
    ) -> None:
        self.db_path = Path(db_path)
        self.qdrant_dir = str(self.db_path / "qdrant_data")
        self.chunk_collection = chunk_collection
        self.device = (
            device
            or os.getenv("RAG_EMBEDDING_DEVICE")
            or os.getenv("RAG_DEVICE", "cuda:0")
        )

        resolved_embedding_model = embedding_model
        if resolved_embedding_model == _DEFAULT_MODEL:
            resolved_embedding_model = os.getenv("RAG_EMBEDDING_MODEL", resolved_embedding_model)

        logger.info(
            "Loading embedder for GraphRAG (model=%s, device=%s)…",
            resolved_embedding_model,
            self.device,
        )
        self.embedder = EmbeddingModel(model_name=resolved_embedding_model, device=self.device)
        self.llm = llm_client or LocalLLMClient()

        self.chunk_store = QdrantVectorStore(
            persist_dir=self.qdrant_dir,
            collection_name=chunk_collection,
        )
        self.store = GraphStore(db_path=self.db_path)

        # Lazy search handles
        self._local_search: Optional[LocalSearch] = None
        self._global_search: Optional[GlobalSearch] = None

    # ── Build ────────────────────────────────────────────────────────────

    def build(
        self,
        paper_filter: Optional[List[str]] = None,
        skip_fortran: bool = False,
        max_chunks: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Build (or rebuild) the graph + communities + summaries.

        Parameters
        ----------
        paper_filter : list of str, optional
            Only process chunks whose ``paper_title`` matches one of these.
        skip_fortran : bool
            If True, exclude Fortran code chunks from extraction.
        max_chunks : int, optional
            Hard cap on the number of chunks processed (debug convenience).
        """
        logger.info("Scrolling chunks from '%s'…", self.chunk_collection)
        chunks = _scroll_all_chunks(self.chunk_store)
        logger.info("Fetched %d chunks.", len(chunks))

        def _keep(c: Dict[str, Any]) -> bool:
            meta = c.get("metadata", {}) or {}
            if paper_filter and meta.get("paper_title") not in set(paper_filter):
                return False
            if skip_fortran and str(meta.get("content_type", "")).startswith("fortran"):
                return False
            if not (c.get("text") or "").strip():
                return False
            return True

        filtered = [c for c in chunks if _keep(c)]
        if max_chunks is not None:
            filtered = filtered[:max_chunks]
        logger.info("%d chunks after filtering.", len(filtered))

        if not filtered:
            raise RuntimeError("No chunks to process — is the vector store populated?")

        # ── 1. Extract entities and relationships ──────────────────────
        extractor = EntityExtractor(llm_client=self.llm)
        extractions: List[ChunkExtraction] = []
        for i, c in enumerate(filtered, 1):
            if i % 10 == 0 or i == len(filtered):
                logger.info("Extracting %d / %d…", i, len(filtered))
            extractions.append(extractor.extract_chunk(
                chunk_id=str(c["id"]),
                text=c["text"],
                paper_title=(c.get("metadata") or {}).get("paper_title", ""),
                section=(c.get("metadata") or {}).get("section", ""),
            ))

        n_entities = sum(len(e.entities) for e in extractions)
        n_rels = sum(len(e.relationships) for e in extractions)
        logger.info("Extraction complete — %d entities, %d relationships raw.", n_entities, n_rels)

        # ── 2. Build graph ─────────────────────────────────────────────
        g = build_graph(extractions)

        # ── 3. Detect communities ──────────────────────────────────────
        detect_communities(g)
        members = community_members(g)
        logger.info("Communities: %d (largest=%d)", len(members),
                    max((len(v) for v in members.values()), default=0))

        # ── 4. Summarise communities ───────────────────────────────────
        evidence_by_cid = {
            cid: collect_community_evidence(g, keys)
            for cid, keys in members.items()
        }
        summarizer = CommunitySummarizer(llm_client=self.llm)
        summaries = summarizer.summarize_all(evidence_by_cid)

        # ── 5. Embed entity names+descriptions for seed resolution ─────
        logger.info("Embedding entity descriptions for seed matching…")
        node_keys = list(g.nodes)
        texts = [_entity_embedding_text(k, g.nodes[k]) for k in node_keys]
        entity_embeddings = np.asarray(self.embedder.embed_documents(texts), dtype=np.float32)

        # ── 6. Persist ─────────────────────────────────────────────────
        self.store.save(
            graph=g,
            communities=summaries,
            entity_embeddings=entity_embeddings,
            entity_order=node_keys,
            build_meta={
                "n_chunks": len(filtered),
                "n_entities_raw": n_entities,
                "n_relationships_raw": n_rels,
                "paper_filter": paper_filter or [],
                "skip_fortran": skip_fortran,
            },
        )

        # Force reload of lazy search handles next time
        self._local_search = None
        self._global_search = None
        self.store._graph = g
        self.store._communities = summaries
        self.store._entity_embeddings = entity_embeddings
        self.store._entity_order = node_keys

        return {
            "n_chunks": len(filtered),
            "n_nodes": g.number_of_nodes(),
            "n_edges": g.number_of_edges(),
            "n_communities": len(summaries),
        }

    # ── Query ───────────────────────────────────────────────────────────

    def _ensure_loaded(self) -> None:
        if not self.store.exists:
            raise FileNotFoundError(
                f"No graph found under {self.store.dir} — run build() first."
            )

    def _ensure_local(self) -> LocalSearch:
        self._ensure_loaded()
        if self._local_search is None:
            graph = self.store.graph()
            emb, order = self.store.entity_embeddings()
            self._local_search = LocalSearch(
                graph=graph,
                chunk_store=self.chunk_store,
                embedder=self.embedder,
                llm=self.llm,
                entity_embeddings=emb,
                entity_order=order,
            )
        return self._local_search

    def _ensure_global(self) -> GlobalSearch:
        self._ensure_loaded()
        if self._global_search is None:
            self._global_search = GlobalSearch(
                community_summaries=self.store.communities(),
                embedder=self.embedder,
                llm=self.llm,
            )
        return self._global_search

    def query(
        self,
        user_query: str,
        mode: str = "auto",
        conversation_history: Optional[List[Dict[str, str]]] = None,
        **kwargs: Any,
    ) -> Dict[str, Any]:
        """
        Run a GraphRAG query.

        Parameters
        ----------
        user_query : str
        mode : one of "auto", "local", "global"
            ``auto`` uses a regex heuristic over the query text.
        conversation_history : optional list of ``{"role", "content"}`` turns
            from the same chat session. Used to resolve follow-up references
            and condition the answer.
        kwargs : forwarded to the chosen search backend (``n_hop``,
            ``max_chunks``, ``candidate_top_k`` etc.).
        """
        chosen = mode
        if mode == "auto":
            chosen = "global" if _looks_global(user_query) else "local"
        logger.info("GraphRAG query mode: %s", chosen)

        if chosen == "global":
            result = self._ensure_global().search(
                user_query,
                conversation_history=conversation_history,
                **kwargs,
            )
        else:
            result = self._ensure_local().search(
                user_query,
                conversation_history=conversation_history,
                **kwargs,
            )
        result["mode"] = chosen
        return result

    # ── Misc ────────────────────────────────────────────────────────────

    def status(self) -> Dict[str, Any]:
        if not self.store.exists:
            return {"built": False}
        meta = self.store.build_meta()
        return {"built": True, **meta}

    def close(self) -> None:
        try:
            self.chunk_store.close()
        except Exception:
            pass
