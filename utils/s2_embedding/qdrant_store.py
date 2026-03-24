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
        vector_size: int = 1024,
    ):
        """
        Args:
            persist_dir: Directory for Qdrant on-disk storage.
            collection_name: Name of the collection.
            vector_size: Dimensionality of embedding vectors.
        """
        self.persist_dir = persist_dir
        self.collection_name = collection_name
        Path(persist_dir).mkdir(parents=True, exist_ok=True)

        self.client = QdrantClient(path=persist_dir)

        # Create collection if it doesn't exist
        existing = [c.name for c in self.client.get_collections().collections]
        if collection_name not in existing:
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=models.VectorParams(
                    size=vector_size,
                    distance=models.Distance.COSINE,
                ),
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
        """Close the underlying Qdrant client and release local storage locks."""
        client = getattr(self, "client", None)
        if client is None:
            return
        try:
            client.close()
        except Exception:
            pass
