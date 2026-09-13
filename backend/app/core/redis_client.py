"""Lazy shared Redis connection (optional dependency at runtime).

When REDIS_ENABLED=0 or the server is unreachable, callers fall back to the
in-process implementations — the API must keep working degraded, never fail.
"""
import logging

import redis as redis_lib

from . import config

logger = logging.getLogger("lianliankan")
_client = None
_warned = False


def get_client():
    """Return a shared Redis client, or None when disabled/unreachable."""
    global _client, _warned
    if not config.redis_enabled():
        return None
    if _client is None:
        try:
            candidate = redis_lib.Redis.from_url(
                config.redis_url(), socket_connect_timeout=1, socket_timeout=1)
            candidate.ping()
            _client = candidate
            logger.info('{"event":"redis_connected"}')
        except Exception as exc:
            if not _warned:
                _warned = True
                logger.warning('{"event":"redis_unavailable","detail":"%s"}', exc)
            return None
    return _client


def ping() -> bool:
    client = get_client()
    if client is None:
        return False
    try:
        return bool(client.ping())
    except Exception:
        return False


def reset() -> None:
    """Test hook: drop the cached client."""
    global _client, _warned
    _client = None
    _warned = False
