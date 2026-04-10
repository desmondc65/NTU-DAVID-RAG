"""
Structure-aware Fortran code digestion for RAG indexing.

Instead of naive character-based chunking, this module:
1. Parses the Fortran source into logical units (PROGRAM preamble,
   SUBROUTINE, FUNCTION, MODULE) using regex on explicit Fortran markers.
2. Extracts a call graph from CALL / USE statements (no LLM needed).
3. Sends each logical unit to the LLM individually for a focused summary.
4. Produces one global "architecture" document from the file header,
   call graph, and all function signatures.

Designed for large (10k+ LOC) economics Fortran codebases.
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

from utils.llm_clients.local_llm import LocalLLMClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ── Structural parser ────────────────────────────────────────────────────

# Matches: SUBROUTINE name(...), FUNCTION name(...), PROGRAM name, MODULE name
# Handles free-form and fixed-form, case-insensitive.
_UNIT_START = re.compile(
    r"^\s*(?:(?:RECURSIVE|PURE|ELEMENTAL|INTEGER|REAL|DOUBLE\s+PRECISION|"
    r"COMPLEX|CHARACTER|LOGICAL)\s+)*"
    r"(PROGRAM|SUBROUTINE|FUNCTION|MODULE)\s+"
    r"(\w+)",
    re.IGNORECASE | re.MULTILINE,
)

# Matches: END SUBROUTINE [name], END FUNCTION [name], etc.
# Allows optional leading statement labels (e.g., "100 END FUNCTION")
# and trailing inline comments (! ...)
_UNIT_END = re.compile(
    r"^\s*(?:\d+\s+)?END\s+(PROGRAM|SUBROUTINE|FUNCTION|MODULE)(?:\s+(\w+))?(?:\s*!.*)?\s*$",
    re.IGNORECASE | re.MULTILINE,
)

# Matches CALL statements: CALL subroutine_name(...)
_CALL_RE = re.compile(r"\bCALL\s+(\w+)", re.IGNORECASE)

# Matches USE statements: USE module_name
_USE_RE = re.compile(r"^\s*USE\s+(\w+)", re.IGNORECASE | re.MULTILINE)

# Matches CONTAINS keyword (separates declarations from internal procedures)
_CONTAINS_RE = re.compile(r"^\s*CONTAINS\s*$", re.IGNORECASE | re.MULTILINE)


@dataclass
class FortranUnit:
    """A parsed logical unit from Fortran source."""
    kind: str            # "program_preamble", "subroutine", "function", "module"
    name: str
    source: str          # full source text of this unit
    start_line: int
    end_line: int
    signature: str = ""  # first line(s) with args
    calls: List[str] = field(default_factory=list)
    uses: List[str] = field(default_factory=list)


def parse_fortran_units(code: str) -> Tuple[List[FortranUnit], str]:
    """
    Parse Fortran source into logical units.

    Returns (units, header_comments) where header_comments is any
    leading comment block before the first executable statement.
    """
    lines = code.splitlines(keepends=True)
    numbered = list(enumerate(lines, 1))  # (line_no, text)

    # Collect all unit start/end positions
    starts = []  # (line_idx_0based, kind, name)
    ends = []    # (line_idx_0based, kind, name_or_None)

    for idx, line in enumerate(lines):
        m = _UNIT_START.match(line)
        if m:
            starts.append((idx, m.group(1).upper(), m.group(2)))
        m = _UNIT_END.match(line)
        if m:
            ends.append((idx, m.group(1).upper(), (m.group(2) or "").upper()))

    if not starts:
        # No recognizable units — treat entire file as one unit
        unit = FortranUnit(
            kind="program",
            name="UNKNOWN",
            source=code,
            start_line=1,
            end_line=len(lines),
        )
        unit.calls = _extract_calls(code)
        unit.uses = _extract_uses(code)
        return [unit], ""

    # Extract header comments: everything before the first unit start
    first_start_idx = starts[0][0]
    header_lines = lines[:first_start_idx]
    header_comments = "".join(header_lines).strip()

    # For each start, find its matching end
    units: List[FortranUnit] = []

    # The first unit might be a PROGRAM with a CONTAINS section.
    # After CONTAINS, inner subroutines/functions are separate units.
    # Strategy: process starts in order, match each to the nearest valid end.

    used_ends = set()

    for si, (s_idx, s_kind, s_name) in enumerate(starts):
        # If this start is inside a range already claimed by a PROGRAM's
        # preamble, skip (it will be handled as an inner unit after CONTAINS).
        # Actually, inner units after CONTAINS have their own START/END pairs,
        # so they'll be matched naturally.

        # Find the matching END for this unit
        best_end_idx = None
        for ei, (e_idx, e_kind, e_name) in enumerate(ends):
            if ei in used_ends:
                continue
            if e_idx <= s_idx:
                continue
            if e_kind != s_kind:
                continue
            # Name match (if END has a name, it must match)
            if e_name and e_name != s_name.upper():
                continue
            # For PROGRAM units, only match the END PROGRAM that comes after
            # all inner units (i.e., the last possible matching end)
            if s_kind == "PROGRAM":
                # Find the outermost END PROGRAM
                candidate = ei
                for ei2, (e_idx2, e_kind2, e_name2) in enumerate(ends):
                    if ei2 in used_ends or e_idx2 <= s_idx or e_kind2 != "PROGRAM":
                        continue
                    if e_name2 and e_name2 != s_name.upper():
                        continue
                    candidate = ei2
                best_end_idx = candidate
                break
            else:
                best_end_idx = ei
                break

        if best_end_idx is not None:
            e_idx = ends[best_end_idx][0]
            used_ends.add(best_end_idx)
            unit_source = "".join(lines[s_idx:e_idx + 1])
            unit_end_line = e_idx + 1
        else:
            # No matching END found — take until next start or EOF
            next_start = None
            for s2_idx, _, _ in starts[si + 1:]:
                if s2_idx > s_idx:
                    next_start = s2_idx
                    break
            if next_start:
                unit_source = "".join(lines[s_idx:next_start])
                unit_end_line = next_start
            else:
                unit_source = "".join(lines[s_idx:])
                unit_end_line = len(lines)

        kind = s_kind.lower()

        # For PROGRAM blocks, split at CONTAINS into preamble + inner units
        if kind == "program":
            contains_match = _CONTAINS_RE.search(unit_source)
            if contains_match:
                preamble_source = unit_source[:contains_match.start()]
                kind = "program_preamble"
                preamble_line_count = preamble_source.count("\n")
                unit_end_line = s_idx + 1 + preamble_line_count
                unit_source = preamble_source
                # Inner units (after CONTAINS) will be picked up by their
                # own START entries in the main loop.

        # Extract the signature (first logical line, handling continuations)
        sig_lines = []
        for line in unit_source.splitlines():
            sig_lines.append(line.rstrip())
            if "&" not in line:
                break
        signature = " ".join(sig_lines).strip()

        unit = FortranUnit(
            kind=kind,
            name=s_name,
            source=unit_source,
            start_line=s_idx + 1,
            end_line=unit_end_line,
            signature=signature,
            calls=_extract_calls(unit_source),
            uses=_extract_uses(unit_source),
        )
        units.append(unit)

    # Split large preambles into sub-sections
    expanded: List[FortranUnit] = []
    for u in units:
        if u.kind == "program_preamble":
            expanded.extend(_split_preamble(u))
        else:
            expanded.append(u)
    units = expanded

    logger.info(
        "Parsed %d logical units: %s",
        len(units),
        ", ".join(f"{u.kind}:{u.name}" for u in units),
    )
    return units, header_comments


def _extract_calls(source: str) -> List[str]:
    """Extract unique CALL targets from source."""
    return sorted(set(m.upper() for m in _CALL_RE.findall(source)))


def _extract_uses(source: str) -> List[str]:
    """Extract unique USE targets from source."""
    return sorted(set(m.upper() for m in _USE_RE.findall(source)))


_SECTION_HEADER = re.compile(
    r"^(!\*{3,}.*\n(?:!.*\n)*?!\*{3,}|!-{3,}.*\n(?:!.*\n)*?!-{3,})",
    re.MULTILINE,
)


def _split_preamble(unit: FortranUnit, max_lines: int = 500) -> List[FortranUnit]:
    """
    Split a large program_preamble into sub-sections using comment block
    headers (e.g., lines of !*** or !---). This captures important inline
    code like the 'Main Calculations' section that orchestrates CALL order.

    Returns a list of FortranUnit objects with kind='program_section'.
    If the preamble is small enough, returns it unchanged.
    """
    source_lines = unit.source.splitlines(keepends=True)
    if len(source_lines) <= max_lines:
        return [unit]

    # Find section boundaries: lines that are comment banners
    # A section starts at a banner line like "!**************************"
    banner_re = re.compile(r"^\s*![*=\-]{10,}")
    section_starts: List[Tuple[int, str]] = []  # (line_idx_in_source, section_name)

    i = 0
    while i < len(source_lines):
        line = source_lines[i]
        if banner_re.match(line):
            # Look for a title in the next line(s) between banner lines
            title = ""
            j = i + 1
            while j < len(source_lines) and not banner_re.match(source_lines[j]):
                candidate = source_lines[j].strip().lstrip("!").strip()
                if candidate:
                    title = candidate
                    break
                j += 1
            if not title:
                title = line.strip().lstrip("!").strip()[:60]
            section_starts.append((i, title))
            i = j + 1
        else:
            i += 1

    if len(section_starts) < 2:
        return [unit]

    # Build sub-units from section boundaries
    sub_units: List[FortranUnit] = []
    for idx, (sec_start, sec_title) in enumerate(section_starts):
        if idx + 1 < len(section_starts):
            sec_end = section_starts[idx + 1][0]
        else:
            sec_end = len(source_lines)

        sec_source = "".join(source_lines[sec_start:sec_end])
        if not sec_source.strip():
            continue

        # Generate a readable name
        safe_name = re.sub(r"[^A-Za-z0-9_ ]", "", sec_title).strip()
        safe_name = re.sub(r"\s+", "_", safe_name)[:60] or f"section_{idx}"

        sub = FortranUnit(
            kind="program_section",
            name=safe_name,
            source=sec_source,
            start_line=unit.start_line + sec_start,
            end_line=unit.start_line + sec_end - 1,
            signature=f"! {sec_title}",
            calls=_extract_calls(sec_source),
            uses=_extract_uses(sec_source),
        )
        sub_units.append(sub)

    # Merge adjacent tiny sections (< min_lines) into their successor
    min_lines = 15
    merged: List[FortranUnit] = []
    buffer: Optional[FortranUnit] = None

    for su in sub_units:
        su_lines = su.end_line - su.start_line + 1
        if buffer is None:
            if su_lines < min_lines:
                buffer = su
            else:
                merged.append(su)
        else:
            # Merge buffer into this section
            combined_source = buffer.source + su.source
            combined = FortranUnit(
                kind="program_section",
                name=su.name if su_lines >= min_lines else buffer.name,
                source=combined_source,
                start_line=buffer.start_line,
                end_line=su.end_line,
                signature=buffer.signature,
                calls=_extract_calls(combined_source),
                uses=_extract_uses(combined_source),
            )
            combined_lines = combined.end_line - combined.start_line + 1
            if combined_lines < min_lines:
                buffer = combined
            else:
                merged.append(combined)
                buffer = None

    if buffer is not None:
        if merged:
            # Merge trailing small buffer into the last section
            last = merged[-1]
            combined_source = last.source + buffer.source
            merged[-1] = FortranUnit(
                kind="program_section",
                name=last.name,
                source=combined_source,
                start_line=last.start_line,
                end_line=buffer.end_line,
                signature=last.signature,
                calls=_extract_calls(combined_source),
                uses=_extract_uses(combined_source),
            )
        else:
            merged.append(buffer)

    logger.info(
        "Split preamble (%d lines) into %d sections: %s",
        len(source_lines), len(merged),
        ", ".join(s.name for s in merged),
    )
    return merged


def build_call_graph(units: List[FortranUnit]) -> Dict[str, List[str]]:
    """Build a call graph: {caller_name: [callee_name, ...]}."""
    return {u.name.upper(): u.calls for u in units if u.calls}


# ── LLM summarization ───────────────────────────────────────────────────

# Threshold: units larger than this get a skeleton extraction first.
_LARGE_UNIT_LINES = 400

# Patterns that indicate structurally important lines worth keeping
_SKELETON_KEEP = re.compile(
    r"^\s*("
    r"!.*|"                              # all comments
    r"(?:REAL|INTEGER|DOUBLE|LOGICAL|CHARACTER|COMPLEX)\b.*|"  # declarations
    r"(?:DO|END\s*DO|IF|ELSE|END\s*IF|SELECT|CASE|END\s*SELECT)\b.*|"  # control flow
    r"CALL\s+\w+.*|"                     # CALL statements
    r"ALLOCATE\b.*|"                     # ALLOCATE
    r"(?:READ|WRITE|OPEN|CLOSE|PRINT)\b.*|"  # I/O
    r"(?:SUBROUTINE|FUNCTION|END\s+SUBROUTINE|END\s+FUNCTION)\b.*"  # boundaries
    r")",
    re.IGNORECASE,
)


def _extract_skeleton(source: str) -> str:
    """
    Extract a structural skeleton from a large Fortran unit.

    Keeps: comments, declarations, control flow headers (DO/IF/SELECT),
    CALL statements, I/O, and ALLOCATE. Drops the dense computational
    lines (assignments, arithmetic). This produces a much shorter
    representation that still captures the algorithm's structure.
    """
    lines = source.splitlines()
    kept = []
    skipped_run = 0

    for i, line in enumerate(lines):
        if _SKELETON_KEEP.match(line):
            if skipped_run > 0:
                kept.append(f"      ! ... ({skipped_run} computational lines omitted)")
                skipped_run = 0
            kept.append(line)
        else:
            skipped_run += 1

    if skipped_run > 0:
        kept.append(f"      ! ... ({skipped_run} computational lines omitted)")

    return "\n".join(kept)


def _summarize_unit(
    client: LocalLLMClient,
    unit: FortranUnit,
    call_graph: Dict[str, List[str]],
) -> dict:
    """Use the LLM to produce a structured summary of a single Fortran unit."""

    # Build context about what calls this unit
    called_by = [
        caller for caller, callees in call_graph.items()
        if unit.name.upper() in callees
    ]

    unit_lines = unit.end_line - unit.start_line + 1
    is_large = unit_lines > _LARGE_UNIT_LINES

    system_prompt = (
        "You are an expert computational economist analyzing Fortran code that "
        "implements economic models (overlapping generations, heterogeneous agents, "
        "wealth distribution, etc.). "
        "Given a single Fortran subroutine/function, produce a JSON object with these keys:\n"
        '  "function_name": the subroutine/function name,\n'
        '  "purpose": 1-2 sentence description of what this computes and its economic meaning,\n'
        '  "algorithm": step-by-step pseudocode of the core logic (5-15 steps),\n'
        '  "inputs": list of key input variables/parameters with brief descriptions,\n'
        '  "outputs": list of key output variables/results with brief descriptions,\n'
        '  "economic_concepts": list of economic concepts this implements '
        "(e.g., 'Gini coefficient', 'invariant distribution', 'policy function').\n"
        "Output ONLY the JSON object, no other text."
    )

    context_parts = [f"Subroutine/Function: {unit.name}"]
    if unit.calls:
        context_parts.append(f"Calls: {', '.join(unit.calls)}")
    if called_by:
        context_parts.append(f"Called by: {', '.join(called_by)}")
    if unit.uses:
        context_parts.append(f"Uses modules: {', '.join(unit.uses)}")
    context_header = "\n".join(context_parts)

    # For large units, use skeleton to improve summary quality
    if is_large:
        skeleton = _extract_skeleton(unit.source)
        logger.info(
            "Large unit %s (%d lines) → skeleton (%d lines)",
            unit.name, unit_lines, skeleton.count("\n") + 1,
        )
        code_block = (
            f"NOTE: This is a large subroutine ({unit_lines} lines). "
            f"Below is a structural skeleton with computational lines omitted.\n\n"
            f"```fortran\n{skeleton}\n```"
        )
    else:
        code_block = f"```fortran\n{unit.source}\n```"

    user_prompt = f"{context_header}\n\n{code_block}"

    try:
        response = client.generate_response(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            response_mime_type="application/json",
            max_tokens=4096,
            temperature=0.1,
        )

        if isinstance(response, dict):
            result = response
        else:
            cleaned = _extract_json(response)
            result = json.loads(cleaned)

        # Normalize keys
        result.setdefault("function_name", unit.name)
        result.setdefault("purpose", "")
        result.setdefault("algorithm", "")
        result.setdefault("inputs", [])
        result.setdefault("outputs", [])
        result.setdefault("economic_concepts", [])
        return result

    except Exception as e:
        logger.error("Failed to summarize %s: %s", unit.name, e)
        return {
            "function_name": unit.name,
            "purpose": f"[LLM summarization failed: {e}]",
            "algorithm": "",
            "inputs": [],
            "outputs": [],
            "economic_concepts": [],
        }


def _generate_architecture_doc(
    client: LocalLLMClient,
    header_comments: str,
    units: List[FortranUnit],
    call_graph: Dict[str, List[str]],
) -> str:
    """Produce a global architecture overview from signatures + call graph."""

    # Build a concise listing of all units
    sig_list = []
    for u in units:
        line = f"  {u.kind.upper()} {u.name}"
        if u.calls:
            line += f"  →  calls: {', '.join(u.calls)}"
        sig_list.append(line)
    signatures_text = "\n".join(sig_list)

    # Format call graph
    cg_lines = []
    for caller, callees in sorted(call_graph.items()):
        cg_lines.append(f"  {caller} → {', '.join(callees)}")
    cg_text = "\n".join(cg_lines) if cg_lines else "(no inter-unit calls)"

    system_prompt = (
        "You are an expert computational economist. Given the structure of a "
        "Fortran program that implements an economic model, write a clear "
        "architecture overview (300-500 words) that explains:\n"
        "1. What economic model this program implements\n"
        "2. The high-level computational pipeline (what runs in what order)\n"
        "3. Key calibration/solution strategies\n"
        "4. What outputs the model produces\n"
        "Write in plain English for a researcher who wants to understand the "
        "code without reading it. Do not output JSON."
    )

    user_prompt = (
        "FILE HEADER COMMENTS:\n"
        f"{header_comments}\n\n"
        "ALL UNITS (with call targets):\n"
        f"{signatures_text}\n\n"
        "CALL GRAPH:\n"
        f"{cg_text}"
    )

    try:
        response = client.generate_response(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            response_mime_type="text/plain",
            max_tokens=2048,
            temperature=0.2,
        )
        return response.strip()
    except Exception as e:
        logger.error("Failed to generate architecture doc: %s", e)
        return f"[Architecture generation failed: {e}]"


def _extract_json(text: str) -> str:
    """Extract JSON from LLM response that may include markdown fences."""
    m = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL)
    if m:
        return m.group(1).strip()
    # Try to find raw JSON object
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if m:
        return m.group(0)
    return text.strip()


# ── Main entry points ────────────────────────────────────────────────────

def digest_fortran_code(
    code_content: str,
    output_json_path: str,
    model_name: str = "gemma4:31b",
    base_url: str = "http://localhost:11434/v1",
    api_key: str = "ollama",
) -> dict:
    """
    Structure-aware Fortran code digestion.

    1. Parse source into logical units (subroutines, functions, etc.)
    2. Extract call graph from CALL/USE statements
    3. Summarize each unit individually via LLM
    4. Generate a global architecture overview
    5. Save everything to a single JSON file

    Args:
        code_content: Raw Fortran source code.
        output_json_path: Where to save the digest JSON.
        model_name: LLM model name.
        base_url: LLM API base URL.
        api_key: LLM API key.

    Returns:
        The digest as a dict.
    """
    logger.info("Starting structure-aware Fortran digestion (%d chars)", len(code_content))

    # ── 1. Parse ─────────────────────────────────────────────────────────
    units, header_comments = parse_fortran_units(code_content)
    call_graph = build_call_graph(units)

    logger.info(
        "Parsed %d units, %d call-graph edges",
        len(units),
        sum(len(v) for v in call_graph.values()),
    )

    # ── 2. Summarize each unit via LLM ──────────────────────────────────
    client = LocalLLMClient(
        model_name=model_name,
        base_url=base_url,
        api_key=api_key,
    )

    function_digests = []
    for i, unit in enumerate(units):
        logger.info(
            "Summarizing unit %d/%d: %s %s (%d lines)",
            i + 1, len(units), unit.kind, unit.name,
            unit.end_line - unit.start_line + 1,
        )
        summary = _summarize_unit(client, unit, call_graph)

        # Attach structural metadata (from parsing, not LLM)
        summary["kind"] = unit.kind
        summary["start_line"] = unit.start_line
        summary["end_line"] = unit.end_line
        summary["signature"] = unit.signature
        summary["calls"] = unit.calls
        summary["called_by"] = [
            caller for caller, callees in call_graph.items()
            if unit.name.upper() in callees
        ]
        summary["uses"] = unit.uses

        # Build composite text for embedding (used by store_to_db)
        composite_parts = [
            f"{unit.kind.upper()} {unit.name}",
            summary.get("purpose", ""),
        ]
        if summary.get("economic_concepts"):
            composite_parts.append(
                "Economic concepts: " + ", ".join(summary["economic_concepts"])
            )
        if unit.calls:
            composite_parts.append("Calls: " + ", ".join(unit.calls))
        if summary.get("called_by"):
            composite_parts.append("Called by: " + ", ".join(summary["called_by"]))
        algo = summary.get("algorithm", "")
        if algo:
            if isinstance(algo, list):
                algo = "\n".join(f"  {step}" for step in algo)
            composite_parts.append(f"Algorithm:\n{algo}")

        summary["composite_text"] = "\n".join(composite_parts)

        function_digests.append(summary)

    # ── 3. Architecture overview ────────────────────────────────────────
    logger.info("Generating architecture overview …")
    architecture_doc = _generate_architecture_doc(
        client, header_comments, units, call_graph,
    )

    # ── 4. Assemble and save ────────────────────────────────────────────
    digest = {
        "architecture_overview": architecture_doc,
        "call_graph": call_graph,
        "key_functions": function_digests,
    }

    output_path = Path(output_json_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(digest, f, indent=4, ensure_ascii=False)

    logger.info("Saved digest with %d units to %s", len(function_digests), output_json_path)
    return digest


def summarize_fortran_digest(
    json_path: Union[str, Path],
    model_name: str = "gemma4:31b",
    base_url: str = "http://localhost:11434/v1",
    api_key: str = "ollama",
):
    """
    Post-process pass: kept for backward compatibility with the orchestrator.

    The new digest_fortran_code already produces per-unit summaries and
    composite_text, so this function is now a lightweight no-op that just
    verifies the digest file exists and logs a confirmation.
    """
    json_path = Path(json_path)
    if not json_path.exists():
        raise FileNotFoundError(f"Digest JSON not found: {json_path}")

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    n_funcs = len(data.get("key_functions", []))
    has_arch = bool(data.get("architecture_overview"))
    logger.info(
        "Digest verified: %d functions, architecture_overview=%s",
        n_funcs, "yes" if has_arch else "no",
    )


# ── CLI / manual test ────────────────────────────────────────────────────

if __name__ == "__main__":
    sample_fortran_code = """
    PROGRAM MAIN
      REAL A, B, C
      A = 10.0
      B = 20.0
      CALL ADD_NUMS(A, B, C)
      PRINT *, "The result is: ", C
    END PROGRAM MAIN

    SUBROUTINE ADD_NUMS(X, Y, Z)
      REAL X, Y, Z
      Z = X + Y
    END SUBROUTINE ADD_NUMS
    """

    test_output_path = "output_test/fortran_digest.json"
    digest_fortran_code(
        code_content=sample_fortran_code,
        output_json_path=test_output_path,
    )
    summarize_fortran_digest(test_output_path)
