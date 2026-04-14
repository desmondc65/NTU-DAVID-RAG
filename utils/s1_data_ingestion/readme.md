# utils/s1_data_ingestion

This directory contains Stage-1 ingestion utilities for turning raw source material
into structured artifacts that downstream embedding and RAG stages can index.

The code here handles two major ingestion modalities:

1. **Fortran code digestion** into structured JSON summaries of key routines.
2. **PDF extraction and multimodal enrichment** (images/equations/tables) via MinerU
	plus a local LLM.

---

## Directory contents

### `fortran_code_digest.py`

#### High-level purpose
Builds a RAG-ready JSON digest from long Fortran source code by:

1. Splitting large source files into overlapping chunks.
2. Asking a local LLM to extract important routines and pseudocode.
3. Merging chunk-level outputs into one `key_functions` list.
4. Optionally deduplicating routines and adding a per-function search index summary.

This module is designed for very large legacy codebases where full-context analysis
in a single LLM request is not reliable.

#### Imports and dependencies
- Standard library:
  - `json`, `re`, `logging`
  - `pathlib.Path`
  - `typing.List`, `typing.Optional`, `typing.Union`
- Third-party:
  - `pydantic.BaseModel`, `pydantic.Field`
- Internal:
  - `utils.llm_clients.local_llm.LocalLLMClient`

#### Data schemas

1. `RAGFortranFunction` (`BaseModel`)
	- `function_name: str`
	- `purpose: str`
	- `pseudocode: str`
	- `dependencies: List[str]` (default empty list)
	- `key_variables: List[str]` (default empty list)

	This is the expected shape for each extracted routine.

2. `RAGFortranDigest` (`BaseModel`)
	- `key_functions: List[RAGFortranFunction]`

	Wrapper schema for the final output document.

Note: these schemas are defined and useful for validation/documentation, but the
current runtime flow writes plain `dict` objects from JSON parsing rather than
instantiating these models explicitly.

#### Function: `digest_fortran_code(...) -> dict`

Signature:

```python
digest_fortran_code(
	 code_content: str,
	 output_json_path: str,
	 model_name: str = "qwen2.5-vl-72b-instruct",
	 base_url: str = "http://localhost:8000/v1",
	 api_key: str = "local-dev-key",
) -> dict
```

Behavior details:

1. Initializes `LocalLLMClient` with provided model connection settings.
2. Builds a strict system prompt instructing the model to output only JSON.
3. Splits `code_content` into overlapping chunks:
	- `max_chunk_chars = 80000`
	- `overlap_chars = 15000`
	- overlap is line-based backtracking from previous chunk.
4. For each chunk:
	- sends a chunk-level prompt in a fenced `fortran` block,
	- requests text output (`response_mime_type="text/plain"`),
	- attempts robust JSON extraction:
	  - first tries fenced JSON regex extraction,
	  - falls back to trimming raw triple-backtick wrappers.
	- parses JSON and normalizes accepted shapes:
	  - list => extend `all_digests`,
	  - dict with `key_functions` => extend from that field,
	  - plain dict => append as one item.
	- if parsing fails for a chunk, logs error and continues.
5. Writes merged output to `output_json_path` as:

```json
{
  "key_functions": [ ... ]
}
```

6. Returns the same dictionary in memory.

Error handling:
- Chunk JSON parse failures are non-fatal (skip chunk, continue).
- Unexpected failures in outer block are logged and re-raised.

Operational implications:
- Overlap reduces boundary loss where routine definitions span chunks.
- No final deduplication occurs here, so duplicate functions can remain.
- `ensure_ascii=False` preserves non-ASCII text in output JSON.

#### Function: `summarize_fortran_digest(...)`

Signature:

```python
summarize_fortran_digest(
	 json_path: Union[str, Path],
	 model_name: str = "qwen2.5-vl-72b-instruct",
	 base_url: str = "http://localhost:8000/v1",
	 api_key: str = "local-dev-key",
)
```

Behavior details:

1. Loads existing digest JSON from disk.
2. Deduplicates functions by normalized name:
	- key uses `function_name` fallback `name`,
	- normalized as `.strip().lower()`,
	- first occurrence wins.
3. Replaces `data["key_functions"]` with deduplicated list.
4. Lazily initializes `LocalLLMClient` when first summary is needed.
5. For each function lacking `summary_index`:
	- gathers `function_name`, `purpose`, `pseudocode`, `key_variables`,
	- converts pseudocode list to newline string if needed,
	- asks LLM for compact indexing summary with 4 sections:
	  - Core Capability
	  - Algorithms/Logic
	  - Key Variables
	  - Keywords
	- writes response into `func["summary_index"]`.
6. Intermittently saves every 5 processed functions.
7. Removes old top-level `summary_index` if present.
8. Final save only if modifications occurred.

Error handling:
- Missing JSON path raises `FileNotFoundError`.
- LLM init failure logs error and stops summary loop.
- Per-function generation failures are logged and skipped.

#### Script mode (`if __name__ == "__main__"`)

Contains in-file demo code:

1. Creates a toy Fortran snippet (includes duplicate subroutine intentionally).
2. Calls `digest_fortran_code(...)` writing to `output_test/fortran_digest.json`.
3. Calls `summarize_fortran_digest(...)` on that output.

This section is mainly for manual sanity testing.

#### Design strengths
- Works on long code via chunk + overlap strategy.
- Tolerates imperfect LLM wrapper formatting.
- Supports incremental enrichment (`summary_index`) without rewriting all entries.

#### Practical caveats
- Duplicate detection uses only function name; overload/context differences are ignored.
- Chunking is character/line based, not syntax aware (possible mid-block splits).
- No strict Pydantic validation before write, despite available schemas.

---

### `pdf_extract.py`

#### High-level purpose
Provides PDF ingestion and multimodal enrichment for MinerU output.

Core responsibilities:

1. Run MinerU parse and locate expected Markdown output.
2. Traverse MinerU content-list JSON.
3. For `image`, `equation`, and `table` items:
	- collect nearby textual context,
	- load associated cropped image,
	- ask local multimodal LLM for concise retrieval-oriented description,
	- write `description` back into the JSON incrementally.

#### Path/bootstrap logic at import time

The module modifies `sys.path` to ensure imports resolve in mixed project layouts:

1. Computes current file directory.
2. Prepends MinerU path:
	- `CURRENT_DIR.parent / "data_preprocess" / "MinerU"`
3. Prepends project root for `utils.*` imports:
	- `CURRENT_DIR.parent.parent`

This is functional but environment-sensitive; packaging the project would be cleaner
than runtime path mutation.

#### Imports and dependencies
- Standard library:
  - `json`, `base64`, `sys`, `pathlib.Path`
- External/internal tools:
  - `mineru.cli.common.do_parse`, `mineru.cli.common.read_fn`
  - `utils.llm_clients.local_llm.LocalLLMClient`

#### Helper: `_parse_subdir(backend: str, method: str) -> str`

Maps MinerU backend/method to expected subdirectory names:

- `pipeline` => method name
- `hybrid-*` => `hybrid_<method>`
- `vlm-*` => `vlm`
- default => method name

Used to compute where MinerU should have written output markdown.

#### Function: `extract_pdf_mineru(...) -> Path`

Signature:

```python
extract_pdf_mineru(
	 input_path: str | Path,
	 output_dir: str | Path,
	 backend: str = "hybrid-auto-engine",
	 method: str = "auto",
	 lang: str = "en",
	 url: str | None = None,
	 start: int = 0,
	 end: int | None = None,
) -> Path
```

Behavior details:

1. Normalizes and creates output directory.
2. Calls `do_parse(...)` with a single PDF provided as bytes via `read_fn`.
3. Computes expected markdown location:

```text
<output_dir>/<pdf_stem>/<parsed_subdir>/<pdf_stem>.md
```

4. Raises `RuntimeError` if expected markdown is missing.
5. Returns markdown path on success.

#### Function: `describe_mineru_images(json_path)`

Purpose:
- Enriches MinerU JSON entries where `item["type"] == "image"`.

Detailed flow:

1. Loads JSON from `json_path`.
2. Supports two formats:
	- wrapped: `{"items": [...]}`
	- direct list: `[...]`
3. Initializes `LocalLLMClient()` with defaults.
4. Iterates entries:
	- skip if `description` already exists,
	- require `img_path`,
	- resolve image path relative to JSON directory,
	- gather optional text context from immediate previous/next text items,
	- base64-encode image,
	- build multimodal prompt with text + `image_url` data URI,
	- call model and save response to `item["description"]`.
5. Writes file incrementally after each successful description.

Prompt intent:
- extraction style optimized for retrieval indexing:
  - subject/type,
  - labels/legends,
  - key findings,
  - keywords.

#### Function: `describe_mineru_equations(json_path)`

Purpose:
- Same pattern as images, but for `type == "equation"`.

Additional inputs:
- includes equation text (`item.get("text", "")`) in prompt as `LaTeX` context.

Prompt intent:
- capture concept, intuition, variable definitions, and search keywords.

#### Function: `describe_mineru_tables(json_path)`

Purpose:
- Same enrichment pattern for `type == "table"`.

Additional table metadata extraction:
- `table_caption` list -> newline-joined text
- `table_footnote` list -> newline-joined text
- `table_body` raw content (often HTML-like)

Prompt intent:
- summarize subject, reported metrics, key insight, and keywords.

#### Shared behavior across describe_* functions

- Skip already-described items (idempotent-friendly).
- Continue on per-item errors (non-fatal processing).
- Save progress incrementally to reduce data loss risk.
- Use `ensure_ascii=False` when writing updated JSON.

#### Script mode (`main()`)

Hard-coded test path:

```text
/home3/davidlcs/Econ-Rag/NTU-DAVID-RAG/tests/output_pdf_extract/Manuscript/auto/Manuscript_content_list.json
```

Execution order:
1. `describe_mineru_images(...)`
2. `describe_mineru_equations(...)`
3. `describe_mineru_tables(...)`

This is suitable for manual testing but should be parameterized for production use.

#### Design strengths
- Works with both wrapped and list JSON structures.
- Uses immediate textual neighbors for better contextual descriptions.
- Incremental persistence makes long runs safer.

#### Practical caveats
- Uses `print` instead of module logger (less controllable in larger systems).
- Repeats similar logic across 3 functions (candidate for refactoring).
- Assumes image MIME type `image/jpeg` for all assets.
- Relies on runtime path hacks (`sys.path`) rather than package configuration.

---

### `readme.md`

This file documents the contents and behavior of the directory.
It is intended to be the quick technical orientation point for Stage-1 ingestion.

---

### `__pycache__/`

Python bytecode cache generated at runtime.

- Not source of truth.
- Safe to ignore for code understanding.
- Usually excluded from version control.

---

## End-to-end relationship between files

1. `pdf_extract.py` handles document ingestion from PDFs and enriches extracted
	non-text objects for retrieval.
2. `fortran_code_digest.py` handles source-code ingestion from Fortran programs and
	converts them to semantically searchable metadata.
3. Outputs from both modules are JSON-centric and designed to feed later indexing/
	embedding stages in the broader RAG pipeline.

---

## Typical outputs produced by this directory

- Fortran digest JSON:
  - top-level `key_functions`
  - each item has function metadata + optional `summary_index`
- MinerU-enriched content list JSON:
  - existing MinerU items plus `description` fields for images/equations/tables
- MinerU markdown extraction output:
  - parsed markdown per PDF in backend/method-specific subfolders

---

## Recommendations for future maintenance

1. Replace hard-coded defaults/paths with explicit config or CLI args.
2. Introduce unified logging in `pdf_extract.py`.
3. Refactor repeated `describe_*` logic into a generic helper.
4. Validate LLM outputs against explicit schemas before writing.
5. Add unit tests for:
	- chunk boundary behavior,
	- JSON wrapper handling,
	- idempotent re-runs,
	- malformed MinerU items.
