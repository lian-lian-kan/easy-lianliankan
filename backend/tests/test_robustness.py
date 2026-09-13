"""Pure-logic tests (no DB): rate limiter and the audit gate's canary."""
import subprocess
import sys

from app.core.ratelimit import SlidingWindowLimiter


def test_sliding_window_allows_within_limit():
    now = [100.0]
    limiter = SlidingWindowLimiter(clock=lambda: now[0])
    for _ in range(5):
        assert limiter.allow("ip1", limit=5, window_seconds=60)
    assert not limiter.allow("ip1", limit=5, window_seconds=60)
    assert limiter.allow("ip2", limit=5, window_seconds=60)


def test_sliding_window_frees_after_window():
    now = [100.0]
    limiter = SlidingWindowLimiter(clock=lambda: now[0])
    for _ in range(3):
        assert limiter.allow("ip1", limit=3, window_seconds=60)
    assert not limiter.allow("ip1", limit=3, window_seconds=60)
    now[0] += 61
    assert limiter.allow("ip1", limit=3, window_seconds=60)


def test_audit_gate_runs_clean():
    """The gate itself must pass on the current codebase."""
    result = subprocess.run(
        [sys.executable, "tools/backend_audit.py"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout
    assert "0 ERROR(S)" in result.stdout
