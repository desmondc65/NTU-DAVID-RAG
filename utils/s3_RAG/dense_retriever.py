"""
Dense Retriever using ChromaDB vector store and BGE embedding model.

Captures semantic intent — e.g., searching for "fluid dynamics temperature
gradient" will surface the Fortran code calculating it, even if those
exact words are not in the comments.
"""

from typing import Dict, List, Optional

from utils.s2_embedding.embedder import EmbeddingModel
from utils.s2_embedding.vector_store import VectorStore


class DenseRetriever:
    """Dense vector retrieval via ChromaDB and sentence-transformers."""

    def __init__(
        self,
        vector_store_dir: str,
        collection_name: str = "rag_embeddings",
        embedding_model: str = "BAAI/bge-large-en-v1.5",
        device: Optional[str] = None,
    ):
        """
        Args:
            vector_store_dir: Path to ChromaDB persistent storage.
            collection_name: Name of the collection.
            embedding_model: HuggingFace model ID.
            device: 'cuda:0', 'cpu', or None (auto-detect).
        """
        self.store = VectorStore(
            persist_dir=vector_store_dir,
            collection_name=collection_name,
        )
        self.embedder = EmbeddingModel(
            model_name=embedding_model,
            device=device,
        )

    def retrieve(
        self,
        query: str,
        top_k: int = 50,
        where_filter: Optional[Dict] = None,
    ) -> List[Dict]:
        """
        Retrieve top-k documents by vector similarity.

        Args:
            query: The search query string.
            top_k: Number of results to return.
            where_filter: Optional metadata filter.

        Returns:
            List of result dicts with keys: id, text, metadata, score
        """
        query_embedding = self.embedder.embed_query(query)
        results = self.store.query(
            query_embedding=query_embedding,
            n_results=top_k,
            where_filter=where_filter,
        )

        # Flatten ChromaDB's nested result format
        output = []
        if results["ids"] and results["ids"][0]:
            for i in range(len(results["ids"][0])):
                # ChromaDB returns cosine distance; convert to similarity score
                distance = results["distances"][0][i]
                score = 1.0 - distance
                output.append({
                    "id": results["ids"][0][i],
                    "text": results["documents"][0][i],
                    "metadata": results["metadatas"][0][i],
                    "score": score,
                })

        return output

    def get_all_documents(self) -> Dict:
        """
        Retrieve all documents from the collection (for BM25 indexing).

        Returns:
            Dict with keys: ids, documents, metadatas
        """
        collection = self.store.collection
        count = collection.count()
        if count == 0:
            return {"ids": [], "documents": [], "metadatas": []}

        return collection.get(include=["documents", "metadatas"])
