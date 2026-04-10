"""
Embedding model wrapper using sentence-transformers.

Uses Alibaba-NLP/gte-Qwen2-7B-instruct by default — top-tier MTEB
performance, 3584-dim embeddings, 8192-token context.  Needs ~15 GB
VRAM in fp16 (fits comfortably on a 30 GB GPU).

Falls back to BAAI/bge-large-en-v1.5 when passed explicitly.
"""

from typing import List, Optional

from sentence_transformers import SentenceTransformer


_DEFAULT_MODEL = "Alibaba-NLP/gte-Qwen2-7B-instruct"

# Instruction prefixes per model family (asymmetric retrieval)
_BGE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: "
_GTE_QUERY_PREFIX = "Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery: "
_E5_QUERY_PREFIX = "query: "


def _query_prefix(model_name: str) -> str:
    """Return the appropriate query-side instruction prefix."""
    name = model_name.lower()
    if "gte-qwen" in name:
        return _GTE_QUERY_PREFIX
    if "bge" in name:
        return _BGE_QUERY_PREFIX
    if "e5" in name:
        return _E5_QUERY_PREFIX
    return ""


def _doc_prefix(model_name: str) -> str:
    """Return the appropriate document-side instruction prefix."""
    name = model_name.lower()
    if "e5" in name:
        return "passage: "
    return ""


class EmbeddingModel:
    """Wrapper around a sentence-transformers model for embedding."""

    def __init__(self, model_name: str = _DEFAULT_MODEL, device: Optional[str] = None):
        """
        Args:
            model_name: HuggingFace model ID or local path.
            device: 'cuda', 'cpu', or None (auto-detect).
        """
        self.model_name = model_name
        self.model = SentenceTransformer(model_name, device=device, trust_remote_code=True)
        self._query_prefix = _query_prefix(model_name)
        self._doc_prefix = _doc_prefix(model_name)

    def embed_documents(
        self, texts: List[str], batch_size: int = 8, show_progress: bool = True
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
        if self._doc_prefix:
            texts = [f"{self._doc_prefix}{t}" for t in texts]
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

        Args:
            query: The search query string.

        Returns:
            Embedding vector as list of floats.
        """
        text = f"{self._query_prefix}{query}" if self._query_prefix else query
        embedding = self.model.encode(
            [text], normalize_embeddings=True
        )
        return embedding[0].tolist()
