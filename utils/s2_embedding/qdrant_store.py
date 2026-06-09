"""
Qdrant vector store wrapper for persistent local storage.

Stores embeddings with metadata and supports filtered nearest-neighbor queries.
Uses local disk persistence (no server required).
"""
from __future__ import annotations

import uuid
from pathlib import Path
from typing import Dict, List, Optional, Union

from qdrant_client import QdrantClient, models


class QdrantVectorStore:
    """Wrapper around a Qdrant local-disk collection."""

    def __init__(
        self,
        persist_dir: str,
        collection_name: str = "rag_embeddings",
        vector_size: int = 3584,
        client: Optional[QdrantClient] = None,
        manage_schema: bool = True,
    ):
        """
        Args:
            persist_dir: Directory for Qdrant on-disk storage.
            collection_name: Name of the collection.
            vector_size: Dimensionality of embedding vectors.
            client: Optional existing QdrantClient to reuse. Qdrant's local
                path mode acquires a filesystem lock, so sharing a client
                is required when opening multiple collections in the same
                process (e.g. the chunk collection + the paper_profiles
                collection). When ``None`` a new client is created and
                owned by this instance.
            manage_schema: When True (write path), create the collection if it
                is missing and, if it already exists, assert its vector size
                matches ``vector_size`` — this catches a wrong-dimension write
                loudly instead of letting Qdrant fail opaquely on upsert.
                Set False for payload-only / read-only opens (delete, metadata
                rename), where ``vector_size`` is unknown and irrelevant.
        """
        self.persist_dir = persist_dir
        self.collection_name = collection_name
        Path(persist_dir).mkdir(parents=True, exist_ok=True)

        if client is not None:
            self.client = client
            self._owns_client = False
        else:
            self.client = QdrantClient(path=persist_dir)
            self._owns_client = True

        existing = [c.name for c in self.client.get_collections().collections]
        if collection_name not in existing:
            if manage_schema:
                self.client.create_collection(
                    collection_name=collection_name,
                    vectors_config=models.VectorParams(
                        size=vector_size,
                        distance=models.Distance.COSINE,
                    ),
                )
        elif manage_schema:
            self._assert_vector_size(vector_size)

    def _assert_vector_size(self, expected: int) -> None:
        """Raise if the existing collection's vector size != ``expected``.

        Different embedding models must live in different collections (see
        ``utils.s2_embedding.collections``); this guard makes a misroute fail
        with an actionable message rather than a cryptic upsert error.
        """
        try:
            params = self.client.get_collection(self.collection_name).config.params.vectors
            size = getattr(params, "size", None)
        except Exception:
            return  # can't introspect (e.g. named-vector config) — don't block
        if size is None or expected is None:
            return
        if int(size) != int(expected):
            raise ValueError(
                f"Collection '{self.collection_name}' stores {size}-dim vectors, "
                f"but the active embedder produces {expected}-dim vectors. Each "
                f"embedding model uses its own collection — see "
                f"utils/s2_embedding/collections.py. Point this model at its own "
                f"collection (the default), or wipe this one to repurpose it."
            )

    def add_documents(
        self,
        texts: List[str],
        embeddings: List[List[float]],
        metadatas: List[Dict],
        ids: List[str],
    ) -> None:
        """
        Upsert documents into the collection.

        Args:
            texts: Document text strings (stored in payload as "document").
            embeddings: Corresponding embedding vectors.
            metadatas: Metadata dicts for each document.
            ids: Unique string IDs for each document.
        """
        points = []
        for text, emb, meta, doc_id in zip(texts, embeddings, metadatas, ids):
            # Build payload: metadata + the document text
            payload = {**meta, "document": text}
            points.append(
                models.PointStruct(
                    id=doc_id,
                    vector=emb,
                    payload=payload,
                )
            )

        self.client.upsert(
            collection_name=self.collection_name,
            points=points,
        )

    def query(
        self,
        query_embedding: List[float],
        n_results: int = 5,
        where_filter: Optional[Dict] = None,
    ) -> Dict:
        """
        Query the collection for nearest neighbors.

        Args:
            query_embedding: The query vector.
            n_results: Number of results to return.
            where_filter: Optional filter dict, e.g. {"content_type": "manuscript"}.
                          Keys map to payload fields with exact-match semantics.

        Returns:
            Dict with keys: ids, documents, metadatas, scores
        """
        qdrant_filter = None
        if where_filter:
            conditions = [
                models.FieldCondition(
                    key=k,
                    match=models.MatchValue(value=v),
                )
                for k, v in where_filter.items()
            ]
            qdrant_filter = models.Filter(must=conditions)

        results = self.client.query_points(
            collection_name=self.collection_name,
            query=query_embedding,
            limit=n_results,
            query_filter=qdrant_filter,
            with_payload=True,
        ).points

        ids = []
        documents = []
        metadatas = []
        scores = []
        for pt in results:
            ids.append(pt.id)
            payload = dict(pt.payload) if pt.payload else {}
            documents.append(payload.pop("document", ""))
            metadatas.append(payload)
            scores.append(pt.score)

        return {
            "ids": ids,
            "documents": documents,
            "metadatas": metadatas,
            "scores": scores,
        }

    @property
    def count(self) -> int:
        """Return the number of documents in the collection."""
        info = self.client.get_collection(self.collection_name)
        return info.points_count

    def close(self) -> None:
        """Close the underlying Qdrant client and release local storage locks.

        No-op when the client was provided externally — the owner closes it.
        """
        if not getattr(self, "_owns_client", True):
            return
        client = getattr(self, "client", None)
        if client is None:
            return
        try:
            client.close()
        except Exception:
            pass
