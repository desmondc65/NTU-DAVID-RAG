"""
Cross-Encoder Reranker using BGE-Reranker-v2.

Non-negotiable final stage: takes the top-N results from hybrid retrieval
and rigorously scores each passage against the exact user query using a
cross-encoder, pushing irrelevant results to the bottom.

Remote mode
-----------
When ``RAG_RERANKER_SERVER_URL`` env is set, scoring is delegated to
that HTTP service. The client handles sorting and top-k slicing so the
server stays stateless.
"""

import os
from typing import Dict, List, Optional

from sentence_transformers import CrossEncoder


_DEFAULT_RERANKER = "BAAI/bge-reranker-v2-m3"


class Reranker:
    """Cross-encoder reranker for refining hybrid retrieval results.

    Two modes:
      * **Local** (default): loads the cross-encoder into the chosen device.
      * **Remote**: when ``RAG_RERANKER_SERVER_URL`` is set (typically
        pointing at the shared embedding/reranker service), scoring is
        performed over HTTP. No model is loaded locally.
    """

    def __init__(
        self,
        model_name: str = _DEFAULT_RERANKER,
        device: Optional[str] = None,
    ):
        """
        Args:
            model_name: HuggingFace cross-encoder model ID.
            device: 'cuda:0', 'cpu', or None (auto-detect).
        """
        self.model_name = model_name

        remote_url = os.getenv("RAG_RERANKER_SERVER_URL", "").strip().rstrip("/")
        if remote_url:
            import requests

            self._remote_url = remote_url
            self._session = requests.Session()
            timeout_env = os.getenv("RAG_RERANKER_HTTP_TIMEOUT", "600")
            try:
                self._timeout = float(timeout_env)
            except ValueError:
                self._timeout = 600.0
            self.model = None
        else:
            self._remote_url = None
            self._session = None
            self._timeout = None
            self.model = CrossEncoder(model_name, device=device)

    def rerank(
        self,
        query: str,
        results: List[Dict],
        top_k: int = 10,
    ) -> List[Dict]:
        """
        Rerank retrieval results using the cross-encoder.

        Args:
            query: The original user query.
            results: List of result dicts (must have 'text' key).
            top_k: Number of top results to return after reranking.

        Returns:
            Reranked list of result dicts, sorted by cross-encoder score,
            with an added 'rerank_score' field.
        """
        if not results:
            return []

        passages = [r["text"] for r in results]

        if self._remote_url:
            resp = self._session.post(
                f"{self._remote_url}/rerank",
                json={"query": query, "passages": passages},
                timeout=self._timeout,
            )
            resp.raise_for_status()
            scores = resp.json()["scores"]
        else:
            pairs = [(query, p) for p in passages]
            scores = self.model.predict(pairs, show_progress_bar=False)

        for result, score in zip(results, scores):
            result["rerank_score"] = float(score)

        reranked = sorted(results, key=lambda x: x["rerank_score"], reverse=True)

        return reranked[:top_k]
