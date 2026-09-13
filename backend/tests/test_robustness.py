"""Pure-logic tests (no DB): memory rate limiter and the audit gate's canary."""
import subprocess
import sys

from app.core.ratelimit import memory_allow


def test_sliding_window_allows_within_limit():
    for i in range(5):
        assert memory_allow("ip1", now=100.0 + i, limit=5, window_seconds=60)
    assert not memory_allow("ip1", now=106.0, limit=5, window_seconds=60)
    assert memory_allow("ip2", now=100.0, limit=5, window_seconds=60)


def test_sliding_window_frees_after_window():
    for i in range(3):
        assert memory_allow("ip1", now=100.0 + i, limit=3, window_seconds=60)
    assert not memory_allow("ip1", now=130.0, limit=3, window_seconds=60)
    assert memory_allow("ip1", now=161.0, limit=3, window_seconds=60)


def test_audit_gate_runs_clean():
    """The gate itself must pass on the current codebase."""
    result = subprocess.run(
        [sys.executable, "tools/backend_audit.py"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout
    assert "0 ERROR(S)" in result.stdout


def test_redis_store_shared_window():
    """With Redis reachable, two store instances share the same bucket."""
    import os
    from app.core import redis_client
    from app.core.ratelimit import RedisStore
    if os.environ.get("SKIP_PG_TESTS") == "1" or redis_client.get_client() is None:
        import pytest
        pytest.skip("needs a reachable Redis (REDIS_URL)")
    redis_client.get_client().flushdb()
    store_a, store_b = RedisStore(), RedisStore()
    for _ in range(3):
        assert store_a.allow("t:shared", now=1000.0, limit=3, window_seconds=60)
    assert not store_b.allow("t:shared", now=1001.0, limit=3, window_seconds=60)
