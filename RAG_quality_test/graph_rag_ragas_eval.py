"""
RAGAS evaluation runner for the GraphRAG service.

This mirrors ``rag_ragas_eval.py`` but targets the GraphRAG HTTP API on port
3007 by default. It converts GraphRAG query outputs into reference-free RAGAS
samples using either retrieved chunks (local mode) or community contributions
(global mode). The evaluation LLM is a local OpenAI-compatible endpoint such
as Ollama on ``http://localhost:11434/v1``.

Usage
-----
    python graph_rag_ragas_eval.py --limit 1 --verbose
    python graph_rag_ragas_eval.py --mode auto
    python graph_rag_ragas_eval.py --mode global
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
from langchain_core.callbacks import BaseCallbackHandler
from langchain_openai import ChatOpenAI

os.environ.setdefault("RAGAS_DO_NOT_TRACK", "true")

from ragas.dataset_schema import EvaluationDataset, SingleTurnSample
from ragas.evaluation import evaluate
from ragas.metrics._context_precision import LLMContextPrecisionWithoutReference
from ragas.metrics._faithfulness import Faithfulness
from ragas.run_config import RunConfig

from graph_rag_quality_test import parse_questions, run_query, Question

CURRENT_DIR = Path(__file__).resolve().parent

DEFAULT_API = os.environ.get("GRAPHRAG_API_BASE", "http://localhost:3007").rstrip("/")
DEFAULT_QUESTIONS = CURRENT_DIR / "questions.md"
DEFAULT_OUT_DIR = CURRENT_DIR / "results"
DEFAULT_LLM_BASE_URL = os.environ.get("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1").rstrip("/")
DEFAULT_LLM_API_KEY = os.environ.get("LOCAL_LLM_API_KEY", "ollama")
DEFAULT_LLM_MODEL = os.environ.get("LLM_MODEL_NAME", "gemma4:31b")
DEFAULT_RAGAS_TOP_CONTEXTS = 3

logger = logging.getLogger("graph_rag_ragas_eval")


class TokenAccumulator(BaseCallbackHandler):
    """Accumulate token usage reported by the local OpenAI-compatible LLM."""

    def __init__(self) -> None:
        self.prompt_tokens = 0
        self.completion_tokens = 0
        self.total_tokens = 0
        self.call_count = 0

    def _extract_usage(self, response: Any) -> Dict[str, int]:
        usage: Dict[str, Any] = {}
        llm_output = getattr(response, "llm_output", None) or {}
        if isinstance(llm_output, dict):
            usage = llm_output.get("token_usage") or llm_output.get("usage") or {}
        if not usage:
            generations = getattr(response, "generations", None) or []
            for gen_list in generations:
                for gen in gen_list:
                    info = getattr(gen, "generation_info", None) or {}
                    if isinstance(info, dict):
                        cand = info.get("token_usage") or info.get("usage") or {}
                        if cand:
                            usage = cand
                            break
                    message = getattr(gen, "message", None)
                    if message is not None:
                        meta = getattr(message, "usage_metadata", None) or {}
                        if meta:
                            usage = {
                                "prompt_tokens": meta.get("input_tokens", 0),
                                "completion_tokens": meta.get("output_tokens", 0),
                                "total_tokens": meta.get("total_tokens", 0),
                            }
                            break
                if usage:
                    break
        return {
            "prompt_tokens": int(usage.get("prompt_tokens", 0) or 0),
            "completion_tokens": int(usage.get("completion_tokens", 0) or 0),
            "total_tokens": int(usage.get("total_tokens", 0) or 0),
        }

    def on_llm_end(self, response: Any, **kwargs: Any) -> None:  # type: ignore[override]
        self.call_count += 1
        usage = self._extract_usage(response)
        self.prompt_tokens += usage["prompt_tokens"]
        self.completion_tokens += usage["completion_tokens"]
        total = usage["total_tokens"] or (usage["prompt_tokens"] + usage["completion_tokens"])
        self.total_tokens += total

    def snapshot(self) -> Dict[str, int]:
        return {
            "prompt_tokens": self.prompt_tokens,
            "completion_tokens": self.completion_tokens,
            "total_tokens": self.total_tokens,
            "call_count": self.call_count,
        }


def _log_progress(msg: str) -> None:
    """Print a progress line immediately (flushed) in addition to logging."""
    print(msg, flush=True)
    logger.info(msg)


@dataclass
class EvalOutcome:
    question: Question
    answer: str = ""
    resolved_mode: Optional[str] = None
    chunks: List[Dict[str, Any]] = field(default_factory=list)
    communities: List[Dict[str, Any]] = field(default_factory=list)
    scored_evidence: List[Dict[str, Any]] = field(default_factory=list)
    retrieved_contexts: List[str] = field(default_factory=list)
    seeds: List[Any] = field(default_factory=list)
    subgraph_nodes: Any = None
    candidate_count: Optional[int] = None
    latency_s: float = 0.0
    rag_error: Optional[str] = None
    ragas_error: Optional[str] = None
    metric_scores: Dict[str, Optional[float]] = field(default_factory=dict)
    token_usage: Dict[str, int] = field(default_factory=dict)


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


def _community_to_context(comm: Dict[str, Any]) -> str:
    parts: List[str] = []
    title = str(comm.get("title") or "").strip()
    if title:
        parts.append(f"title: {title}")
    theme = str(comm.get("theme") or "").strip()
    if theme:
        parts.append(f"theme: {theme}")
    contribution = str(comm.get("contribution") or "").strip()
    if contribution:
        parts.append(f"contribution: {contribution}")
    papers = comm.get("papers") or []
    if isinstance(papers, list) and papers:
        parts.append("papers: " + ", ".join(str(p) for p in papers[:8]))
    if parts:
        return "\n".join(parts)
    return json.dumps(comm, ensure_ascii=False)


def _chunk_to_context(chunk: Dict[str, Any]) -> str:
    text = str(chunk.get("text") or "").strip()
    if text:
        return text

    meta = chunk.get("metadata") or {}
    parts: List[str] = []
    for key in ("paper_title", "section", "content_type", "function_name"):
        value = str(meta.get(key) or "").strip()
        if value:
            parts.append(f"{key}: {value}")
    if parts:
        return " | ".join(parts)
    return json.dumps(chunk, ensure_ascii=False)


def _build_metrics() -> List[Any]:
    return [
        Faithfulness(),
        LLMContextPrecisionWithoutReference(),
    ]


def _build_sample(outcome: EvalOutcome) -> SingleTurnSample:
    return SingleTurnSample(
        user_input=outcome.question.text,
        response=outcome.answer,
        retrieved_contexts=outcome.retrieved_contexts,
    )


def _check_graph_service(api_base: str) -> Dict[str, Any]:
    resp = requests.get(f"{api_base}/api/status", timeout=20)
    resp.raise_for_status()
    payload = resp.json()
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected /api/status payload: {payload!r}")
    return payload


def _check_local_llm(base_url: str) -> Dict[str, Any]:
    resp = requests.get(f"{base_url}/models", timeout=10)
    if resp.ok:
        payload = resp.json()
        if isinstance(payload, dict):
            return payload

    root_base = base_url[:-3] if base_url.endswith("/v1") else base_url
    fallback = requests.get(f"{root_base}/api/tags", timeout=10)
    fallback.raise_for_status()
    payload = fallback.json()
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected LLM health payload: {payload!r}")
    return payload


def _summarize_graph_status(payload: Dict[str, Any]) -> Dict[str, Any]:
    summary = {
        "service": payload.get("service", "graphRag"),
        "db_path": payload.get("db_path"),
    }
    for key in ("graph_built", "papers_count", "chunks_count", "community_count", "node_count", "edge_count"):
        if key in payload:
            summary[key] = payload.get(key)
    return summary


def _summarize_judge_status(llm_base_url: str, llm_model: str) -> Dict[str, Any]:
    return {
        "provider": "local",
        "model": llm_model,
        "base_url": llm_base_url,
        "reachable": True,
    }


def evaluate_sample(sample: SingleTurnSample, llm: ChatOpenAI, timeout: Optional[int]) -> Dict[str, Optional[float]]:
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


def _render_evidence_row(idx: int, item: Dict[str, Any], resolved_mode: Optional[str]) -> List[str]:
    if resolved_mode == "global":
        header_parts = [f"**[{idx}] community**"]
        if item.get("community_id") is not None:
            header_parts.append(f"id: `{item.get('community_id')}`")
        if item.get("title"):
            header_parts.append(f"title: `{item.get('title')}`")
        if item.get("theme"):
            header_parts.append(f"theme: `{item.get('theme')}`")
        if item.get("score") is not None:
            header_parts.append(f"score: `{item.get('score')}`")
        lines = ["- " + " · ".join(header_parts)]
        for line in _safe(item.get("contribution"), limit=700).splitlines():
            lines.append(f"    > {line}")
        papers = item.get("papers") or []
        if papers:
            lines.append(f"    > papers: {', '.join(str(p) for p in papers[:8])}")
        return lines

    meta = item.get("metadata") or {}
    header_parts = [f"**[{idx}] chunk**"]
    for key in ("content_type", "paper_title", "section", "function_name"):
        value = str(meta.get(key) or "").strip()
        if value:
            header_parts.append(f"{key}: `{value}`")
    if item.get("id"):
        header_parts.append(f"id: `{item.get('id')}`")
    lines = ["- " + " · ".join(header_parts)]
    for line in _safe(item.get("text"), limit=700).splitlines():
        lines.append(f"    > {line}")
    return lines


def render_markdown(
    outcomes: List[EvalOutcome],
    *,
    api_base: str,
    query_mode: str,
    extra_params: Dict[str, int],
    llm_base_url: str,
    llm_model: str,
    started_at: datetime,
    duration_s: float,
    graph_status: Dict[str, Any],
    judge_status: Dict[str, Any],
    aggregates: Dict[str, Optional[float]],
    token_totals: Dict[str, int],
) -> str:
    lines: List[str] = []
    lines.append("# RAGAS evaluation — GraphRAG")
    lines.append("")
    lines.append(f"- **Run at:** `{started_at.isoformat(timespec='seconds')}`")
    lines.append(f"- **GraphRAG API:** `{api_base}`")
    lines.append(f"- **Query mode:** `{query_mode}`")
    if extra_params:
        params_str = ", ".join(f"{k}={v}" for k, v in extra_params.items())
        lines.append(f"- **Graph params:** `{params_str}`")
    lines.append(f"- **Judge LLM base URL:** `{llm_base_url}`")
    lines.append(f"- **Judge model:** `{llm_model}`")
    lines.append(f"- **Questions:** `{len(outcomes)}`")
    lines.append(f"- **Total duration:** `{duration_s:.1f}s`")
    lines.append(f"- **GraphRAG status:** `{json.dumps(graph_status, ensure_ascii=False, sort_keys=True)}`")
    lines.append(f"- **Judge status:** `{json.dumps(judge_status, ensure_ascii=False, sort_keys=True)}`")
    lines.append(
        f"- **Judge token usage:** prompt=`{token_totals.get('prompt_tokens', 0)}`, "
        f"completion=`{token_totals.get('completion_tokens', 0)}`, "
        f"total=`{token_totals.get('total_tokens', 0)}`, "
        f"calls=`{token_totals.get('call_count', 0)}`"
    )
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
        lines.append(f"- **GraphRAG latency:** `{outcome.latency_s:.2f}s`")
        if outcome.resolved_mode:
            lines.append(f"- **Resolved mode:** `{outcome.resolved_mode}`")
        if outcome.subgraph_nodes is not None:
            lines.append(f"- **Subgraph nodes:** `{outcome.subgraph_nodes}`")
        if outcome.candidate_count is not None:
            lines.append(f"- **Candidate count:** `{outcome.candidate_count}`")
        if outcome.rag_error:
            lines.append(f"- **GraphRAG error:** `{outcome.rag_error}`")
        if outcome.ragas_error:
            lines.append(f"- **RAGAS error:** `{outcome.ragas_error}`")
        if outcome.metric_scores:
            metric_blob = ", ".join(
                f"{name}={_format_metric_value(value)}"
                for name, value in outcome.metric_scores.items()
            )
            lines.append(f"- **Metric scores:** `{metric_blob}`")
        if outcome.token_usage:
            tu = outcome.token_usage
            lines.append(
                f"- **Judge tokens:** prompt=`{tu.get('prompt_tokens', 0)}`, "
                f"completion=`{tu.get('completion_tokens', 0)}`, "
                f"total=`{tu.get('total_tokens', 0)}`, "
                f"calls=`{tu.get('call_count', 0)}`"
            )
        lines.append("")
        lines.append("### Answer")
        lines.append("")
        lines.append(outcome.answer if outcome.answer else "_(empty)_")
        lines.append("")
        lines.append(f"### Scored evidence ({len(outcome.scored_evidence)})")
        lines.append("")
        if outcome.scored_evidence:
            for idx, item in enumerate(outcome.scored_evidence, 1):
                lines.extend(_render_evidence_row(idx, item, outcome.resolved_mode))
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
    parser = argparse.ArgumentParser(description="Run reference-free RAGAS evaluation on the GraphRAG API (local LLM only).")
    parser.add_argument("--api", default=DEFAULT_API, help=f"GraphRAG API base URL (default: {DEFAULT_API})")
    parser.add_argument("--questions", default=str(DEFAULT_QUESTIONS), help="Path to the markdown questions file.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="Directory to write result artifacts into.")
    parser.add_argument("--mode", default="auto", choices=["auto", "local", "global"], help="GraphRAG query mode.")
    parser.add_argument("--n-hop", type=int, default=None, help="Subgraph hop radius (local mode).")
    parser.add_argument("--max-chunks", type=int, default=None, help="Max chunks pulled from the subgraph.")
    parser.add_argument("--candidate-top-k", type=int, default=None, help="Seed-candidate top_k for local search.")
    parser.add_argument("--keep-top-k", type=int, default=None, help="Chunks kept after reranking.")
    parser.add_argument("--max-generation-tokens", type=int, default=None, help="LLM generation cap.")
    parser.add_argument("--query-timeout", type=int, default=900,
                        help="Per-query HTTP timeout in seconds for calls to the GraphRAG API (default: 900).")
    parser.add_argument("--ragas-timeout", type=int, default=0,
                        help="RAGAS per-metric timeout in seconds. 0 (default) disables the timeout; local judges are often too slow for a bounded wall clock.")
    parser.add_argument("--limit", type=int, default=None, help="Only run the first N questions.")
    parser.add_argument("--only-category", default=None,
                        help="Restrict to questions whose category contains this substring.")
    parser.add_argument("--llm-base-url", default=DEFAULT_LLM_BASE_URL,
                        help=f"OpenAI-compatible base URL for the local evaluation LLM (default: {DEFAULT_LLM_BASE_URL})")
    parser.add_argument("--llm-api-key", default=DEFAULT_LLM_API_KEY, help="API key for the local evaluation LLM.")
    parser.add_argument("--llm-model", default=DEFAULT_LLM_MODEL,
                        help=f"Model name for the local evaluation LLM (default: {DEFAULT_LLM_MODEL}).")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s | %(message)s",
    )

    llm_model = args.llm_model
    llm_base_url = args.llm_base_url.rstrip("/")

    api_base = args.api.rstrip("/")
    query_timeout = args.query_timeout if args.query_timeout > 0 else 900
    ragas_timeout: Optional[int] = args.ragas_timeout if args.ragas_timeout > 0 else None
    questions_path = Path(args.questions)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

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

    _log_progress(f"→ Checking GraphRAG service at {api_base}")
    try:
        graph_status = _check_graph_service(api_base)
        _log_progress(f"✓ GraphRAG service reachable: {graph_status}")
        if graph_status.get("graph_built") is False:
            logger.warning("GraphRAG reports graph_built=False — queries may 409 until POST /api/build.")
    except Exception as exc:
        logger.error("Cannot reach GraphRAG service at %s: %s", api_base, exc)
        return 3

    _log_progress(f"→ Checking local LLM at {llm_base_url}")
    try:
        _check_local_llm(llm_base_url)
        _log_progress(f"✓ Local evaluation LLM reachable at {llm_base_url} (model={llm_model})")
    except Exception as exc:
        logger.error("Cannot reach local LLM at %s: %s", llm_base_url, exc)
        return 4
    judge_status = _summarize_judge_status(llm_base_url, llm_model)
    token_accumulator = TokenAccumulator()
    llm = ChatOpenAI(
        model=llm_model,
        base_url=llm_base_url,
        api_key=args.llm_api_key,
        temperature=0,
        callbacks=[token_accumulator],
    )

    outcomes: List[EvalOutcome] = []
    started_at = datetime.now()
    run_t0 = time.monotonic()

    _log_progress(
        f"→ Running {len(questions)} question(s) against {api_base} "
        f"(mode={args.mode}, params={extra_params or '{}'}) with judge model {llm_model}"
    )

    with requests.Session() as session:
        for idx, question in enumerate(questions, 1):
            _log_progress(
                f"[{idx}/{len(questions)}] {question.category} — Q{question.number}: {question.text[:80]}"
            )
            _log_progress(f"  → Querying GraphRAG (mode={args.mode}, timeout={query_timeout}s)")
            q_t0 = time.monotonic()
            raw = run_query(
                api_base=api_base,
                question=question,
                mode=args.mode,
                extra_params=extra_params,
                timeout=query_timeout,
                session=session,
            )
            _log_progress(
                f"  ← GraphRAG returned in {time.monotonic() - q_t0:.2f}s "
                f"(mode={raw.mode}, chunks={len(raw.chunks)}, communities={len(raw.communities)}, "
                f"answer_chars={len(raw.answer or '')})"
            )
            outcome = EvalOutcome(
                question=question,
                answer=raw.answer,
                resolved_mode=raw.mode,
                chunks=raw.chunks,
                communities=raw.communities,
                seeds=raw.seeds,
                subgraph_nodes=raw.subgraph_nodes,
                candidate_count=raw.candidate_count,
                latency_s=raw.latency_s,
                rag_error=raw.error,
            )

            if raw.chunks:
                outcome.scored_evidence = raw.chunks[:DEFAULT_RAGAS_TOP_CONTEXTS]
                outcome.retrieved_contexts = [_chunk_to_context(c) for c in outcome.scored_evidence]
            elif raw.communities:
                outcome.scored_evidence = raw.communities[:DEFAULT_RAGAS_TOP_CONTEXTS]
                outcome.retrieved_contexts = [_community_to_context(c) for c in outcome.scored_evidence]

            if outcome.rag_error:
                _log_progress(f"  ✗ GraphRAG error: {outcome.rag_error}")
                outcomes.append(outcome)
                continue

            if not outcome.retrieved_contexts:
                outcome.ragas_error = "No retrieved contexts were returned by the GraphRAG API."
                _log_progress(f"  ⚠ RAGAS skipped: {outcome.ragas_error}")
                outcomes.append(outcome)
                continue

            _log_progress(f"  → Scoring with RAGAS (contexts={len(outcome.retrieved_contexts)})")
            ragas_t0 = time.monotonic()
            tokens_before = token_accumulator.snapshot()
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
            tokens_after = token_accumulator.snapshot()
            outcome.token_usage = {
                key: tokens_after[key] - tokens_before[key]
                for key in ("prompt_tokens", "completion_tokens", "total_tokens", "call_count")
            }
            _log_progress(
                f"  · judge tokens (this q): prompt={outcome.token_usage['prompt_tokens']}, "
                f"completion={outcome.token_usage['completion_tokens']}, "
                f"total={outcome.token_usage['total_tokens']}, calls={outcome.token_usage['call_count']} "
                f"| cumulative total={tokens_after['total_tokens']}"
            )

            outcomes.append(outcome)

    duration_s = time.monotonic() - run_t0
    graph_status_summary = _summarize_graph_status(graph_status)
    aggregates = compute_aggregates(outcomes)
    token_totals = token_accumulator.snapshot()

    stamp = started_at.strftime("%Y-%m-%d_%H%M%S")
    json_path = out_dir / f"results_{stamp}_graph_rag_ragas.json"
    md_path = out_dir / f"results_{stamp}_graph_rag_ragas.md"

    payload = {
        "api": api_base,
        "mode": args.mode,
        "params": extra_params,
        "judge_provider": "local",
        "llm_base_url": llm_base_url,
        "llm_model": llm_model,
        "started_at": started_at.isoformat(),
        "duration_s": duration_s,
        "graph_status": graph_status_summary,
        "judge_status": judge_status,
        "aggregate_metrics": aggregates,
        "judge_token_usage": token_totals,
        "results": [
            {
                "question": asdict(outcome.question),
                "answer": outcome.answer,
                "resolved_mode": outcome.resolved_mode,
                "seeds": outcome.seeds,
                "subgraph_nodes": outcome.subgraph_nodes,
                "candidate_count": outcome.candidate_count,
                "scored_evidence": outcome.scored_evidence,
                "retrieved_contexts": outcome.retrieved_contexts,
                "latency_s": outcome.latency_s,
                "rag_error": outcome.rag_error,
                "ragas_error": outcome.ragas_error,
                "metric_scores": outcome.metric_scores,
                "token_usage": outcome.token_usage,
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
            query_mode=args.mode,
            extra_params=extra_params,
            llm_base_url=llm_base_url,
            llm_model=llm_model,
            started_at=started_at,
            duration_s=duration_s,
            graph_status=graph_status_summary,
            judge_status=judge_status,
            aggregates=aggregates,
            token_totals=token_totals,
        ),
        encoding="utf-8",
    )

    rag_errors = sum(1 for outcome in outcomes if outcome.rag_error)
    ragas_errors = sum(1 for outcome in outcomes if outcome.ragas_error)
    _log_progress(
        f"Done — {len(outcomes)} questions, {rag_errors} GraphRAG errors, "
        f"{ragas_errors} RAGAS errors, duration={duration_s:.1f}s"
    )
    _log_progress(
        f"Judge token totals: prompt={token_totals['prompt_tokens']}, "
        f"completion={token_totals['completion_tokens']}, "
        f"total={token_totals['total_tokens']}, calls={token_totals['call_count']}"
    )
    _log_progress(f"  wrote {md_path}")
    _log_progress(f"  wrote {json_path}")
    return 0 if rag_errors == 0 and ragas_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
