"""Sliding-window rate limiter (pure logic, dependency-free, per-process).

Good enough for a single-instance casual-game API; swap the store for Redis
behind the same `allow()` signature if instances scale out.
"""
import time
from collections import defaultdict, deque


class SlidingWindowLimiter:
    def __init__(self, clock=time.monotonic):
        self._clock = clock
        self._hits = defaultdict(deque)

    def allow(self, key: str, limit: int, window_seconds: float) -> bool:
        """True when this call is within `limit` hits per window for `key`."""
        now = self._clock()
        window_start = now - window_seconds
        hits = self._hits[key]
        while hits and hits[0] <= window_start:
            hits.popleft()
        if len(hits) >= limit:
            return False
        hits.append(now)
        return True


_limiter = SlidingWindowLimiter()


def allow(key: str, limit: int, window_seconds: float) -> bool:
    return _limiter.allow(key, limit, window_seconds)


def reset() -> None:
    """Test hook: drop all buckets (limits are per-process by design)."""
    global _limiter
    _limiter = SlidingWindowLimiter()
