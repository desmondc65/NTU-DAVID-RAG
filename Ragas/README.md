# Ragas Evaluation Pack For NTU-DAVID-RAG

This folder is self-contained for evaluation.

It includes:
- `run_ragas_eval.py`: runs your live `RAGQueryEngine` and scores with Ragas.
- `gold_questions.jsonl`: starter gold evaluation set.
- `requirements-ragas.txt`: evaluator dependencies.

## 1. What this evaluates

The script evaluates the full query pipeline in:
- `utils/orchestrator/rag_query.py` (`RAGQueryEngine.query`)

For each gold question, it:
1. Runs retrieval + generation from your current DB.
2. Collects retrieved contexts and final answer.
3. Computes Ragas metrics:
   - `Faithfulness`
   - `ResponseRelevancy`
   - `LLMContextPrecisionWithReference`
   - `LLMContextRecall`
   - `AnswerCorrectness`

## 2. Prerequisites

You need all three:

1. A populated DB at `db/qdrant_data`  
   If missing, run:
   ```bash
   cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
   source .venv/bin/activate
   python -m tests.test_orch_store_to_db
   ```

2. Local LLM server running (OpenAI-compatible endpoint)  
   Default expected:
   - `http://localhost:8000/v1`
   - API key `local-dev-key`

3. Python env activated (`.venv`).

## 3. Install evaluator dependencies

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
source .venv/bin/activate
pip install -r Ragas/requirements-ragas.txt
```

## 4. Edit the gold set

Open and edit:
- `Ragas/gold_questions.jsonl`

Format per line:

```json
{"id":"q1","question":"...","reference_answer":"...","top_k":8}
```

Optional filter:

```json
{"id":"q_code","question":"...","reference_answer":"...","top_k":8,"where_filter":{"content_type":"code"}}
```

## 5. Run evaluation

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
source .venv/bin/activate
python Ragas/run_ragas_eval.py
```

## 6. Output files

Created under `Ragas/results/`:
- `predictions.jsonl`: question, generated answer, retrieved contexts.
- `scores.csv`: per-sample metric scores.
- `summary.json`: mean score for each metric.

## 7. Optional runtime overrides

If your judge model endpoint differs:

```bash
export RAGAS_JUDGE_MODEL="qwen3-next-80b-instruct-q8_0"
export RAGAS_JUDGE_BASE_URL="http://localhost:8000/v1"
export RAGAS_JUDGE_API_KEY="local-dev-key"
python Ragas/run_ragas_eval.py
```

If you want evaluator embeddings on GPU:

```bash
export RAGAS_EMBEDDING_DEVICE="cuda:0"
python Ragas/run_ragas_eval.py
```

## 8. How to interpret scores

- Low `Faithfulness`: answer is not well grounded in retrieved context.
- Low `ContextPrecision`: retriever/reranker is returning noisy chunks.
- Low `ContextRecall`: key evidence is missing from retrieval.
- Low `AnswerCorrectness`: final answer does not match your gold reference.

Use `predictions.jsonl` + `scores.csv` together to debug failures sample by sample.
