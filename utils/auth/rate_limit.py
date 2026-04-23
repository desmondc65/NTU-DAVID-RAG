"""In-memory sliding-window rate limiter.

Safe for the current single-worker gunicorn setup. If the stack is ever
scaled to multiple workers, swap this for a Redis- or Postgres-backed
counter — the interface (``hit(key) -> bool``) is small on purpose.
"""
from __future__ import annotations

from collections import deque
from threading import Lock
from time import monotonic
from typing import Deque, Dict


class SlidingWindowCounter:
    def __init__(self, limit: int, window_seconds: int):
        self.limit = limit
        self.window = window_seconds
        self._events: Dict[str, Deque[float]] = {}
        self._lock = Lock()

    def hit(self, key: str) -> bool:
        """Record a hit. Return True if allowed, False if over the limit."""
        now = monotonic()
        cutoff = now - self.window
        with self._lock:
            events = self._events.get(key)
            if events is None:
                events = deque()
                self._events[key] = events
            while events and events[0] < cutoff:
                events.popleft()
            if len(events) >= self.limit:
                return False
            events.append(now)
            return True

    def reset(self, key: str) -> None:
        with self._lock:
            self._events.pop(key, None)


# Defaults from the design doc. Tune via env later if needed.
LOGIN_PER_IP = SlidingWindowCounter(limit=5, window_seconds=60)
LOGIN_PER_EMAIL = SlidingWindowCounter(limit=5, window_seconds=60)
REGISTER_PER_IP = SlidingWindowCounter(limit=30, window_seconds=3600)
