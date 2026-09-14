"""Tiny JSON cache over Redis.

Every failure mode (no redis, outage, bad payload) degrades to a cache
miss so callers fall through to the database — the cache can never take
the API down.
"""
import json
import logging

from . import redis_client

logger = logging.getLogger("lianliankan")


def get_json(key: str):
    client = redis_client.get_client()
    if client is None:
        return None
    try:
        raw = client.get(key)
        return json.loads(raw) if raw else None
    except Exception:
        logger.info('{"event":"cache_get_failed","key":"%s"}', key)
        return None


def set_json(key: str, value, ttl_seconds: int) -> None:
    client = redis_client.get_client()
    if client is None:
        return
    try:
        client.setex(key, int(ttl_seconds), json.dumps(value))
    except Exception:
        logger.info('{"event":"cache_set_failed","key":"%s"}', key)


def drop(key: str) -> None:
    client = redis_client.get_client()
    if client is None:
        return
    try:
        client.delete(key)
    except Exception:
        logger.info('{"event":"cache_drop_failed","key":"%s"}', key)
