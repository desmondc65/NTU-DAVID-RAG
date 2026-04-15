"""
RAG quality test — automated evaluator.

Reads categorised questions from ``questions.md``, issues each through the
RAG service's ``POST /api/query`` endpoint, and writes a timestamped markdown
report with, for every question:

- the exact question text
- the service's generated answer
- the retrieved sources (paper title, section, content type, score, excerpt)
- per-question latency and error info

Usage
-----
    python rag_quality_test.py                                 # defaults
    python rag_quality_test.py --api http://localhost:3006     # custom host
    python rag_quality_test.py --limit 5                       # first 5 only
    python rag_quality_test.py --out-dir results/              # pick output dir
    python rag_quality_test.py --top-k 15 --timeout 300        # tuning

The script is dependency-light — only ``requests`` is needed. If the RAG
service lives behind a different port than the default, set ``--api`` or
the ``RAG_API_BASE`` environment variable.
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

DEFAULT_API = os.environ.get("RAG_API_BASE", "http://localhost:3006").rstrip("/")
DEFAULT_QUESTIONS = CURRENT_DIR / "questions.md"
DEFAULT_OUT_DIR = CURRENT_DIR / "results"

logger = logging.getLogger("rag_quality_test")


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
    sources: List[Dict[str, Any]] = field(default_factory=list)
    latency_s: float = 0.0
    error: Optional[str] = None


def run_query(
    api_base: str,
    question: Question,
    top_k: int,
    timeout: int,
    session: requests.Session,
) -> QueryOutcome:
    """POST the question to the RAG service and capture the response."""
    outcome = QueryOutcome(question=question)
    url = f"{api_base}/api/query"
    payload = {"query": question.text, "top_k": top_k}
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
        return outcome

    outcome.answer = data.get("answer", "") or ""
    sources = data.get("sources") or []
    if isinstance(sources, list):
        outcome.sources = sources
    return outcome


# ── Report rendering ─────────────────────────────────────────────────────

def _fmt_score(score: Any) -> str:
    try:
        return f"{float(score):.4f}"
    except (TypeError, ValueError):
        return str(score)


def _safe(text: Any, limit: int = 600) -> str:
    """Clip + clean a string for inline markdown display."""
    s = str(text or "").strip()
    if not s:
        return "_(empty)_"
    if len(s) > limit:
        s = s[:limit].rstrip() + " …"
    return s


def _render_source_row(idx: int, src: Dict[str, Any]) -> List[str]:
    meta = src.get("metadata") or {}
    ct = meta.get("content_type", "?")
    paper = meta.get("paper_title", "(no title)")
    section = meta.get("section", "")
    fn_name = meta.get("function_name", "")
    score = _fmt_score(src.get("score"))

    header_parts = [f"**[{idx}] {ct}**", f"score: `{score}`"]
    if paper:
        header_parts.append(f'paper: "{paper}"')
    if section:
        header_parts.append(f"section: `{section}`")
    if fn_name:
        header_parts.append(f"function: `{fn_name}`")

    lines = ["- " + " · ".join(header_parts)]
    text = _safe(src.get("text"), limit=700)
    # Quote block for the text excerpt so markdown renders cleanly.
    for line in text.splitlines():
        lines.append(f"    > {line}")
    return lines


def render_report(
    outcomes: List[QueryOutcome],
    api_base: str,
    top_k: int,
    started_at: datetime,
    duration_s: float,
) -> str:
    lines: List[str] = []
    lines.append("# RAG quality test — results")
    lines.append("")
    lines.append(f"- **Run at:** `{started_at.isoformat(timespec='seconds')}`")
    lines.append(f"- **API:** `{api_base}`")
    lines.append(f"- **top_k:** `{top_k}`")
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

    # Table of contents
    lines.append("## Questions")
    lines.append("")
    for o in outcomes:
        anchor = f"q-{o.question.number}"
        lines.append(f"- [Q{o.question.number}]({'#' + anchor}) — _{o.question.category}_ — {o.question.text}")
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
        if o.error:
            lines.append(f"- **Error:** `{o.error}`")
        lines.append("")

        lines.append("### Answer")
        lines.append("")
        lines.append(o.answer if o.answer else "_(empty)_")
        lines.append("")

        if o.sources:
            lines.append(f"### Retrieved sources ({len(o.sources)})")
            lines.append("")
            for i, src in enumerate(o.sources, 1):
                lines.extend(_render_source_row(i, src))
            lines.append("")
        else:
            lines.append("### Retrieved sources")
            lines.append("")
            lines.append("_(none)_")
            lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines)


# ── Main ─────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description="Run a RAG-quality regression over questions.md.")
    parser.add_argument("--api", default=DEFAULT_API, help=f"RAG API base URL (default: {DEFAULT_API})")
    parser.add_argument("--questions", default=str(DEFAULT_QUESTIONS),
                        help="Path to the markdown questions file.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR),
                        help="Directory to write the results markdown into.")
    parser.add_argument("--top-k", type=int, default=10, help="top_k passed to the query.")
    parser.add_argument("--timeout", type=int, default=900, help="Per-query HTTP timeout (seconds).")
    parser.add_argument("--limit", type=int, default=None, help="Only run the first N questions.")
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

    questions = parse_questions(questions_path)
    if args.only_category:
        needle = args.only_category.lower()
        questions = [q for q in questions if needle in q.category.lower()]
    if args.limit is not None:
        questions = questions[: args.limit]
    if not questions:
        logger.error("No questions to run after filtering.")
        return 2

    logger.info("Running %d question(s) against %s (top_k=%d, timeout=%ds)",
                len(questions), api_base, args.top_k, args.timeout)

    # Fail fast if the service is unreachable.
    try:
        status = requests.get(f"{api_base}/api/status", timeout=10)
        status.raise_for_status()
        logger.info("Service reachable: %s", status.json())
    except requests.RequestException as exc:
        logger.error("Cannot reach RAG service at %s: %s", api_base, exc)
        return 3

    outcomes: List[QueryOutcome] = []
    started_at = datetime.now()
    run_t0 = time.monotonic()

    with requests.Session() as session:
        for i, q in enumerate(questions, 1):
            logger.info("[%d/%d] %s — Q%d: %s",
                        i, len(questions), q.category, q.number, q.text[:80])
            outcome = run_query(api_base, q, args.top_k, args.timeout, session)
            if outcome.error:
                logger.warning("  ✗ error: %s", outcome.error)
            else:
                logger.info("  ✓ %ds · %d sources · %d chars",
                            round(outcome.latency_s), len(outcome.sources),
                            len(outcome.answer))
            outcomes.append(outcome)

    duration_s = time.monotonic() - run_t0

    stamp = started_at.strftime("%Y-%m-%d_%H%M%S")
    out_path = out_dir / f"results_{stamp}.md"
    report = render_report(
        outcomes=outcomes,
        api_base=api_base,
        top_k=args.top_k,
        started_at=started_at,
        duration_s=duration_s,
    )
    out_path.write_text(report, encoding="utf-8")
    # Also emit a machine-readable JSON sidecar for downstream analysis.
    json_path = out_dir / f"results_{stamp}.json"
    json_path.write_text(
        json.dumps(
            {
                "api": api_base,
                "top_k": args.top_k,
                "started_at": started_at.isoformat(),
                "duration_s": duration_s,
                "results": [
                    {
                        "number": o.question.number,
                        "category": o.question.category,
                        "question": o.question.text,
                        "answer": o.answer,
                        "sources": o.sources,
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
