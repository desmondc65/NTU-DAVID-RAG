"""
ChromaDB vector store wrapper for persistent local storage.

Stores embeddings with metadata and supports filtered nearest-neighbor queries.
"""

from typing import Dict, List, Optional

import chromadb
from chromadb.config import Settings


class VectorStore:
    """Wrapper around a ChromaDB persistent collection."""

    def __init__(self, persist_dir: str, collection_name: str = "rag_embeddings"):
        """
        Args:
            persist_dir: Directory for ChromaDB persistent storage.
            collection_name: Name of the collection.
        """
        self.persist_dir = persist_dir
        self.client = chromadb.PersistentClient(
            path=persist_dir,
            settings=Settings(anonymized_telemetry=False),
        )
        self.collection = self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )

    def add_documents(
        self,
        texts: List[str],
        embeddings: List[List[float]],
        metadatas: List[Dict],
        ids: List[str],
    ) -> None:
        """
        Add (or upsert) documents into the collection.

        Args:
            texts: Document text strings.
            embeddings: Corresponding embedding vectors.
            metadatas: Metadata dicts for each document.
            ids: Unique IDs for each document.
        """
        # ChromaDB metadata values must be str, int, float, or bool
        clean_metadatas = []
        for m in metadatas:
            clean = {}
            for k, v in m.items():
                if isinstance(v, list):
                    clean[k] = str(v)
                else:
                    clean[k] = v
            clean_metadatas.append(clean)

        self.collection.upsert(
            ids=ids,
            documents=texts,
            embeddings=embeddings,
            metadatas=clean_metadatas,
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
            where_filter: Optional ChromaDB where clause,
                          e.g. {"content_type": "manuscript"}.

        Returns:
            ChromaDB query result dict with keys:
                ids, documents, metadatas, distances
        """
        kwargs = {
            "query_embeddings": [query_embedding],
            "n_results": n_results,
        }
        if where_filter:
            kwargs["where"] = where_filter

        return self.collection.query(**kwargs)

    @property
    def count(self) -> int:
        """Return the number of documents in the collection."""
        return self.collection.count()
