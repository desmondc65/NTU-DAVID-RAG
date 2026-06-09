"""
Embedding model wrapper using sentence-transformers.

Uses Alibaba-NLP/gte-Qwen2-7B-instruct by default — top-tier MTEB
performance, 3584-dim embeddings, 8192-token context.  Needs ~15 GB
VRAM in fp16 (fits comfortably on a 30 GB GPU).

Falls back to BAAI/bge-large-en-v1.5 when passed explicitly.

Remote mode
-----------
When the ``RAG_EMBEDDING_SERVER_URL`` environment variable is set, the
wrapper skips the local model load and routes ``embed_query`` /
``embed_documents`` to that HTTP service instead. This lets multiple
backend containers share a single GPU-resident embedder (see
``docker/embedding_server``). The server applies the instruction
prefixes, so the client just sends raw text.
"""

import os
from typing import List, Optional

from sentence_transformers import SentenceTransformer

# gte-Qwen2-7B-instruct ships custom modeling_qwen.py pinned to an older HF
# transformers API; it calls DynamicCache.get_usable_length and
# DynamicCache.from_legacy_cache, both removed in transformers >=4.47.
# Re-add them as thin shims so the remote modeling code runs unchanged
# against current transformers.
try:
    from transformers.cache_utils import DynamicCache

    if not hasattr(DynamicCache, "get_usable_length"):
        def _get_usable_length(self, new_seq_length: int, layer_idx: int = 0) -> int:
            return self.get_seq_length(layer_idx)

        DynamicCache.get_usable_length = _get_usable_length  # type: ignore[attr-defined]

    if not hasattr(DynamicCache, "from_legacy_cache"):
        @classmethod
        def _from_legacy_cache(cls, past_key_values=None):
            cache = cls()
            if past_key_values is None:
                return cache
            for layer_idx, layer in enumerate(past_key_values):
                key_states, value_states = layer
                cache.update(key_states, value_states, layer_idx)
            return cache

        DynamicCache.from_legacy_cache = _from_legacy_cache  # type: ignore[attr-defined]

    if not hasattr(DynamicCache, "to_legacy_cache"):
        def _to_legacy_cache(self):
            legacy = ()
            key_cache = getattr(self, "key_cache", None)
            value_cache = getattr(self, "value_cache", None)
            if key_cache is None or value_cache is None:
                return legacy
            for layer_idx in range(len(key_cache)):
                legacy += ((key_cache[layer_idx], value_cache[layer_idx]),)
            return legacy

        DynamicCache.to_legacy_cache = _to_legacy_cache  # type: ignore[attr-defined]
except ImportError:
    pass

# Some older transformers builds expose Qwen2Config without rope_theta.
# gte-Qwen2's remote modeling code expects the attribute to exist.
try:
    from transformers.models.qwen2.configuration_qwen2 import Qwen2Config

    if not hasattr(Qwen2Config, "rope_theta"):
        Qwen2Config.rope_theta = 10000.0  # type: ignore[attr-defined]
except ImportError:
    pass


_DEFAULT_MODEL = "Alibaba-NLP/gte-Qwen2-7B-instruct"

# Instruction prefixes per model family (asymmetric retrieval)
_BGE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: "
_GTE_QUERY_PREFIX = "Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery: "
_E5_QUERY_PREFIX = "query: "
# EmbeddingGemma is trained with explicit task prompts; these are the exact
# retrieval prompts from its model card. The document side assumes no title
# is available ("title: none | text: <passage>").
_EMBEDDINGGEMMA_QUERY_PREFIX = "task: search result | query: "
_EMBEDDINGGEMMA_DOC_PREFIX = "title: none | text: "


def _query_prefix(model_name: str) -> str:
    """Return the appropriate query-side instruction prefix."""
    name = model_name.lower()
    if "gte-qwen" in name:
        return _GTE_QUERY_PREFIX
    if "embeddinggemma" in name:
        return _EMBEDDINGGEMMA_QUERY_PREFIX
    if "bge" in name:
        return _BGE_QUERY_PREFIX
    if "e5" in name:
        return _E5_QUERY_PREFIX
    return ""


def _doc_prefix(model_name: str) -> str:
    """Return the appropriate document-side instruction prefix."""
    name = model_name.lower()
    if "embeddinggemma" in name:
        return _EMBEDDINGGEMMA_DOC_PREFIX
    if "e5" in name:
        return "passage: "
    return ""


class EmbeddingModel:
    """Wrapper around a sentence-transformers model for embedding.

    Two modes:
      * **Local** (default): loads the model into the chosen device.
      * **Remote**: when ``RAG_EMBEDDING_SERVER_URL`` env is set, defers
        encoding to that HTTP service. No model is loaded locally — the
        wrapper is a thin client. The server owns the prefix logic.
    """

    def __init__(self, model_name: str = _DEFAULT_MODEL, device: Optional[str] = None):
        """
        Args:
            model_name: HuggingFace model ID or local path.
            device: 'cuda', 'cpu', or None (auto-detect).
        """
        self.model_name = model_name
        self._query_prefix = _query_prefix(model_name)
        self._doc_prefix = _doc_prefix(model_name)

        remote_url = os.getenv("RAG_EMBEDDING_SERVER_URL", "").strip().rstrip("/")
        if remote_url:
            # Remote mode: lazily create a requests.Session, do not load the model.
            import requests  # local import so non-Docker tests don't require it unless used

            self._remote_url = remote_url
            self._session = requests.Session()
            timeout_env = os.getenv("RAG_EMBEDDING_HTTP_TIMEOUT", "600")
            try:
                self._timeout = float(timeout_env)
            except ValueError:
                self._timeout = 600.0
            self.model = None
        else:
            self._remote_url = None
            self._session = None
            self._timeout = None
            self.model = SentenceTransformer(model_name, device=device, trust_remote_code=True)

    def embed_documents(
        self, texts: List[str], batch_size: int = 8, show_progress: bool = True
    ) -> List[List[float]]:
        """
        Embed a list of document texts (passages to be stored).

        Args:
            texts: List of document strings.
            batch_size: Encoding batch size.
            show_progress: Show progress bar (ignored in remote mode).

        Returns:
            List of embedding vectors (list of floats).
        """
        if not texts:
            return []

        if self._remote_url:
            resp = self._session.post(
                f"{self._remote_url}/embed/documents",
                json={"texts": texts, "batch_size": batch_size},
                timeout=self._timeout,
            )
            resp.raise_for_status()
            return resp.json()["embeddings"]

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
        if self._remote_url:
            resp = self._session.post(
                f"{self._remote_url}/embed/query",
                json={"query": query},
                timeout=self._timeout,
            )
            resp.raise_for_status()
            return resp.json()["embedding"]

        text = f"{self._query_prefix}{query}" if self._query_prefix else query
        embedding = self.model.encode(
            [text], normalize_embeddings=True
        )
        return embedding[0].tolist()
