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


def test_cors_preflight_answers_game_page():
    """The H5 page on GitHub Pages must get its PUT preflight answered here."""
    from fastapi.testclient import TestClient
    from app.main import app
    client = TestClient(app)  # no context manager: no lifespan, no DB needed
    resp = client.options("/api/v1/progress", headers={
        "Origin": "https://lian-lian-kan.github.io",
        "Access-Control-Request-Method": "PUT",
        "Access-Control-Request-Headers": "authorization,content-type",
    })
    assert resp.status_code in (200, 204)
    assert resp.headers["access-control-allow-origin"] == "https://lian-lian-kan.github.io"
    assert "authorization" in resp.headers.get("access-control-allow-headers", "").lower()


def test_cors_ignores_unknown_origin():
    """Origins outside ALLOWED_ORIGINS get no allow-origin header back."""
    from fastapi.testclient import TestClient
    from app.main import app
    client = TestClient(app)
    resp = client.options("/api/v1/progress", headers={
        "Origin": "https://evil.example.com",
        "Access-Control-Request-Method": "PUT",
    })
    assert "access-control-allow-origin" not in resp.headers
