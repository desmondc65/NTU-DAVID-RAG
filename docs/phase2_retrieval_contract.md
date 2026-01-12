# Retrieval Contract

---

This document defines the formal interface between **Phase 2 (Embedding and Storage)** and **Phase 3 (Hybrid Retrieval and Generation)**.

Phase 2 guarantees the structure, metadata, and retrieval properties described below.

---

## 1. Scope and Responsibility

### 1.1 Phase 2 owns

- Embedding of parsed artifacts (text, code summaries, images)
- Metadata definition and population
- Vector storage and indexing
- Retrieval-ready representations

### 1.2 Phase 2 does not own

- PDF parsing or OCR
- Prompt engineering
- Reranking models
- LLM-based answer generation

---

## 2. Input Artifacts

Phase 2 consumes normalized artifacts produced by Phase 1.

### 2.1 Artifact types

### Text chunks

- **Source:** Markdown output
- **Chunk size:** ~500 tokens
- **Content:** Paragraph-level scientific text

### Code blocks

- **Source:** Parsed code sections
- **Representation:** LLM-generated summaries
- **Raw code:** Stored separately and referenced by ID

### Images

- **Source:** Figures, charts, diagrams
- **Representation:** Image + generated caption
- **Raw image:** Stored separately and referenced by ID

---

## 3. Embedding Strategy

### 3.1 Embedding granularity

- One embedding per text chunk
- One embedding per code summary
- One embedding per image caption
- One image embedding per image (CLIP-style)

Each document is represented by multiple vectors.

### 3.2 Embedding models

- **Text:** text-embedding-3 or equivalent
- **Image:** CLIP-compatible image encoder
- **Code:** Text embedding over summarized code

Embedding dimensionality is consistent per modality.

---

## 4. Metadata Schema

Metadata is mandatory and filterable.

### 4.1 Required metadata fields

```json
{
  "doc_id": "string",
  "chunk_id": "string",
  "chunk_type": "text | code | image",
  "section": "string",
  "year": "int",
  "authors": ["string"],
  "affiliation": ["string"],
  "source_type": "paper | thesis",
  "ref_id": "string"
}
```

### 4.2 Metadata semantics

- **doc_id:** Unique document identifier
- **chunk_id:** Unique identifier for the chunk
- **chunk_type:** Used for modality-aware retrieval
- **section:** Logical document section (e.g., Method, Results)
- **year, authors, affiliation:** Used for metadata filtering
- **ref_id:** Points to raw content in the document store

---

## 5. Vector Storage and Indexing

### 5.1 Storage system

- **Vector database:** Qdrant or Weaviate
- Stores: embedding vectors + metadata
- Raw content stored separately in document store

### 5.2 Indexing strategy

- Dense vector index per modality
- Metadata fields indexed for filtering
- Support for hybrid retrieval (dense + keyword)

---

## 6. Query-Time Retrieval Guarantees

Phase 2 guarantees the following at query time:

- Metadata filtering by year, author, affiliation
- Retrieval of top-K semantically relevant chunks
- Stable reference IDs to fetch raw text, code, and images
- Modality-aware chunk identification

Phase 2 does not guarantee:

- Answer correctness
- Ranking optimality after reranking
- Prompt assembly quality

---

## 7. Output Contract to Phase 3

### 7.1 Retrieval output format

```json
{
  "chunk_id": "string",
  "chunk_type": "text | code | image",
  "score": "float",
  "metadata": { "...": "..." },
  "ref_id": "string"
}
```

### 7.2 Phase 3 assumptions

Phase 3 may assume:

- Retrieved chunks are semantically relevant
- Metadata fields are present and correct
- Raw content is retrievable using ref_id

---

## 8. Known Limitations

- Embeddings may not fully capture mathematical semantics
- Image captions may omit fine-grained visual details
- Metadata extraction may introduce noise

---

## 9. Future Extensions

- Adaptive chunking based on query intent
- Cross-modal reranking
- Learned metadata tagging
- Multimodal joint embeddings

---

## 10. Versioning

- **Contract version:** v1.0
- **Last updated:** 2026-01-12
