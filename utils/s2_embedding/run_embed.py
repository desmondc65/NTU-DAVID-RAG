"""
Main orchestration script for the embedding pipeline.

Usage:
    python -m utils.s2_embedding.run_embed \
        --manuscript "data/.../Manuscript_content_list.json" \
        --fortran "data/.../fortran_chunks.json" \
        --output "data/.../vector_store"

    Add --test-query to run smoke queries after embedding.
"""

import argparse
import hashlib
import os
import time
from pathlib import Path
from typing import Optional

from utils.s2_embedding.chunker import chunk_manuscript, chunk_fortran
from utils.s2_embedding.embedder import EmbeddingModel, _DEFAULT_MODEL
from utils.s2_embedding.vector_store import VectorStore


def _make_id(content_type: str, source: str, chunk_idx: int) -> str:
    """Generate a deterministic document ID."""
    raw = f"{content_type}:{source}:{chunk_idx}"
    return hashlib.md5(raw.encode()).hexdigest()


def run_embedding_pipeline(
    manuscript_path: Optional[str],
    fortran_path: Optional[str],
    output_dir: str,
    model_name: str = _DEFAULT_MODEL,
    device: Optional[str] = None,
    test_query: bool = False,
) -> None:
    """Run the full embedding pipeline."""

    all_chunks = []  # type: list

    # --- Chunking ---
    print("=" * 60)
    print("STEP 1: Chunking")
    print("=" * 60)

    if manuscript_path:
        print(f"\nChunking manuscript: {manuscript_path}")
        ms_chunks = chunk_manuscript(manuscript_path)
        print(f"  → {len(ms_chunks)} manuscript chunks")
        all_chunks.extend(ms_chunks)

    if fortran_path:
        print(f"\nChunking Fortran code: {fortran_path}")
        ft_chunks = chunk_fortran(fortran_path)
        print(f"  → {len(ft_chunks)} Fortran code chunks")
        all_chunks.extend(ft_chunks)

    if not all_chunks:
        print("No chunks produced. Exiting.")
        return

    print(f"\nTotal chunks: {len(all_chunks)}")

    # --- Embedding ---
    print("\n" + "=" * 60)
    print("STEP 2: Embedding")
    print("=" * 60)

    print(f"\nLoading model: {model_name} (device={device or 'auto'})")
    embedder = EmbeddingModel(model_name=model_name, device=device)

    texts = [c["text"] for c in all_chunks]
    print(f"Embedding {len(texts)} chunks...")
    t0 = time.time()
    embeddings = embedder.embed_documents(texts)
    elapsed = time.time() - t0
    print(f"  → Done in {elapsed:.1f}s ({len(texts) / elapsed:.1f} chunks/s)")

    # --- Storage ---
    print("\n" + "=" * 60)
    print("STEP 3: Storing in ChromaDB")
    print("=" * 60)

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    print(f"\nPersist directory: {output_path}")

    store = VectorStore(persist_dir=str(output_path))

    ids = []
    metadatas = []
    for c in all_chunks:
        meta = c["metadata"]
        doc_id = _make_id(
            meta["content_type"],
            meta.get("source_file", ""),
            meta["chunk_idx"],
        )
        ids.append(doc_id)
        metadatas.append(meta)

    store.add_documents(
        texts=texts,
        embeddings=embeddings,
        metadatas=metadatas,
        ids=ids,
    )

    print(f"\n✓ Stored {store.count} documents in ChromaDB")
    print(f"  Collection: rag_embeddings")
    print(f"  Location: {output_path.resolve()}")

    # --- Smoke test ---
    if test_query:
        print("\n" + "=" * 60)
        print("STEP 4: Smoke Query Test")
        print("=" * 60)

        test_queries = [
            ("What drives wealth concentration?", None),
            ("value function iteration", None),
            ("earnings heterogeneity capital income", {"content_type": "manuscript"}),
            ("subroutine asset grid", {"content_type": "code"}),
        ]

        for query, where_filter in test_queries:
            filter_desc = f" (filter: {where_filter})" if where_filter else ""
            print(f"\nQuery: '{query}'{filter_desc}")
            q_emb = embedder.embed_query(query)
            results = store.query(q_emb, n_results=3, where_filter=where_filter)

            for i, (doc, meta, dist) in enumerate(
                zip(
                    results["documents"][0],
                    results["metadatas"][0],
                    results["distances"][0],
                )
            ):
                print(f"  [{i+1}] score={1-dist:.4f} | type={meta.get('content_type')} | {doc[:120]}...")

    print("\n✓ Pipeline complete!")


def main():
    parser = argparse.ArgumentParser(
        description="Embed academic manuscript and Fortran code into ChromaDB"
    )
    parser.add_argument(
        "--manuscript",
        type=str,
        default=None,
        help="Path to Manuscript_content_list.json",
    )
    parser.add_argument(
        "--fortran",
        type=str,
        default=None,
        help="Path to fortran_chunks.json",
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Output directory for ChromaDB persistent storage",
    )
    parser.add_argument(
        "--model",
        type=str,
        default=_DEFAULT_MODEL,
        help=f"Embedding model name (default: {_DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--test-query",
        action="store_true",
        help="Run smoke queries after embedding",
    )

    parser.add_argument(
        "--device",
        type=str,
        default=None,
        help="Device for embedding model, e.g. 'cuda:0' (default: auto)",
    )

    args = parser.parse_args()

    if not args.manuscript and not args.fortran:
        parser.error("At least one of --manuscript or --fortran must be specified")

    run_embedding_pipeline(
        manuscript_path=args.manuscript,
        fortran_path=args.fortran,
        output_dir=args.output,
        model_name=args.model,
        device=args.device,
        test_query=args.test_query,
    )


if __name__ == "__main__":
    main()
