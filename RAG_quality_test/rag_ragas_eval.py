"""
RAGAS evaluation runner for the original vector RAG service.

This script reuses the existing ``questions.md`` question set and the original
``POST /api/query`` endpoint exposed by ``docker/RAG``. Each successful query
is converted into a reference-free RAGAS sample:

- ``user_input``: the question text
- ``response``: the model answer returned by the API
- ``retrieved_contexts``: source texts from the API response

The first pass intentionally avoids reference-answer metrics. It uses
LLM-only metrics that can score the original RAG without a curated gold
dataset. The evaluation LLM is a local OpenAI-compatible endpoint such as
Ollama on ``http://localhost:11434/v1``.

Usage
-----
    python rag_ragas_eval.py
    python rag_ragas_eval.py --limit 1 --verbose
    python rag_ragas_eval.py --api http://localhost:3006 --top-k 15 --timeout 600
"""
from __future__ import annotations

import argparse
import json
import logging
import math
import os
import statistics
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from langchain_openai import ChatOpenAI

# Disable RAGAS telemetry before importing the package.
os.environ.setdefault("RAGAS_DO_NOT_TRACK", "true")

from ragas.dataset_schema import EvaluationDataset, SingleTurnSample
from ragas.evaluation import evaluate
from ragas.metrics._context_precision import LLMContextPrecisionWithoutReference
from ragas.metrics._faithfulness import Faithfulness
from ragas.run_config import RunConfig

from rag_quality_test import Question, parse_questions, run_query

CURRENT_DIR = Path(__file__).resolve().parent

DEFAULT_API = os.environ.get("RAG_API_BASE", "http://localhost:3006").rstrip("/")
DEFAULT_QUESTIONS = CURRENT_DIR / "questions.md"
DEFAULT_OUT_DIR = CURRENT_DIR / "results"
DEFAULT_LLM_BASE_URL = os.environ.get("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1").rstrip("/")
DEFAULT_LLM_API_KEY = os.environ.get("LOCAL_LLM_API_KEY", "ollama")
DEFAULT_LLM_MODEL = os.environ.get("LLM_MODEL_NAME", "gemma4:31b")
DEFAULT_RAGAS_TOP_CONTEXTS = 3

logger = logging.getLogger("rag_ragas_eval")


def _log_progress(msg: str) -> None:
    """Print a progress line immediately (flushed) in addition to logging."""
    print(msg, flush=True)
    logger.info(msg)


@dataclass
class EvalOutcome:
    question: Question
    answer: str = ""
    sources: List[Dict[str, Any]] = field(default_factory=list)
    scored_sources: List[Dict[str, Any]] = field(default_factory=list)
    retrieved_contexts: List[str] = field(default_factory=list)
    latency_s: float = 0.0
    rag_error: Optional[str] = None
    ragas_error: Optional[str] = None
    metric_scores: Dict[str, Optional[float]] = field(default_factory=dict)


def _safe(text: Any, limit: int = 700) -> str:
    value = str(text or "").strip()
    if not value:
        return "_(empty)_"
    if len(value) > limit:
        return value[:limit].rstrip() + " ..."
    return value


def _is_finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value))


def _format_metric_value(value: Optional[float]) -> str:
    if value is None:
        return "n/a"
    if not math.isfinite(value):
        return "nan"
    return f"{value:.4f}"


def _source_to_context(src: Dict[str, Any]) -> str:
    text = str(src.get("text") or "").strip()
    if text:
        return text

    meta = src.get("metadata") or {}
    parts: List[str] = []
    for key in ("paper_title", "section", "content_type", "function_name"):
        value = str(meta.get(key) or "").strip()
        if value:
            parts.append(f"{key}: {value}")
    if parts:
        return " | ".join(parts)
    return json.dumps(src, ensure_ascii=False)


def _build_sample(outcome: EvalOutcome) -> SingleTurnSample:
    return SingleTurnSample(
        user_input=outcome.question.text,
        response=outcome.answer,
        retrieved_contexts=outcome.retrieved_contexts,
    )


def _build_metrics() -> List[Any]:
    return [
        Faithfulness(),
        LLMContextPrecisionWithoutReference(),
    ]


def _check_rag_service(api_base: str) -> Dict[str, Any]:
    resp = requests.get(f"{api_base}/api/status", timeout=10)
    resp.raise_for_status()
    payload = resp.json()
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected /api/status payload: {payload!r}")
    return payload


def _check_local_llm(base_url: str) -> Dict[str, Any]:
    models_url = f"{base_url}/models"
    resp = requests.get(models_url, timeout=10)
    if resp.ok:
        payload = resp.json()
        if isinstance(payload, dict):
            return payload

    # Ollama also exposes ``/api/tags`` outside the OpenAI-compatible prefix.
    root_base = base_url[:-3] if base_url.endswith("/v1") else base_url
    fallback_url = f"{root_base}/api/tags"
    fallback = requests.get(fallback_url, timeout=10)
    fallback.raise_for_status()
    payload = fallback.json()
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected LLM health payload: {payload!r}")
    return payload


def _summarize_rag_status(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "status": payload.get("status", "ok"),
        "papers_count": payload.get("papers_count"),
        "db_path": payload.get("db_path"),
    }


def _summarize_judge_status(llm_base_url: str, llm_model: str) -> Dict[str, Any]:
    return {
        "provider": "local",
        "model": llm_model,
        "base_url": llm_base_url,
        "reachable": True,
    }


def evaluate_sample(
    sample: SingleTurnSample,
    llm: ChatOpenAI,
    timeout: Optional[int],
) -> Dict[str, Optional[float]]:
    run_config = RunConfig(
        timeout=timeout if timeout is not None else 10**9,
        max_retries=2,
        max_wait=10,
        max_workers=1,
    )
    result = evaluate(
        dataset=EvaluationDataset(samples=[sample]),
        metrics=_build_metrics(),
        llm=llm,
        embeddings=None,
        run_config=run_config,
        raise_exceptions=False,
        show_progress=True,
        batch_size=1,
    )
    row = result.scores[0]
    metric_scores: Dict[str, Optional[float]] = {}
    for key, value in row.items():
        metric_scores[key] = float(value) if _is_finite_number(value) else None
    return metric_scores


def _render_source_row(idx: int, src: Dict[str, Any]) -> List[str]:
    meta = src.get("metadata") or {}
    header_parts = [f"**[{idx}]**"]
    for key in ("content_type", "paper_title", "section", "function_name"):
        value = str(meta.get(key) or "").strip()
        if value:
            header_parts.append(f"{key}: `{value}`")
    score = src.get("score")
    if score is not None:
        try:
            header_parts.append(f"score: `{float(score):.4f}`")
        except (TypeError, ValueError):
            header_parts.append(f"score: `{score}`")

    lines = ["- " + " · ".join(header_parts)]
    for line in _safe(src.get("text"), limit=700).splitlines():
        lines.append(f"    > {line}")
    return lines


def render_markdown(
    outcomes: List[EvalOutcome],
    *,
    api_base: str,
    llm_base_url: str,
    llm_model: str,
    top_k: int,
    started_at: datetime,
    duration_s: float,
    rag_status: Dict[str, Any],
    judge_status: Dict[str, Any],
    aggregates: Dict[str, Optional[float]],
) -> str:
    lines: List[str] = []
    lines.append("# RAGAS evaluation — original RAG")
    lines.append("")
    lines.append(f"- **Run at:** `{started_at.isoformat(timespec='seconds')}`")
    lines.append(f"- **RAG API:** `{api_base}`")
    lines.append(f"- **Judge LLM base URL:** `{llm_base_url}`")
    lines.append(f"- **Judge model:** `{llm_model}`")
    lines.append(f"- **top_k:** `{top_k}`")
    lines.append(f"- **Questions:** `{len(outcomes)}`")
    lines.append(f"- **Total duration:** `{duration_s:.1f}s`")
    lines.append(f"- **RAG status:** `{json.dumps(rag_status, ensure_ascii=False, sort_keys=True)}`")
    lines.append(f"- **Judge status:** `{json.dumps(judge_status, ensure_ascii=False, sort_keys=True)}`")
    lines.append("")
    lines.append("## Aggregate metrics")
    lines.append("")
    lines.append("| Metric | Mean |")
    lines.append("|---|---:|")
    for metric_name, mean_value in aggregates.items():
        lines.append(f"| `{metric_name}` | {_format_metric_value(mean_value)} |")
    lines.append("")
    lines.append("## Questions")
    lines.append("")
    for outcome in outcomes:
        lines.append(
            f"- [Q{outcome.question.number}]({'#q-' + str(outcome.question.number)})"
            f" — _{outcome.question.category}_ — {outcome.question.text}"
        )
    lines.append("")
    lines.append("---")
    lines.append("")

    for outcome in outcomes:
        q = outcome.question
        lines.append(f'<a id="q-{q.number}"></a>')
        lines.append(f"## Q{q.number}. {q.text}")
        lines.append("")
        lines.append(f"- **Category:** {q.category}")
        lines.append(f"- **RAG latency:** `{outcome.latency_s:.2f}s`")
        if outcome.rag_error:
            lines.append(f"- **RAG error:** `{outcome.rag_error}`")
        if outcome.ragas_error:
            lines.append(f"- **RAGAS error:** `{outcome.ragas_error}`")
        if outcome.metric_scores:
            metric_blob = ", ".join(
                f"{name}={_format_metric_value(value)}"
                for name, value in outcome.metric_scores.items()
            )
            lines.append(f"- **Metric scores:** `{metric_blob}`")
        lines.append("")
        lines.append("### Answer")
        lines.append("")
        lines.append(outcome.answer if outcome.answer else "_(empty)_")
        lines.append("")
        lines.append(f"### Retrieved contexts ({len(outcome.retrieved_contexts)})")
        lines.append("")
        if outcome.scored_sources:
            for idx, src in enumerate(outcome.scored_sources, 1):
                lines.extend(_render_source_row(idx, src))
            lines.append("")
        else:
            lines.append("_(none)_")
            lines.append("")
        lines.append("---")
        lines.append("")
    return "\n".join(lines)


def compute_aggregates(outcomes: List[EvalOutcome]) -> Dict[str, Optional[float]]:
    metric_names = sorted({name for outcome in outcomes for name in outcome.metric_scores})
    aggregates: Dict[str, Optional[float]] = {}
    for name in metric_names:
        values = [
            value
            for outcome in outcomes
            for metric_name, value in outcome.metric_scores.items()
            if metric_name == name and value is not None and math.isfinite(value)
        ]
        aggregates[name] = statistics.fmean(values) if values else None
    return aggregates


def main() -> int:
    parser = argparse.ArgumentParser(description="Run reference-free RAGAS evaluation on the original RAG API (local LLM only).")
    parser.add_argument("--api", default=DEFAULT_API, help=f"RAG API base URL (default: {DEFAULT_API})")
    parser.add_argument("--questions", default=str(DEFAULT_QUESTIONS), help="Path to the markdown questions file.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="Directory to write result artifacts into.")
    parser.add_argument("--top-k", type=int, default=10, help="top_k passed to the RAG query endpoint.")
    parser.add_argument("--query-timeout", type=int, default=900,
                        help="Per-query HTTP timeout in seconds for calls to the RAG API (default: 900).")
    parser.add_argument("--ragas-timeout", type=int, default=0,
                        help="RAGAS per-metric timeout in seconds. 0 (default) disables the timeout; local judges are often too slow for a bounded wall clock.")
    parser.add_argument("--limit", type=int, default=None, help="Only run the first N questions.")
    parser.add_argument("--only-category", default=None, help="Restrict to questions whose category contains this substring.")
    parser.add_argument("--llm-base-url", default=DEFAULT_LLM_BASE_URL,
                        help=f"OpenAI-compatible base URL for the local evaluation LLM (default: {DEFAULT_LLM_BASE_URL})")
    parser.add_argument("--llm-api-key", default=DEFAULT_LLM_API_KEY,
                        help="API key for the local evaluation LLM.")
    parser.add_argument("--llm-model", default=DEFAULT_LLM_MODEL,
                        help=f"Model name for the local evaluation LLM (default: {DEFAULT_LLM_MODEL}).")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s | %(message)s",
    )

    api_base = args.api.rstrip("/")
    llm_model = args.llm_model
    llm_base_url = args.llm_base_url.rstrip("/")
    query_timeout = args.query_timeout if args.query_timeout > 0 else 900
    ragas_timeout: Optional[int] = args.ragas_timeout if args.ragas_timeout > 0 else None
    questions_path = Path(args.questions)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    _log_progress(f"→ Parsing questions from {questions_path}")
    questions = parse_questions(questions_path)
    if args.only_category:
        needle = args.only_category.lower()
        questions = [q for q in questions if needle in q.category.lower()]
    if args.limit is not None:
        questions = questions[: args.limit]
    if not questions:
        logger.error("No questions to run after filtering.")
        return 2
    _log_progress(f"→ {len(questions)} question(s) selected")

    _log_progress(f"→ Checking RAG service at {api_base}")
    try:
        rag_status = _check_rag_service(api_base)
        _log_progress(f"✓ RAG service reachable: {rag_status}")
    except Exception as exc:
        logger.error("Cannot reach RAG service at %s: %s", api_base, exc)
        return 3

    _log_progress(f"→ Checking local LLM at {llm_base_url}")
    try:
        _check_local_llm(llm_base_url)
        _log_progress(f"✓ Local evaluation LLM reachable at {llm_base_url} (model={llm_model})")
    except Exception as exc:
        logger.error("Cannot reach local LLM at %s: %s", llm_base_url, exc)
        return 4
    judge_status = _summarize_judge_status(llm_base_url, llm_model)
    llm = ChatOpenAI(
        model=llm_model,
        base_url=llm_base_url,
        api_key=args.llm_api_key,
        temperature=0,
    )

    outcomes: List[EvalOutcome] = []
    started_at = datetime.now()
    run_t0 = time.monotonic()

    _log_progress(
        f"→ Running {len(questions)} question(s) against {api_base} with judge model {llm_model}"
    )

    with requests.Session() as session:
        for idx, question in enumerate(questions, 1):
            _log_progress(
                f"[{idx}/{len(questions)}] {question.category} — Q{question.number}: {question.text[:80]}"
            )
            _log_progress(f"  → Querying RAG (top_k={args.top_k}, timeout={query_timeout}s)")
            q_t0 = time.monotonic()
            raw = run_query(api_base, question, args.top_k, query_timeout, session)
            _log_progress(
                f"  ← RAG returned in {time.monotonic() - q_t0:.2f}s "
                f"(sources={len(raw.sources)}, answer_chars={len(raw.answer or '')})"
            )
            outcome = EvalOutcome(
                question=question,
                answer=raw.answer,
                sources=raw.sources,
                scored_sources=raw.sources[:DEFAULT_RAGAS_TOP_CONTEXTS],
                latency_s=raw.latency_s,
                rag_error=raw.error,
            )
            outcome.retrieved_contexts = [
                _source_to_context(src) for src in outcome.scored_sources
            ]

            if outcome.rag_error:
                _log_progress(f"  ✗ RAG error: {outcome.rag_error}")
                outcomes.append(outcome)
                continue

            if not outcome.retrieved_contexts:
                outcome.ragas_error = "No retrieved contexts were returned by the RAG API."
                _log_progress(f"  ⚠ RAGAS skipped: {outcome.ragas_error}")
                outcomes.append(outcome)
                continue

            _log_progress(f"  → Scoring with RAGAS (contexts={len(outcome.retrieved_contexts)})")
            ragas_t0 = time.monotonic()
            try:
                metric_scores = evaluate_sample(_build_sample(outcome), llm, ragas_timeout)
                outcome.metric_scores = metric_scores
                metric_blob = ", ".join(
                    f"{name}={_format_metric_value(value)}" for name, value in metric_scores.items()
                )
                _log_progress(
                    f"  ✓ scored in {time.monotonic() - ragas_t0:.2f}s: {metric_blob}"
                )
            except Exception as exc:
                outcome.ragas_error = f"{type(exc).__name__}: {exc}"
                _log_progress(f"  ✗ RAGAS error: {outcome.ragas_error}")

            outcomes.append(outcome)

    duration_s = time.monotonic() - run_t0
    aggregates = compute_aggregates(outcomes)
    rag_status_summary = _summarize_rag_status(rag_status)

    stamp = started_at.strftime("%Y-%m-%d_%H%M%S")
    json_path = out_dir / f"results_{stamp}_ragas.json"
    md_path = out_dir / f"results_{stamp}_ragas.md"

    payload = {
        "api": api_base,
        "llm_base_url": llm_base_url,
        "llm_model": llm_model,
        "judge_provider": "local",
        "top_k": args.top_k,
        "started_at": started_at.isoformat(),
        "duration_s": duration_s,
        "rag_status": rag_status_summary,
        "judge_status": judge_status,
        "aggregate_metrics": aggregates,
        "results": [
            {
                "question": asdict(outcome.question),
                "answer": outcome.answer,
                "scored_sources": outcome.scored_sources,
                "retrieved_contexts": outcome.retrieved_contexts,
                "latency_s": outcome.latency_s,
                "rag_error": outcome.rag_error,
                "ragas_error": outcome.ragas_error,
                "metric_scores": outcome.metric_scores,
            }
            for outcome in outcomes
        ],
    }
    _log_progress(f"→ Writing results to {json_path} and {md_path}")
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    md_path.write_text(
        render_markdown(
            outcomes,
            api_base=api_base,
            llm_base_url=llm_base_url,
            llm_model=llm_model,
            top_k=args.top_k,
            started_at=started_at,
            duration_s=duration_s,
            rag_status=rag_status_summary,
            judge_status=judge_status,
            aggregates=aggregates,
        ),
        encoding="utf-8",
    )

    rag_errors = sum(1 for outcome in outcomes if outcome.rag_error)
    ragas_errors = sum(1 for outcome in outcomes if outcome.ragas_error)
    _log_progress(
        f"Done — {len(outcomes)} questions, {rag_errors} RAG errors, "
        f"{ragas_errors} RAGAS errors, duration={duration_s:.1f}s"
    )
    _log_progress(f"  wrote {md_path}")
    _log_progress(f"  wrote {json_path}")
    return 0 if rag_errors == 0 and ragas_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
