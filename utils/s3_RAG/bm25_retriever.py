"""
BM25 Sparse Retriever for lexical matching.

Critical for finding exact variable names (e.g., REAL*8 dimension(50,50)),
specific algorithm names, and Fortran identifiers that dense retrieval
may miss.
"""

import json
import re
from typing import Dict, List, Optional, Tuple

from rank_bm25 import BM25Okapi


def _tokenize(text: str) -> List[str]:
    """
    Tokenize text for BM25 indexing.

    Preserves Fortran-specific tokens (underscores, parentheses patterns)
    alongside standard word tokenization.  Also keeps hyphenated compounds
    (e.g. "overlapping-generations", "two-earner") as additional tokens
    for better academic-text matching.
    """
    text = text.lower()
    # Primary tokens: alphanumeric + underscores + dots
    tokens = re.findall(r"[a-z0-9_\.]+", text)
    # Keep hyphenated compounds as single tokens (e.g. "life-cycle", "two-earner")
    compounds = re.findall(r"[a-z0-9]+-[a-z0-9]+(?:-[a-z0-9]+)*", text)
    tokens.extend(compounds)
    return tokens


class BM25Retriever:
    """BM25-based sparse retrieval over a corpus of text chunks."""

    def __init__(self):
        self.documents = []  # type: List[str]
        self.metadatas = []  # type: List[Dict]
        self.doc_ids = []  # type: List[str]
        self.bm25 = None  # type: Optional[BM25Okapi]
        self._tokenized_corpus = []  # type: List[List[str]]

    def index_documents(
        self,
        texts: List[str],
        metadatas: List[Dict],
        ids: List[str],
    ) -> None:
        """
        Build the BM25 index from a corpus of documents.

        Args:
            texts: List of document text strings.
            metadatas: List of metadata dicts for each document.
            ids: Unique ID for each document.
        """
        self.documents = texts
        self.metadatas = metadatas
        self.doc_ids = ids
        self._tokenized_corpus = [_tokenize(doc) for doc in texts]
        self.bm25 = BM25Okapi(self._tokenized_corpus)

    def retrieve(
        self,
        query: str,
        top_k: int = 50,
        where_filter: Optional[Dict] = None,
    ) -> List[Dict]:
        """
        Retrieve top-k documents by BM25 score.

        Args:
            query: The search query string.
            top_k: Number of results to return.
            where_filter: Optional metadata filter, e.g. {"content_type": "code"}.

        Returns:
            List of result dicts with keys: id, text, metadata, score
        """
        if self.bm25 is None:
            raise RuntimeError("Index not built. Call index_documents() first.")

        tokenized_query = _tokenize(query)
        scores = self.bm25.get_scores(tokenized_query)

        # Pair scores with indices
        scored_indices = list(enumerate(scores))

        # Apply metadata filter if specified
        if where_filter:
            scored_indices = [
                (idx, score)
                for idx, score in scored_indices
                if all(
                    self.metadatas[idx].get(k) == v
                    for k, v in where_filter.items()
                )
            ]

        # Sort by score descending
        scored_indices.sort(key=lambda x: x[1], reverse=True)

        results = []
        for idx, score in scored_indices[:top_k]:
            if score <= 0:
                continue
            results.append({
                "id": self.doc_ids[idx],
                "text": self.documents[idx],
                "metadata": self.metadatas[idx],
                "score": float(score),
            })

        return results

    def save_index(self, path: str) -> None:
        """Save the indexed corpus to a JSON file for fast reload."""
        data = {
            "documents": self.documents,
            "metadatas": self.metadatas,
            "doc_ids": self.doc_ids,
        }
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)

    def load_index(self, path: str) -> None:
        """Load a previously saved corpus and rebuild the BM25 index."""
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        self.index_documents(
            texts=data["documents"],
            metadatas=data["metadatas"],
            ids=data["doc_ids"],
        )
