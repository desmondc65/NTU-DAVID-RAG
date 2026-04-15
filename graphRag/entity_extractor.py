"""
LLM-based entity and relationship extraction from text chunks.

Each chunk is passed to the LLM with a schema-constrained prompt that
returns:

- **entities**: ``{name, type, description}`` where ``type`` is one of
  ``model, concept, method, dataset, variable, theorem, author, paper``.
- **relationships**: ``{source, target, type, description, strength}``
  where ``type`` is ``uses, extends, compares, applies_to, causes,
  contains, measures, authored``.

The extractor is intentionally tolerant: malformed JSON, missing fields,
and trivially short entity names are silently dropped.  Repeated entities
across chunks are reconciled upstream in :mod:`graph_builder`.
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional

from utils.llm_clients.local_llm import LocalLLMClient

logger = logging.getLogger(__name__)


ENTITY_TYPES = (
    "model",
    "concept",
    "method",
    "dataset",
    "variable",
    "theorem",
    "author",
    "paper",
)

RELATIONSHIP_TYPES = (
    "uses",
    "extends",
    "compares",
    "applies_to",
    "causes",
    "contains",
    "measures",
    "authored",
    "mentions",
)


_SYSTEM_PROMPT = (
    "You are an information extraction system for academic economics "
    "papers. Extract named entities (mathematical models, economic "
    "concepts, numerical methods, datasets, key variables, theorems, "
    "authors, papers) and the relationships between them from the given "
    "chunk. Use canonical economics terminology. Return ONLY valid JSON. "
    "Entity names must be noun phrases, NOT sentences. Skip entities whose "
    "name is generic ('the model', 'a variable') or longer than 80 chars. "
    "If the chunk contains no substantive content, return empty lists."
)


_USER_TEMPLATE = (
    "Chunk from paper \"{paper_title}\" — section \"{section}\":\n"
    "---\n{text}\n---\n\n"
    "Return a JSON object with keys:\n"
    "- \"entities\": list of {{\"name\": str, \"type\": one of {etypes}, \"description\": str}}\n"
    "- \"relationships\": list of {{\"source\": str, \"target\": str, \"type\": one of {rtypes}, "
    "\"description\": str, \"strength\": int 1-10}}\n"
    "Rules:\n"
    "- Entity \"name\" must be the canonical short form (e.g. \"overlapping-generations model\", "
    "not \"an overlapping-generations model of household saving\").\n"
    "- Include relationships only between entities you extracted in the same call.\n"
    "- Extract at most 12 entities and 15 relationships per chunk.\n"
    "- Focus on ECONOMICS-SPECIFIC entities. Skip programming language names, file "
    "paths, boilerplate words, and citations to author names in bibliographic form.\n"
    "Return ONLY the JSON object."
)


@dataclass
class ExtractedEntity:
    name: str
    type: str
    description: str
    chunk_id: str
    paper_title: str


@dataclass
class ExtractedRelationship:
    source: str
    target: str
    type: str
    description: str
    strength: int
    chunk_id: str
    paper_title: str


@dataclass
class ChunkExtraction:
    chunk_id: str
    paper_title: str
    entities: List[ExtractedEntity] = field(default_factory=list)
    relationships: List[ExtractedRelationship] = field(default_factory=list)


def _clean_name(name: Any) -> Optional[str]:
    if not isinstance(name, str):
        return None
    n = name.strip()
    if not n or len(n) > 80:
        return None
    # Strip trailing periods but keep internal punctuation.
    n = n.rstrip(" .;:,")
    if len(n) < 2:
        return None
    return n


def _normalise_entity(obj: Any) -> Optional[Dict[str, str]]:
    if not isinstance(obj, dict):
        return None
    name = _clean_name(obj.get("name"))
    if not name:
        return None
    etype = str(obj.get("type", "")).strip().lower()
    if etype not in ENTITY_TYPES:
        etype = "concept"
    desc = str(obj.get("description", "")).strip()[:400]
    return {"name": name, "type": etype, "description": desc}


def _normalise_relationship(obj: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(obj, dict):
        return None
    src = _clean_name(obj.get("source"))
    tgt = _clean_name(obj.get("target"))
    if not src or not tgt or src == tgt:
        return None
    rtype = str(obj.get("type", "")).strip().lower()
    if rtype not in RELATIONSHIP_TYPES:
        rtype = "mentions"
    desc = str(obj.get("description", "")).strip()[:300]
    strength = obj.get("strength", 5)
    try:
        strength = int(strength)
    except (TypeError, ValueError):
        strength = 5
    strength = max(1, min(10, strength))
    return {
        "source": src,
        "target": tgt,
        "type": rtype,
        "description": desc,
        "strength": strength,
    }


class EntityExtractor:
    """Runs entity + relationship extraction on a stream of chunks."""

    def __init__(
        self,
        llm_client: Optional[LocalLLMClient] = None,
        max_chunk_chars: int = 6000,
        temperature: float = 0.1,
    ) -> None:
        self.llm = llm_client or LocalLLMClient()
        self.max_chunk_chars = max_chunk_chars
        self.temperature = temperature

    def extract_chunk(
        self,
        chunk_id: str,
        text: str,
        paper_title: str = "",
        section: str = "",
    ) -> ChunkExtraction:
        text = (text or "").strip()
        if not text:
            return ChunkExtraction(chunk_id=chunk_id, paper_title=paper_title)
        if len(text) > self.max_chunk_chars:
            text = text[: self.max_chunk_chars]

        user_prompt = _USER_TEMPLATE.format(
            paper_title=paper_title or "(unknown)",
            section=section or "(unknown)",
            text=text,
            etypes=", ".join(f'"{t}"' for t in ENTITY_TYPES),
            rtypes=", ".join(f'"{t}"' for t in RELATIONSHIP_TYPES),
        )

        try:
            raw = self.llm.generate_response(
                user_prompt=user_prompt,
                system_prompt=_SYSTEM_PROMPT,
                response_mime_type="application/json",
                max_tokens=2048,
                temperature=self.temperature,
            )
        except Exception as exc:
            logger.warning("Extraction failed on chunk %s: %s", chunk_id, exc)
            return ChunkExtraction(chunk_id=chunk_id, paper_title=paper_title)

        if not isinstance(raw, dict):
            try:
                raw = json.loads(raw) if isinstance(raw, str) else {}
            except Exception:
                raw = {}

        extraction = ChunkExtraction(chunk_id=chunk_id, paper_title=paper_title)
        for e in (raw.get("entities") or []):
            norm = _normalise_entity(e)
            if not norm:
                continue
            extraction.entities.append(
                ExtractedEntity(
                    name=norm["name"],
                    type=norm["type"],
                    description=norm["description"],
                    chunk_id=chunk_id,
                    paper_title=paper_title,
                )
            )

        extracted_names = {e.name.lower() for e in extraction.entities}
        for r in (raw.get("relationships") or []):
            norm = _normalise_relationship(r)
            if not norm:
                continue
            # Drop relationships referencing entities not in this chunk's
            # extraction — they add noise we cannot ground.
            if norm["source"].lower() not in extracted_names:
                continue
            if norm["target"].lower() not in extracted_names:
                continue
            extraction.relationships.append(
                ExtractedRelationship(
                    source=norm["source"],
                    target=norm["target"],
                    type=norm["type"],
                    description=norm["description"],
                    strength=norm["strength"],
                    chunk_id=chunk_id,
                    paper_title=paper_title,
                )
            )

        return extraction

    def extract_batch(
        self,
        chunks: Iterable[Dict[str, Any]],
    ) -> List[ChunkExtraction]:
        """
        Extract from a list of dicts with keys ``id, text, metadata``.
        Metadata is used to pass ``paper_title`` and ``section``.
        """
        results: List[ChunkExtraction] = []
        for c in chunks:
            meta = c.get("metadata", {}) or {}
            results.append(
                self.extract_chunk(
                    chunk_id=str(c.get("id") or c.get("chunk_id") or ""),
                    text=c.get("text") or c.get("document") or "",
                    paper_title=meta.get("paper_title", ""),
                    section=meta.get("section", ""),
                )
            )
        return results
