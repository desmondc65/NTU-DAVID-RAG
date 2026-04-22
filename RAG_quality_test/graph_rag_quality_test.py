"""
GraphRAG quality test — automated evaluator.

Reads categorised questions from ``questions.md``, issues each through the
GraphRAG service's ``POST /api/query`` endpoint, and writes a timestamped
markdown report with, for every question:

- the exact question text
- the service's generated answer + chosen mode (local/global)
- the retrieved chunks (paper title, section, content type, excerpt)
- the graph context (seeds, subgraph node count, communities)
- per-question latency and error info

Usage
-----
    python graph_rag_quality_test.py                                 # defaults
    python graph_rag_quality_test.py --api http://localhost:3007     # custom host
    python graph_rag_quality_test.py --limit 5                       # first 5 only
    python graph_rag_quality_test.py --out-dir results/              # pick output dir
    python graph_rag_quality_test.py --mode local --timeout 300      # tuning
    python graph_rag_quality_test.py --max-chunks 15 --keep-top-k 10

The GraphRAG container exposes port 3007 by default (see
``docker/graphRag/docker-compose.yml``). Override with ``--api`` or the
``GRAPHRAG_API_BASE`` environment variable.

Output files land in ``results/`` with the suffix ``_graph_rag`` so they
don't collide with the vector-RAG results.
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

CURRENT_DIR = Path(__file__).resolve().parent

DEFAULT_API = os.environ.get("GRAPHRAG_API_BASE", "http://localhost:3007").rstrip("/")
DEFAULT_QUESTIONS = CURRENT_DIR / "questions.md"
DEFAULT_OUT_DIR = CURRENT_DIR / "results"

logger = logging.getLogger("graph_rag_quality_test")


# ── Question parsing ─────────────────────────────────────────────────────

_HEADING_RE = re.compile(r"^##\s+(.*?)\s*$")
_NUMBERED_RE = re.compile(r"^(\d+)\.\s+(.*?)\s*$")


@dataclass
class Question:
    number: int
    category: str
    text: str


def parse_questions(path: Path) -> List[Question]:
    """Parse the markdown questions file into a flat list of Question records.

    Only lines matching the ``N. ...`` pattern are treated as questions; the
    active ``##`` heading provides the category label. Sub-bullets indented
    beneath a question are ignored.
    """
    questions: List[Question] = []
    current_category = "(uncategorised)"
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        heading = _HEADING_RE.match(line)
        if heading:
            current_category = heading.group(1).strip()
            continue
        m = _NUMBERED_RE.match(line)
        if m:
            questions.append(
                Question(
                    number=int(m.group(1)),
                    category=current_category,
                    text=m.group(2).strip(),
                )
            )
    if not questions:
        raise RuntimeError(f"No questions parsed from {path} — check formatting.")
    return questions


# ── HTTP client ──────────────────────────────────────────────────────────

@dataclass
class QueryOutcome:
    question: Question
    answer: str = ""
    mode: Optional[str] = None
    seeds: List[Any] = field(default_factory=list)
    subgraph_nodes: Any = None
    candidate_count: Optional[int] = None
    chunks: List[Dict[str, Any]] = field(default_factory=list)
    communities: List[Any] = field(default_factory=list)
    latency_s: float = 0.0
    error: Optional[str] = None


def run_query(
    api_base: str,
    question: Question,
    mode: str,
    extra_params: Dict[str, int],
    timeout: int,
    session: requests.Session,
) -> QueryOutcome:
    """POST the question to the GraphRAG service and capture the response."""
    outcome = QueryOutcome(question=question)
    url = f"{api_base}/api/query"
    payload: Dict[str, Any] = {"query": question.text, "mode": mode, **extra_params}
    t0 = time.monotonic()
    try:
        resp = session.post(url, json=payload, timeout=timeout)
    except requests.RequestException as exc:
        outcome.error = f"network error: {exc}"
        outcome.latency_s = time.monotonic() - t0
        return outcome
    outcome.latency_s = time.monotonic() - t0

    try:
        data = resp.json()
    except ValueError:
        outcome.error = f"non-JSON response (status {resp.status_code}): {resp.text[:200]}"
        return outcome

    if resp.status_code != 200:
        outcome.error = data.get("error") or f"HTTP {resp.status_code}"
        if data.get("hint"):
            outcome.error = f"{outcome.error} (hint: {data['hint']})"
        return outcome

    outcome.answer = data.get("answer", "") or ""
    outcome.mode = data.get("mode")
    seeds = data.get("seeds") or []
    if isinstance(seeds, list):
        outcome.seeds = seeds
    outcome.subgraph_nodes = data.get("subgraph_nodes")
    outcome.candidate_count = data.get("candidate_count")
    chunks = data.get("chunks") or []
    if isinstance(chunks, list):
        outcome.chunks = chunks
    communities = data.get("communities") or []
    if isinstance(communities, list):
        outcome.communities = communities
    return outcome


# ── Report rendering ─────────────────────────────────────────────────────

def _safe(text: Any, limit: int = 600) -> str:
    """Clip + clean a string for inline markdown display."""
    s = str(text or "").strip()
    if not s:
        return "_(empty)_"
    if len(s) > limit:
        s = s[:limit].rstrip() + " …"
    return s


def _render_chunk_row(idx: int, chunk: Dict[str, Any]) -> List[str]:
    meta = chunk.get("metadata") or {}
    ct = meta.get("content_type", "?")
    paper = meta.get("paper_title", "(no title)")
    section = meta.get("section", "")
    fn_name = meta.get("function_name", "")
    chunk_id = chunk.get("id", "")

    header_parts = [f"**[{idx}] {ct}**"]
    if chunk_id:
        header_parts.append(f"id: `{chunk_id}`")
    if paper:
        header_parts.append(f'paper: "{paper}"')
    if section:
        header_parts.append(f"section: `{section}`")
    if fn_name:
        header_parts.append(f"function: `{fn_name}`")

    lines = ["- " + " · ".join(header_parts)]
    text = _safe(chunk.get("text"), limit=700)
    # Quote block for the text excerpt so markdown renders cleanly.
    for line in text.splitlines():
        lines.append(f"    > {line}")
    return lines


def _render_community(idx: int, comm: Any) -> str:
    if isinstance(comm, dict):
        cid = comm.get("id", idx)
        size = comm.get("size", comm.get("node_count", ""))
        summary = _safe(comm.get("summary") or comm.get("description") or comm, limit=400)
        tag = f"community `{cid}`"
        if size:
            tag += f" (size: {size})"
        return f"- **[{idx}] {tag}** — {summary}"
    return f"- **[{idx}]** {_safe(comm, limit=400)}"


def render_report(
    outcomes: List[QueryOutcome],
    api_base: str,
    mode: str,
    extra_params: Dict[str, int],
    started_at: datetime,
    duration_s: float,
) -> str:
    lines: List[str] = []
    lines.append("# GraphRAG quality test — results")
    lines.append("")
    lines.append(f"- **Run at:** `{started_at.isoformat(timespec='seconds')}`")
    lines.append(f"- **API:** `{api_base}`")
    lines.append(f"- **mode:** `{mode}`")
    if extra_params:
        params_str = ", ".join(f"{k}={v}" for k, v in extra_params.items())
        lines.append(f"- **params:** `{params_str}`")
    lines.append(f"- **Questions:** `{len(outcomes)}`")
    failed = [o for o in outcomes if o.error]
    lines.append(f"- **Failed:** `{len(failed)}`")
    lines.append(f"- **Total duration:** `{duration_s:.1f}s`")
    lines.append("")

    # Per-category summary
    from collections import OrderedDict
    by_category: "OrderedDict[str, List[QueryOutcome]]" = OrderedDict()
    for o in outcomes:
        by_category.setdefault(o.question.category, []).append(o)
    lines.append("## Summary by category")
    lines.append("")
    lines.append("| Category | Questions | Avg latency (s) | Errors |")
    lines.append("|---|---:|---:|---:|")
    for cat, group in by_category.items():
        lat = sum(o.latency_s for o in group) / max(len(group), 1)
        errs = sum(1 for o in group if o.error)
        lines.append(f"| {cat} | {len(group)} | {lat:.1f} | {errs} |")
    lines.append("")

    # Mode breakdown — GraphRAG picks local vs. global per question in auto mode
    mode_counts: "OrderedDict[str, int]" = OrderedDict()
    for o in outcomes:
        key = o.mode or "(none)"
        mode_counts[key] = mode_counts.get(key, 0) + 1
    lines.append("## Mode breakdown")
    lines.append("")
    lines.append("| Resolved mode | Questions |")
    lines.append("|---|---:|")
    for m, n in mode_counts.items():
        lines.append(f"| `{m}` | {n} |")
    lines.append("")

    # Table of contents
    lines.append("## Questions")
    lines.append("")
    for o in outcomes:
        anchor = f"q-{o.question.number}"
        lines.append(
            f"- [Q{o.question.number}]({'#' + anchor}) — _{o.question.category}_ — {o.question.text}"
        )
    lines.append("")
    lines.append("---")
    lines.append("")

    # Per-question body
    for o in outcomes:
        q = o.question
        lines.append(f'<a id="q-{q.number}"></a>')
        lines.append(f"## Q{q.number}. {q.text}")
        lines.append("")
        lines.append(f"- **Category:** {q.category}")
        lines.append(f"- **Latency:** `{o.latency_s:.2f}s`")
        if o.mode:
            lines.append(f"- **Resolved mode:** `{o.mode}`")
        if o.subgraph_nodes is not None:
            lines.append(f"- **Subgraph nodes:** `{o.subgraph_nodes}`")
        if o.candidate_count is not None:
            lines.append(f"- **Candidate count:** `{o.candidate_count}`")
        if o.seeds:
            seed_preview = ", ".join(f"`{s}`" for s in o.seeds[:10])
            extra = "" if len(o.seeds) <= 10 else f" (+{len(o.seeds) - 10} more)"
            lines.append(f"- **Seeds ({len(o.seeds)}):** {seed_preview}{extra}")
        if o.error:
            lines.append(f"- **Error:** `{o.error}`")
        lines.append("")

        lines.append("### Answer")
        lines.append("")
        lines.append(o.answer if o.answer else "_(empty)_")
        lines.append("")

        if o.chunks:
            lines.append(f"### Retrieved chunks ({len(o.chunks)})")
            lines.append("")
            for i, chunk in enumerate(o.chunks, 1):
                lines.extend(_render_chunk_row(i, chunk))
            lines.append("")
        else:
            lines.append("### Retrieved chunks")
            lines.append("")
            lines.append("_(none)_")
            lines.append("")

        if o.communities:
            lines.append(f"### Communities ({len(o.communities)})")
            lines.append("")
            for i, comm in enumerate(o.communities, 1):
                lines.append(_render_community(i, comm))
            lines.append("")

        lines.append("---")
        lines.append("")

    return "\n".join(lines)


# ── Main ─────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a GraphRAG-quality regression over questions.md."
    )
    parser.add_argument("--api", default=DEFAULT_API,
                        help=f"GraphRAG API base URL (default: {DEFAULT_API})")
    parser.add_argument("--questions", default=str(DEFAULT_QUESTIONS),
                        help="Path to the markdown questions file.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR),
                        help="Directory to write the results markdown into.")
    parser.add_argument("--mode", default="auto", choices=["auto", "local", "global"],
                        help="GraphRAG query mode (default: auto).")
    parser.add_argument("--n-hop", type=int, default=None,
                        help="Subgraph hop radius (local mode).")
    parser.add_argument("--max-chunks", type=int, default=None,
                        help="Max chunks pulled from the subgraph.")
    parser.add_argument("--candidate-top-k", type=int, default=None,
                        help="Seed-candidate top_k for local search.")
    parser.add_argument("--keep-top-k", type=int, default=None,
                        help="Chunks kept after reranking.")
    parser.add_argument("--max-generation-tokens", type=int, default=None,
                        help="LLM generation cap.")
    parser.add_argument("--timeout", type=int, default=900,
                        help="Per-query HTTP timeout (seconds).")
    parser.add_argument("--limit", type=int, default=None,
                        help="Only run the first N questions.")
    parser.add_argument("--only-category", default=None,
                        help="Restrict to questions whose category contains this substring (case-insensitive).")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s | %(message)s",
    )

    api_base = args.api.rstrip("/")
    questions_path = Path(args.questions)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Pack only the tuning knobs the user explicitly set — the server fills
    # the rest from its own defaults.
    extra_params: Dict[str, int] = {}
    for key, attr in (
        ("n_hop", "n_hop"),
        ("max_chunks", "max_chunks"),
        ("candidate_top_k", "candidate_top_k"),
        ("keep_top_k", "keep_top_k"),
        ("max_generation_tokens", "max_generation_tokens"),
    ):
        val = getattr(args, attr)
        if val is not None:
            extra_params[key] = val

    questions = parse_questions(questions_path)
    if args.only_category:
        needle = args.only_category.lower()
        questions = [q for q in questions if needle in q.category.lower()]
    if args.limit is not None:
        questions = questions[: args.limit]
    if not questions:
        logger.error("No questions to run after filtering.")
        return 2

    logger.info(
        "Running %d question(s) against %s (mode=%s, params=%s, timeout=%ds)",
        len(questions), api_base, args.mode, extra_params or "{}", args.timeout,
    )

    # Fail fast if the service is unreachable — also surfaces graph-not-built.
    try:
        status = requests.get(f"{api_base}/api/status", timeout=30)
        status.raise_for_status()
        status_body = status.json()
        logger.info("Service reachable: %s", status_body)
        if isinstance(status_body, dict) and status_body.get("graph_built") is False:
            logger.warning(
                "GraphRAG reports graph_built=False — queries will 409 until POST /api/build."
            )
    except requests.RequestException as exc:
        logger.error("Cannot reach GraphRAG service at %s: %s", api_base, exc)
        return 3

    outcomes: List[QueryOutcome] = []
    started_at = datetime.now()
    run_t0 = time.monotonic()

    with requests.Session() as session:
        for i, q in enumerate(questions, 1):
            logger.info("[%d/%d] %s — Q%d: %s",
                        i, len(questions), q.category, q.number, q.text[:80])
            outcome = run_query(
                api_base=api_base,
                question=q,
                mode=args.mode,
                extra_params=extra_params,
                timeout=args.timeout,
                session=session,
            )
            if outcome.error:
                logger.warning("  ✗ error: %s", outcome.error)
            else:
                logger.info(
                    "  ✓ %ds · mode=%s · %d chunks · %d communities · %d chars",
                    round(outcome.latency_s),
                    outcome.mode or "?",
                    len(outcome.chunks),
                    len(outcome.communities),
                    len(outcome.answer),
                )
            outcomes.append(outcome)

    duration_s = time.monotonic() - run_t0

    stamp = started_at.strftime("%Y-%m-%d_%H%M%S")
    out_path = out_dir / f"results_{stamp}_graph_rag.md"
    report = render_report(
        outcomes=outcomes,
        api_base=api_base,
        mode=args.mode,
        extra_params=extra_params,
        started_at=started_at,
        duration_s=duration_s,
    )
    out_path.write_text(report, encoding="utf-8")
    # Also emit a machine-readable JSON sidecar for downstream analysis.
    json_path = out_dir / f"results_{stamp}_graph_rag.json"
    json_path.write_text(
        json.dumps(
            {
                "api": api_base,
                "mode": args.mode,
                "params": extra_params,
                "started_at": started_at.isoformat(),
                "duration_s": duration_s,
                "results": [
                    {
                        "number": o.question.number,
                        "category": o.question.category,
                        "question": o.question.text,
                        "answer": o.answer,
                        "resolved_mode": o.mode,
                        "seeds": o.seeds,
                        "subgraph_nodes": o.subgraph_nodes,
                        "candidate_count": o.candidate_count,
                        "chunks": o.chunks,
                        "communities": o.communities,
                        "latency_s": o.latency_s,
                        "error": o.error,
                    }
                    for o in outcomes
                ],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    failed = sum(1 for o in outcomes if o.error)
    logger.info("Done — %d outcomes, %d errors, wrote %s", len(outcomes), failed, out_path)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
