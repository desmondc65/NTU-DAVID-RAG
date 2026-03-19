"""
Embedding model wrapper using sentence-transformers.

Uses BAAI/bge-large-en-v1.5 by default — strong on both academic text
and code retrieval, 1024-dim embeddings, 512-token context.
"""

from typing import List, Optional

from sentence_transformers import SentenceTransformer


# BGE models use a query instruction prefix for asymmetric retrieval
_DEFAULT_MODEL = "BAAI/bge-large-en-v1.5"
_BGE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: "


class EmbeddingModel:
    """Wrapper around a sentence-transformers model for embedding."""

    def __init__(self, model_name: str = _DEFAULT_MODEL, device: Optional[str] = None):
        """
        Args:
            model_name: HuggingFace model ID or local path.
            device: 'cuda', 'cpu', or None (auto-detect).
        """
        self.model_name = model_name
        self.model = SentenceTransformer(model_name, device=device)
        self.is_bge = "bge" in model_name.lower()

    def embed_documents(
        self, texts: List[str], batch_size: int = 32, show_progress: bool = True
    ) -> List[List[float]]:
        """
        Embed a list of document texts (passages to be stored).

        Args:
            texts: List of document strings.
            batch_size: Encoding batch size.
            show_progress: Show progress bar.

        Returns:
            List of embedding vectors (list of floats).
        """
        embeddings = self.model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=show_progress,
            normalize_embeddings=True,
        )
        return embeddings.tolist()  # type: ignore

    def embed_query(self, query: str) -> List[float]:
        """
        Embed a single query text (for retrieval).
        Applies BGE query instruction prefix if using a BGE model.

        Args:
            query: The search query string.

        Returns:
            Embedding vector as list of floats.
        """
        text = f"{_BGE_QUERY_PREFIX}{query}" if self.is_bge else query
        embedding = self.model.encode(
            [text], normalize_embeddings=True
        )
        return embedding[0].tolist()
