"""Smoke tests for LocalLLMClient.get_context_window().

Verifies all three resolution paths (env var → Ollama /api/show → default)
plus the per-instance cache. Matches the print-based style used by the
other tests in this directory.
"""
import os
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent))

from utils.llm_clients.local_llm import LocalLLMClient


def _fresh_client(base_url: str | None = None, model: str = "gemma4:31b") -> LocalLLMClient:
    """Build a client with no LLM_CONTEXT_WINDOW env var leaking in."""
    os.environ.pop("LLM_CONTEXT_WINDOW", None)
    return LocalLLMClient(
        model_name=model,
        base_url=base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1"),
    )


def test_env_var_overrides_everything():
    print("\n=== context_window: env var override ===")
    try:
        os.environ["LLM_CONTEXT_WINDOW"] = "12345"
        client = LocalLLMClient(model_name="gemma4:31b")
        n = client.get_context_window()
        assert n == 12345, f"expected 12345, got {n}"
        print(f"✓ env var honored: {n}")
        return True
    except Exception as e:
        print(f"✗ env-var test failed: {e}")
        return False
    finally:
        os.environ.pop("LLM_CONTEXT_WINDOW", None)


def test_ollama_autodetect():
    """Hits the live Ollama on localhost. Skips if Ollama is unreachable."""
    print("\n=== context_window: Ollama /api/show auto-detect ===")
    try:
        client = _fresh_client()
        if client._ollama_base is None:
            print("⊘ skipped (no Ollama endpoint detected at base_url)")
            return True
        n = client.get_context_window()
        assert n > 1000, f"expected a positive context length, got {n}"
        print(f"✓ Ollama returned context_length={n} for {client.model_name}")
        return True
    except Exception as e:
        print(f"✗ Ollama auto-detect failed: {e}")
        return False


def test_default_fallback():
    """Point at a non-Ollama URL; expect the explicit default."""
    print("\n=== context_window: default fallback ===")
    try:
        # 127.0.0.1:1 is reserved/unused — Ollama probe will fail fast.
        client = _fresh_client(base_url="http://127.0.0.1:1/v1")
        n = client.get_context_window(default=8192)
        assert n == 8192, f"expected 8192 default, got {n}"
        print(f"✓ default returned: {n}")
        return True
    except Exception as e:
        print(f"✗ default-fallback test failed: {e}")
        return False


def test_cached_across_calls():
    """Second call must return the cached value, not re-resolve."""
    print("\n=== context_window: cache ===")
    try:
        os.environ["LLM_CONTEXT_WINDOW"] = "777"
        client = LocalLLMClient(model_name="gemma4:31b")
        first = client.get_context_window()
        # Remove env var — a re-resolution would now fall through to Ollama
        # or the default; the cached value should still come back.
        os.environ.pop("LLM_CONTEXT_WINDOW", None)
        second = client.get_context_window()
        assert first == 777 and second == 777, f"expected 777/777, got {first}/{second}"
        print(f"✓ cached value stable across calls: {second}")
        return True
    except Exception as e:
        print(f"✗ cache test failed: {e}")
        return False
    finally:
        os.environ.pop("LLM_CONTEXT_WINDOW", None)


def run_all_tests():
    print("=" * 60)
    print("LocalLLMClient.get_context_window() tests")
    print("=" * 60)

    results = {
        "env var override":   test_env_var_overrides_everything(),
        "Ollama auto-detect": test_ollama_autodetect(),
        "default fallback":   test_default_fallback(),
        "cache":              test_cached_across_calls(),
    }

    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    for name, ok in results.items():
        print(f"  {name}: {'✓ PASSED' if ok else '✗ FAILED'}")
    total, passed = len(results), sum(results.values())
    print(f"\nTotal: {passed}/{total}")
    return all(results.values())


if __name__ == "__main__":
    sys.exit(0 if run_all_tests() else 1)
