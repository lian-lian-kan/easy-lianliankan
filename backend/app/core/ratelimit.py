"""Sliding-window rate limiting with pluggable stores.

Primary store is Redis (shared across instances, works on the K8S cluster);
when Redis is disabled or unreachable every call degrades to the in-process
memory store, so the API never fails because of the limiter.
"""
import time
import uuid
from collections import defaultdict, deque

from . import redis_client


class MemoryStore:
    """Single-process sliding window (default fallback)."""

    def __init__(self):
        self._hits = defaultdict(deque)

    def allow(self, key: str, now: float, limit: int, window_seconds: float) -> bool:
        window_start = now - window_seconds
        hits = self._hits[key]
        while hits and hits[0] <= window_start:
            hits.popleft()
        if len(hits) >= limit:
            return False
        hits.append(now)
        return True


class RedisStore:
    """Shared sliding window via a ZSET per bucket (score = unix seconds).

    Cleanup + count and add + expire are separate round trips, so concurrent
    instances can slightly over-admit under a race — acceptable for game-tier
    limits and strictly better than failing open.
    """

    def __init__(self, prefix: str = "ratelimit"):
        self._prefix = prefix

    def allow(self, key: str, now: float, limit: int, window_seconds: float) -> bool:
        client = redis_client.get_client()
        if client is None:
            raise RuntimeError("redis unavailable")
        zkey = f"{self._prefix}:{key}"
        member = f"{now}:{uuid.uuid4().hex}"
        pipe = client.pipeline(transaction=True)
        pipe.zremrangebyscore(zkey, 0, now - window_seconds)
        pipe.zcard(zkey)
        _, count = pipe.execute()
        if int(count) >= limit:
            return False
        pipe = client.pipeline(transaction=True)
        pipe.zadd(zkey, {member: now})
        pipe.expire(zkey, max(1, int(window_seconds)))
        pipe.execute()
        return True


_memory = MemoryStore()
_redis = RedisStore()


def allow(key: str, limit: int, window_seconds: float) -> bool:
    """True when this call is within `limit` hits per window for `key`."""
    try:
        return _redis.allow(key, time.time(), limit, window_seconds)
    except Exception:
        return _memory.allow(key, time.monotonic(), limit, window_seconds)


def memory_allow(key: str, now: float, limit: int, window_seconds: float) -> bool:
    """Direct memory-store access for deterministic unit tests."""
    return _memory.allow(key, now, limit, window_seconds)


def reset() -> None:
    """Test hook: drop in-process state (Redis buckets expire on their own)."""
    global _memory
    _memory = MemoryStore()
    redis_client.reset()
