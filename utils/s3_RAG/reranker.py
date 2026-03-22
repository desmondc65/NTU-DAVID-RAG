"""
Cross-Encoder Reranker using BGE-Reranker-v2.

Non-negotiable final stage: takes the top-N results from hybrid retrieval
and rigorously scores each passage against the exact user query using a
cross-encoder, pushing irrelevant results to the bottom.
"""

from typing import Dict, List, Optional

from sentence_transformers import CrossEncoder


_DEFAULT_RERANKER = "BAAI/bge-reranker-v2-m3"


class Reranker:
    """Cross-encoder reranker for refining hybrid retrieval results."""

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

        # Build query-passage pairs for cross-encoder
        pairs = [(query, r["text"]) for r in results]

        # Score all pairs
        scores = self.model.predict(pairs, show_progress_bar=False)

        # Attach scores and sort
        for result, score in zip(results, scores):
            result["rerank_score"] = float(score)

        reranked = sorted(results, key=lambda x: x["rerank_score"], reverse=True)

        return reranked[:top_k]
