# s3_RAG: Hybrid Retrieval Pipeline (BM25 + Dense + Reranker)

This directory contains the full Stage-3 retrieval stack used after document/code chunks have already been embedded and stored.

The design combines three retrieval ideas:

1. Sparse lexical retrieval (BM25) to capture exact strings, identifiers, equations, and code tokens.
2. Dense semantic retrieval over vector embeddings to capture meaning-level similarity.
3. Cross-encoder reranking to rescore top candidates with query-document interaction.

It is orchestrated by `HybridRAG` and exposed through an interactive CLI in `run_rag.py`.

---

## Directory Contents

- `__init__.py`
- `bm25_retriever.py`
- `dense_retriever.py`
- `hybrid_rag.py`
- `reranker.py`
- `run_rag.py`
- `readme.md`

`__pycache__/` is runtime-generated and not part of the source design.

---

## End-to-End Retrieval Flow

For a user query `q`, the pipeline executes:

1. **BM25 retrieval**: returns top `sparse_top_k` by lexical match score.
2. **Dense retrieval**: returns top `dense_top_k` by vector similarity.
3. **Reciprocal Rank Fusion (RRF)**: merges both ranked lists by rank positions.
4. **Cross-encoder reranking**: reranks top fused candidates and outputs `final_top_k`.

Mathematically, if a document appears at rank `r_i` in retrieval list `i`, the RRF score is:

$$
\mathrm{RRF}(d) = \sum_i \frac{1}{k + r_i}
$$

where `k` defaults to `60`.

This gives robust blended retrieval: exact-match recall from BM25 plus semantic recall from embeddings, then precision uplift from the cross-encoder.

---

## File-by-File Deep Explanation

### 1) `__init__.py`

Current role:

- Package marker for Python import resolution under `utils.s3_RAG`.
- No symbols are exported explicitly from this file.

Implication:

- Importers should reference concrete modules/classes directly (for example, from `utils.s3_RAG.hybrid_rag import HybridRAG`).

---

### 2) `bm25_retriever.py`

Purpose:

- Implements sparse retrieval using `rank_bm25.BM25Okapi`.
- Targets lexical precision, especially useful for code-oriented queries where exact token overlap matters.

#### Key Components

#### `_tokenize(text: str) -> List[str]`

- Lowercases input text.
- Uses regex `r"[a-z0-9_\.]+"` to keep:
	- letters and digits,
	- underscores (`_`) for identifiers,
	- periods (`.`) for token forms like module/file references and numeric patterns.

Why this matters:

- This tokenizer intentionally avoids pure whitespace splitting and captures common code-ish fragments better than naive tokenization.

#### `BM25Retriever` class

State fields:

- `documents: List[str]`
- `metadatas: List[Dict]`
- `doc_ids: List[str]`
- `bm25: Optional[BM25Okapi]`
- `_tokenized_corpus: List[List[str]]`

##### `index_documents(texts, metadatas, ids)`

- Stores raw corpus arrays.
- Tokenizes each document.
- Builds BM25 index via `BM25Okapi(tokenized_corpus)`.

Contract:

- `texts`, `metadatas`, and `ids` must be aligned by position.

##### `retrieve(query, top_k=50, where_filter=None)`

- Requires prior indexing; raises `RuntimeError` if `bm25` is not built.
- Tokenizes query and computes BM25 scores for all docs.
- Optionally filters by exact metadata equality for all key/value pairs in `where_filter`.
- Sorts by score descending.
- Returns only positive-score documents.

Return schema per item:

- `id: str`
- `text: str`
- `metadata: Dict`
- `score: float` (BM25 score)

##### `save_index(path)` and `load_index(path)`

- `save_index` serializes documents/metadata/ids to JSON.
- `load_index` restores serialized data and rebuilds BM25 index.

Important detail:

- This does not serialize BM25 internal structures directly; it reconstructs from saved corpus.

Complexity profile:

- Query scoring is effectively linear in corpus size on each query (`O(N)` scoring + sort cost), so retrieval size and corpus size directly affect latency.

---

### 3) `dense_retriever.py`

Purpose:

- Implements embedding-based semantic retrieval using Stage-2 abstractions:
	- `EmbeddingModel` from `utils.s2_embedding.embedder`
	- `VectorStore` from `utils.s2_embedding.vector_store`

#### `DenseRetriever` class

##### Constructor

Parameters:

- `vector_store_dir`: persistent ChromaDB path.
- `collection_name`: defaults to `rag_embeddings`.
- `embedding_model`: defaults to `BAAI/bge-large-en-v1.5`.
- `device`: `cuda:0`, `cpu`, or `None`.

Behavior:

- Creates `VectorStore` handle to existing persisted collection.
- Instantiates embedding model for query encoding.

##### `retrieve(query, top_k=50, where_filter=None)`

Execution:

1. Encodes query into embedding vector.
2. Calls vector store query with `n_results=top_k` and optional metadata filter.
3. Flattens ChromaDB nested response (batch dimension index 0).
4. Converts returned cosine distance to similarity as `score = 1.0 - distance`.

Return schema per item:

- `id: str`
- `text: str`
- `metadata: Dict`
- `score: float` (derived similarity)

Note on score semantics:

- These scores are not directly comparable to BM25 scores. They are only useful inside each retrieval stream unless normalized/fused by rank methods (which this code does via RRF).

##### `get_all_documents()`

- Reads complete collection content for BM25 indexing.
- Returns dict with `ids`, `documents`, `metadatas`.
- Returns empty lists when collection count is zero.

Operational consequence:

- BM25 index construction in `HybridRAG` depends on this method, so dense store availability is a hard dependency for the hybrid pipeline startup.

---

### 4) `reranker.py`

Purpose:

- Implements final precision stage using a cross-encoder from `sentence_transformers.CrossEncoder`.

Default model:

- `_DEFAULT_RERANKER = "BAAI/bge-reranker-v2-m3"`

#### `Reranker` class

##### Constructor

- Loads cross-encoder model on selected device.

##### `rerank(query, results, top_k=10)`

Behavior:

1. Early return `[]` when input `results` is empty.
2. Builds query-document pairs: `[(query, result["text"]), ...]`.
3. Calls `self.model.predict(...)` to get relevance scores.
4. Writes `rerank_score: float` into each result object.
5. Sorts by `rerank_score` descending and truncates to `top_k`.

Important mutation detail:

- The method mutates input result dictionaries by adding `rerank_score`.

Complexity and cost:

- Cross-encoder cost scales with number of candidate pairs and sequence lengths.
- This is much more expensive than BM25 or vector nearest-neighbor retrieval, which is why `hybrid_rag.py` caps reranker candidates to top 50 fused results.

---

### 5) `hybrid_rag.py`

Purpose:

- Orchestrates all retrieval components and defines the core query pipeline for Stage-3.

#### `_reciprocal_rank_fusion(result_lists, k=60)`

Inputs:

- `result_lists`: list of ranked lists (e.g., BM25 results and dense results).
- `k`: RRF constant.

Behavior:

- Iterates each list by rank (1-based).
- Aggregates RRF score per document ID.
- Deduplicates documents by ID, preserving first-seen payload in `doc_map`.
- Returns documents sorted by fused RRF score, each enriched with `rrf_score`.

Why rank fusion is used here:

- BM25 and dense scores are different scales/distributions; rank-level fusion avoids fragile score normalization.

#### `HybridRAG` class

##### Constructor

Startup sequence:

1. Loads dense retriever.
2. Initializes empty BM25 retriever.
3. Calls `_build_bm25_from_chromadb()` to index all documents from vector store.
4. Loads cross-encoder reranker.

Console output:

- Emits progress prints for operator visibility during model/index loading.

##### `_build_bm25_from_chromadb()`

- Calls `self.dense.get_all_documents()`.
- If empty collection, prints warning and exits without BM25 index.
- Otherwise builds BM25 index over all stored documents.

Edge-case implication:

- If no docs exist, later query calls may fail at BM25 retrieval step (because BM25 index was not built). This is expected by current implementation and should be handled operationally by ensuring ingestion/embedding completed first.

##### `query(query, sparse_top_k=50, dense_top_k=50, final_top_k=10, where_filter=None)`

Execution pipeline:

1. BM25 retrieve.
2. Dense retrieve.
3. Fuse via RRF.
4. Keep top 50 fused candidates.
5. Rerank and return top `final_top_k`.

Returned item fields (post-rerank) typically include:

- `id`, `text`, `metadata`
- retrieval-origin score (`score`, whichever source produced first-kept payload)
- `rrf_score`
- `rerank_score`

Subtle but important detail:

- When a document appears in both sparse and dense lists, whichever appears first during fusion determines the preserved base payload fields before adding `rrf_score`.

---

### 6) `run_rag.py`

Purpose:

- CLI/interactive entrypoint to run the hybrid retrieval system manually.

#### CLI Arguments

- `--vector-store` (required): path to ChromaDB persistent directory.
- `--collection` (default `rag_embeddings`): ChromaDB collection name.
- `--embedding-model` (default `BAAI/bge-large-en-v1.5`).
- `--reranker-model` (default `BAAI/bge-reranker-v2-m3`).
- `--device` (default `None`): e.g. `cuda:0` or `cpu`.
- `--top-k` (default `10`): final output count after reranking.
- `--filter` (default `all`): one of `manuscript`, `code`, `all`.

#### Runtime Behavior

- Loads environment variables via `dotenv.load_dotenv()`.
- Instantiates `HybridRAG` with provided args.
- Applies initial filter (`where_filter`) if requested.
- Enters interactive REPL loop:
	- query text runs retrieval,
	- `quit`/`exit`/`q` terminates,
	- `filter:code`, `filter:manuscript`, `filter:all` changes metadata filter live.

#### Output Formatting (`_print_results`)

For each result, prints:

- rank position,
- `rerank_score`,
- `rrf_score`,
- `content_type` metadata,
- content-specific metadata:
	- code: `file_name`, line range from `line_start`/`line_end`,
	- manuscript: `page_indices`,
- truncated text preview (200 chars, whitespace-normalized).

Operational note:

- This script is for retrieval inspection/debugging and does not generate final synthesized answers. It surfaces ranked contexts for downstream use.

---

### 7) `readme.md`

Purpose:

- Documentation for this directory and its architectural responsibilities.
- Should remain synchronized with implementation details in the above files.

---

## Data Contracts and Metadata Assumptions

Across modules, each retrieval result is expected to carry:

- `id`: unique chunk/document id.
- `text`: chunk content.
- `metadata`: dict used for filtering and display.

Common metadata keys used by current code:

- `content_type`: typically `code` or `manuscript`.
- `file_name`, `line_start`, `line_end` for code chunks.
- `page_indices` for manuscript chunks.

If these keys are absent, printing/filtering still runs but may show defaults (`unknown`, `?`, or blank values).

---

## Dependencies Referenced by This Directory

- `rank_bm25` (BM25 index/scoring).
- `sentence_transformers` (cross-encoder reranking).
- `python-dotenv` (environment loading in CLI).
- Stage-2 internal modules:
	- `utils.s2_embedding.embedder.EmbeddingModel`
	- `utils.s2_embedding.vector_store.VectorStore`

---

## Typical Usage

Run interactive retrieval:

```bash
CUDA_VISIBLE_DEVICES=2 python -m utils.s3_RAG.run_rag \
	--vector-store "data/<paper_or_dataset>/vector_store" \
	--device cuda:0 \
	--top-k 10
```

Inside the prompt:

- Type any retrieval query and press Enter.
- Use `filter:code` or `filter:manuscript` for scoped debugging.
- Use `filter:all` to reset.
- Use `quit` to exit.

---

## Performance and Operational Notes

- Startup cost includes loading embedding and reranker models plus BM25 indexing over all documents.
- Query latency contributors:
	- embedding inference,
	- vector store search,
	- BM25 scoring/sorting,
	- cross-encoder reranking (largest contributor).
- Memory footprint increases with corpus size due to in-memory BM25 tokenized corpus.
- For large corpora, reducing `sparse_top_k`, `dense_top_k`, or reranker candidate cap can lower latency.

---

## Failure Modes to Expect

- Empty or missing vector store/collection:
	- BM25 cannot be built from zero documents.
	- retrieval behavior will fail or be empty depending on path taken.
- Model loading failures:
	- invalid model id, network/model cache issues, or incompatible device.
- Metadata mismatch:
	- filtering with keys not present in metadata can silently return no rows.

---

## Suggested Extension Points

- Add score calibration/normalization if direct score-level fusion is desired.
- Introduce query expansion (multi-query or LLM rewrites) before retrieval.
- Add persistent BM25 cache loading in pipeline startup to avoid reindexing each run.
- Add observability metrics (timings per stage, hit overlap between sparse/dense).
- Add batch query mode for evaluation datasets, beyond interactive REPL mode.
