#!/usr/bin/env python3
"""
Run Ragas evaluation against the project's RAGQueryEngine.

Inputs:
- Gold file in JSONL format (question + reference answer)

Outputs:
- Per-sample scores CSV
- Summary JSON (mean score per metric)
- Predictions JSONL (question, answer, contexts)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd

# Ensure project root is importable
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from utils.orchestrator.rag_query import RAGQueryEngine

try:
    from ragas import EvaluationDataset, SingleTurnSample, evaluate
except ImportError:
    from ragas import evaluate
    from ragas.dataset_schema import EvaluationDataset, SingleTurnSample

from ragas.embeddings import LangchainEmbeddingsWrapper
from ragas.llms import LangchainLLMWrapper
from ragas.metrics import (
    AnswerCorrectness,
    Faithfulness,
    LLMContextPrecisionWithReference,
    LLMContextRecall,
    ResponseRelevancy,
)

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_openai import ChatOpenAI


def _load_gold(path: Path) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as f:
        for i, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            if "question" not in row or "reference_answer" not in row:
                raise ValueError(
                    f"Invalid gold row at line {i}: need 'question' and "
                    f"'reference_answer'."
                )
            rows.append(row)
    if not rows:
        raise ValueError(f"No rows found in gold file: {path}")
    return rows


def _save_json(path: Path, payload: Dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Ragas evaluation.")
    parser.add_argument(
        "--gold",
        type=str,
        default=str(SCRIPT_DIR / "gold_questions.jsonl"),
        help="Path to gold JSONL (default: Ragas/gold_questions.jsonl)",
    )
    parser.add_argument(
        "--db-path",
        type=str,
        default=str(PROJECT_ROOT / "db"),
        help="Path to DB directory containing qdrant_data",
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=8,
        help="Default retrieval top_k when not specified in each row",
    )
    parser.add_argument(
        "--out-dir",
        type=str,
        default=str(SCRIPT_DIR / "results"),
        help="Output directory for scores and reports",
    )
    parser.add_argument(
        "--judge-model",
        type=str,
        default=os.getenv("RAGAS_JUDGE_MODEL", "qwen3-next-80b-instruct-q8_0"),
        help="Judge LLM model name for Ragas metrics",
    )
    parser.add_argument(
        "--judge-base-url",
        type=str,
        default=os.getenv("RAGAS_JUDGE_BASE_URL", "http://localhost:8000/v1"),
        help="Judge LLM base URL (OpenAI-compatible)",
    )
    parser.add_argument(
        "--judge-api-key",
        type=str,
        default=os.getenv("RAGAS_JUDGE_API_KEY", "local-dev-key"),
        help="Judge LLM API key",
    )
    parser.add_argument(
        "--embedding-model",
        type=str,
        default=os.getenv("RAGAS_EMBEDDING_MODEL", "BAAI/bge-large-en-v1.5"),
        help="Embedding model for metrics that require embeddings",
    )
    parser.add_argument(
        "--embedding-device",
        type=str,
        default=os.getenv("RAGAS_EMBEDDING_DEVICE", "cpu"),
        help="Embedding device for evaluator embeddings (cpu or cuda:0)",
    )
    args = parser.parse_args()

    gold_path = Path(args.gold).resolve()
    db_path = Path(args.db_path).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    qdrant_dir = db_path / "qdrant_data"
    if not qdrant_dir.exists():
        raise FileNotFoundError(
            f"Qdrant directory not found: {qdrant_dir}\n"
            f"Run `python -m tests.test_orch_store_to_db` first."
        )

    rows = _load_gold(gold_path)
    print(f"Loaded {len(rows)} gold samples from: {gold_path}")

    print("Initializing RAG query engine...")
    engine = RAGQueryEngine(db_path=db_path)

    print("Building prediction set from live RAG pipeline...")
    prediction_rows: List[Dict[str, Any]] = []
    samples: List[SingleTurnSample] = []

    for idx, row in enumerate(rows, start=1):
        question = row["question"]
        reference = row["reference_answer"]
        top_k = int(row.get("top_k", args.top_k))
        where_filter = row.get("where_filter")

        print(f"[{idx}/{len(rows)}] {question}")
        output = engine.query(
            user_query=question,
            top_k=top_k,
            where_filter=where_filter,
        )

        contexts = [s["text"] for s in output["sources"]]
        answer = output["answer"]

        prediction_rows.append(
            {
                "id": row.get("id", f"q{idx}"),
                "question": question,
                "reference_answer": reference,
                "answer": answer,
                "retrieved_contexts": contexts,
                "top_k": top_k,
                "where_filter": where_filter,
            }
        )

        samples.append(
            SingleTurnSample(
                user_input=question,
                response=answer,
                retrieved_contexts=contexts,
                reference=reference,
            )
        )

    predictions_path = out_dir / "predictions.jsonl"
    with predictions_path.open("w", encoding="utf-8") as f:
        for row in prediction_rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"Saved predictions: {predictions_path}")

    dataset = EvaluationDataset(samples=samples)

    print("Initializing Ragas judge LLM and embeddings...")
    judge_llm = LangchainLLMWrapper(
        ChatOpenAI(
            model=args.judge_model,
            base_url=args.judge_base_url,
            api_key=args.judge_api_key,
            temperature=0.0,
        )
    )
    judge_embeddings = LangchainEmbeddingsWrapper(
        HuggingFaceEmbeddings(
            model_name=args.embedding_model,
            model_kwargs={"device": args.embedding_device},
            encode_kwargs={"normalize_embeddings": True},
        )
    )

    metrics = [
        Faithfulness(),
        ResponseRelevancy(),
        LLMContextPrecisionWithReference(),
        LLMContextRecall(),
        AnswerCorrectness(),
    ]

    print("Running Ragas evaluation...")
    result = evaluate(
        dataset=dataset,
        metrics=metrics,
        llm=judge_llm,
        embeddings=judge_embeddings,
    )

    result_df = result.to_pandas()
    scores_path = out_dir / "scores.csv"
    result_df.to_csv(scores_path, index=False)
    print(f"Saved per-sample scores: {scores_path}")

    metric_cols = [
        c
        for c in result_df.columns
        if c not in {"user_input", "response", "reference", "retrieved_contexts"}
        and pd.api.types.is_numeric_dtype(result_df[c])
    ]
    summary = {col: float(result_df[col].mean()) for col in metric_cols}
    summary["num_samples"] = len(result_df)

    summary_path = out_dir / "summary.json"
    _save_json(summary_path, summary)
    print(f"Saved summary: {summary_path}")

    print("\n=== Mean Metric Scores ===")
    for k, v in summary.items():
        if k == "num_samples":
            print(f"{k}: {v}")
        else:
            print(f"{k}: {v:.4f}")


if __name__ == "__main__":
    main()
