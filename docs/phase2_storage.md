# Phase 2 Mission (Scope):

Phase 2 converts parsed scientific artifacts, text, code summaries, and images into retrieval-ready embeddings with mandatory metadata and storage guarantees, enabling Phase 3 to perform metadata-filtered hybrid retrieval reliably.
---
## 0. Executive Summary

(place holder for now)

- Problem Phase 2 is solving
- Key decisions made
- Open questions and risks
- How Phase 2 enables Phase 3 (retrieval and generation)

---

## 1. Problem Definition and Constraints

**Decision questions**

- What are the primary query types we must support (lookup, comparison, explanation), and what quality metric matters most (recall vs precision)?
- What latency and cost constraints are hard requirements vs “nice to have”?

### 1.1 Target Use Case

- Document types (papers, PDFs, figures, equations, tables)
- Query types (fact lookup, comparison, explanation)
- Expected scale (number of documents, chunks)

### 1.2 System Constraints

- Latency targets
- Cost constraints
- Update frequency (static corpus vs incremental ingestion)

---

## 2. Document Chunking Strategy

**Decision questions**

- What is the embedding unit for scientific documents: fixed-size, sliding window, or structure-aware (sections, figures, equations)?
- What chunk size and overlap best balance recall, context preservation, and cost?

### 2.1 Chunking Objectives

- Recall vs precision tradeoff
- Context preservation
- Compatibility with scientific documents

### 2.2 Chunking Approaches Surveyed

- Fixed-size chunking
- Sliding window chunking
- Structure-aware chunking (sections, figures, equations)
- Hierarchical chunking (document → section → paragraph)

### 2.3 Comparative Analysis

| Approach | Pros | Cons | Best Use Case |
| --- | --- | --- | --- |
|  |  |  |  |

### 2.4 Final Chunking Decision

- Chosen strategy
- Parameter choices (chunk size, overlap)
- Rejected alternatives and rationale
- Citations

---

## 3. Embedding Models

**Decision questions**

- Should we use general-purpose embeddings or scientific-domain embeddings, and what evidence supports the choice?
- Do we need multi-vector / modality-specific embeddings (text + image + code), and how will we combine results?

### 3.1 Embedding Requirements

- Domain specificity (scientific language)
- Speed vs quality tradeoff
- Vector dimensionality constraints

### 3.2 Models Surveyed

- General-purpose dense embeddings
- Scientific or academic embeddings
- Multi-vector or late-interaction models

### 3.3 Benchmark Evidence from Literature

- Retrieval metrics (Recall@k, MRR)
- Domain-specific performance
- Compute and memory cost

### 3.4 Final Embedding Model Choice

- Primary embedding model
- Backup or fallback model
- Rejected alternatives and rationale
- Citations

---

## 4. Metadata and Labeling Design

**Decision questions**

- What metadata fields must be guaranteed for Phase 3 filtering and traceability (year, authors, affiliation, section, chunk_type, ref_id)?
- Which fields can be auto-extracted reliably vs require model-assisted labeling or manual review?

### 4.1 Why Metadata Matters in RAG

Prior work in information retrieval and retrieval-augmented generation shows that
metadata-aware retrieval improves both precision and controllability, especially
for long or heterogeneous document collections. Rather than relying solely on dense
semantic similarity, structured metadata enables filtering and constraint-based
retrieval that reduces irrelevant candidates before vector search.

Studies on structured and section-aware retrieval demonstrate that preserving
document structure, such as section boundaries and content types, helps maintain
semantic coherence when retrieving from long scientific documents. This is
particularly important for technical papers, where equations, methods, and results
serve distinct roles.

In addition, provenance-aware retrieval has been shown to improve interpretability
and trust in generation systems by explicitly linking retrieved content to its
original source. Providing stable references and citations allows downstream
generation modules to attribute information correctly and supports debugging and
evaluation.

Motivated by these findings, we adopt a metadata-aware design that explicitly encodes
structural, semantic, and provenance information for each embedded chunk, enabling
filterable and explainable retrieval in Phase 3.

### 4.2 Metadata Taxonomy

### Structural Metadata

- document_id
- section
- page
- figure or table reference

### Semantic Metadata

- topic
- method
- dataset
- assumptions or limitations

### Provenance Metadata

- authors
- publication year
- citation
- source PDF

### 4.3 Labeling Strategies

- Automatic extraction
- Rule-based heuristics
- Model-assisted labeling
- Manual labeling (if applicable)

### 4.4 Proposed Metadata Schema

```json
{
  "doc_id": "",
  "section": "",
  "chunk_type": "",
  "topics": [],
  "method": "",
  "year": "",
  "citation": "",
  "chunk_id" : "",
  "chunk_type": "",
  "ref_id": ""
}
```

### Justifications for each Metadata Field

doc_id

Purpose: Document-level identity and grouping
Justification:
Links multiple chunks (text, code, images) back to the same source document. Required for document-level aggregation, deduplication, and provenance tracking in Phase 3.

---

chunk_id

Purpose: Chunk-level identity
Justification:
Each embedded unit must be uniquely identifiable for retrieval, ranking, caching, and debugging. Enables stable references when Phase 3 selects, reorders, or drops chunks.

---

chunk_type

Purpose: Modality awareness
Justification:
Distinguishes between text, code, and image chunks at query time. Allows Phase 3 to apply modality-specific handling, weighting, or prompt formatting.

---

section

Purpose: Structural context
Justification:
Preserves document structure (e.g., Introduction, Method, Results). Improves retrieval precision by enabling section-based filtering and helps Phase 3 assemble coherent context blocks.

---

topics

Purpose: Semantic filtering and diversification
Justification:
Enables coarse-grained topic filtering or diversification during retrieval. Useful for reducing irrelevant chunks when queries target specific subdomains or methods.

---

method

Purpose: Research-method awareness
Justification:
Explicitly captures the main methodological approach (e.g., RAG, contrastive learning, diffusion). Supports method-based filtering and comparison queries common in scientific QA.

---

year

Purpose: Temporal filtering
Justification:
Allows Phase 3 to prioritize recent work or restrict retrieval to a time window. Critical for scientific domains where recency affects relevance.

---

citation

Purpose: Traceability and attribution
Justification:
Provides a human-readable reference for retrieved chunks. Enables citation generation, debugging, and result explainability in downstream outputs.

---

ref_id

Purpose: Raw content lookup
Justification:
Links embeddings back to the original stored artifact (text block, code snippet, image). Required so Phase 3 can fetch full content for prompt assembly.
---

## 5. Vector Database and Indexing Strategy

**Decision questions**

- Do we use dense-only retrieval or hybrid retrieval (dense + keyword), and why?
- Should metadata filtering happen before vector search, after vector search, or both?

### 5.1 Storage Requirements

- Expected corpus scale (number of documents and chunks)
- Read vs write frequency
- Support for metadata-based filtering
- Latency requirements for interactive querying

### 5.2 Indexing Options Surveyed

- Dense-only vector indexing
- Hybrid dense and sparse indexing
- Metadata-aware indexing and filtering
- Support for reranking or late interaction

### 5.3 Query-Time Retrieval Pipeline

- Metadata pre-filtering
- Vector similarity search
- Optional reranking stage
- Top-k selection strategy

### 5.4 Final Storage and Retrieval Design

- Chosen vector database and rationale
- Index configuration (dimensions, distance metric)
- Metadata handling strategy
- Expected performance characteristics
- Citations

---

## 6. End-to-End Phase 2 Architecture

**Decision questions**

- What exact output schema does Phase 2 return to Phase 3 (fields, types, required guarantees)?
- What failure modes must Phase 2 detect or tolerate (missing metadata, broken refs, empty results)?

### 6.1 Data Flow

- PDF ingestion
- Document parsing and normalization
- Chunk generation
- Embedding computation
- Vector storage with metadata

### 6.2 Interface with Phase 3

- Expected retrieval output format
- Guarantees on chunk granularity
- Required metadata fields for generation
- Assumptions made by the Phase 3 module

---

## 7. Open Problems and Future Improvements

**Decision questions**

- What are the top 3 risks that could block Phase 3 quality (chunking errors, embedding mismatch, metadata noise)?
- What improvements are feasible without changing Phase 1 or Phase 3 interfaces?
- Known limitations of the current design
- Embedding model scalability concerns
- Metadata coverage and labeling noise
- Potential future improvements (adaptive chunking, reranking, multimodal embeddings)

---

## 8. Decision Log (Appendix A)

### Chunking Decision

- Decision:
- Rationale:
- Rejected Alternatives:
- Citations:

### Embedding Model Decision

- Decision:
- Rationale:
- Rejected Alternatives:
- Citations:

### Metadata and Labeling Decision

- Decision:
- Rationale:
- Rejected Alternatives:
- Citations:

### Vector Database Decision

- Decision:
- Rationale:
- Rejected Alternatives:
- Citations:

---

## 9. Paper Review Table (Appendix B)

| Paper Title | Area | Key Contribution | Used for Decision |
| :--- | :--- | :--- | :--- |
| **Metadata-Driven RAG for Financial QA** (Reuven et al., 2025) | Metadata & Filtering | Proposes "Contextual Chunks" (enriching text with parent metadata) and pre-retrieval filtering to reduce noise in dense financial docs. | Validates the **"Filter-then-Search"** architecture and the schema design for `year`, `author`, and `topic` tags. |
| **RAPTOR: Recursive Abstractive Processing** (Sarthi et al., 2024) | Hierarchical Retrieval | Introduces a tree-based retrieval system where leaf nodes (details) are summarized into parent nodes (concepts) for multi-level search. | Justifies the **"Parent Document Retriever"** pattern: search small chunks/summaries, but retrieve full context for the LLM. |
| **Attributed Question Answering** (Bohnet et al., 2023) | Provenance & Citation | Defines "Attributed QA" where the system must generate an answer *and* a pointer to the specific evidence span, or refuse to answer. | Informing the **Phase 3 Generation** requirement: the LLM must strictly cite the `Ref ID` of the chunks provided by Phase 2. |
---

## 10. References

- Full bibliography (BibTeX or numbered references)
