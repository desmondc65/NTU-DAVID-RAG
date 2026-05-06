# RAG Quality Evaluation

This directory contains two evaluation paths for the vector RAG:

- `rag_quality_test.py`: report-style regression runner
- `rag_ragas_eval.py`: reference-free Ragas evaluation

`rag_ragas_eval.py` supports three judge providers:

- `local`: OpenAI-compatible local endpoint such as Ollama
- `openai`: hosted OpenAI API via `OPENAI_API_KEY`
- `gemini`: Gemini API via `GEMINI_API_KEY`

## Startup sequence

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG/docker/local_llm
docker compose -f docker-compose.gemma4_31b_ollama.yml up -d

cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG/docker/RAG
docker compose up -d --build rag-web
```

The expected endpoints are:

- RAG: `http://localhost:3006`
- local evaluation LLM: `http://localhost:11434/v1`

## Install evaluation dependencies

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
. .venv/bin/activate
pip install -r RAG_quality_test/requirements-ragas.txt
```

## Run Ragas evaluation

Full 30-question run:

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
. .venv/bin/activate
python RAG_quality_test/rag_ragas_eval.py
```

Single-question smoke test:

```bash
python RAG_quality_test/rag_ragas_eval.py --limit 1 --verbose
```

OpenAI judge example:

```bash
export OPENAI_API_KEY="your-key"
python RAG_quality_test/rag_ragas_eval.py --judge-provider openai --llm-model gpt-5.4 --limit 1
```

Gemini judge example:

```bash
export GEMINI_API_KEY="your-key"
python RAG_quality_test/rag_ragas_eval.py --judge-provider gemini --llm-model gemini-2.5-flash --limit 1
```

Useful options:

- `--api http://localhost:3006`
- `--questions RAG_quality_test/questions.md`
- `--out-dir RAG_quality_test/results`
- `--top-k 15`
- `--timeout 900`
- `--llm-base-url http://localhost:11434/v1`
- `--llm-model gemma4:31b`
- `--judge-provider openai`
- `--openai-api-key $OPENAI_API_KEY`
- `--judge-provider gemini`
- `--gemini-api-key $GEMINI_API_KEY`

## Output artifacts

Each run writes timestamped files to `RAG_quality_test/results`:

- `results_<timestamp>_ragas.json`
- `results_<timestamp>_ragas.md`

Artifacts include:

- raw answer text per question
- retrieved source payloads and extracted `retrieved_contexts`
- per-question metric scores
- per-question RAG or Ragas errors without aborting the full run
- aggregate metric means across successful evaluations
