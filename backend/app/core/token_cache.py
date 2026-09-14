"""token_hash -> user_id cache.

Replaces the per-request PG lookup on the auth hot path. Only the token
hash ever reaches Redis, and entries die with their token (refresh) or
after a short TTL — a revoked token outlives the cache by at most a
minute. Every outage degrades to the database lookup.
"""
from . import cache, security

TTL_SECONDS = 300


def _key(token: str) -> str:
    return f"tk:{security.hash_token(token)}"


def lookup(token: str):
    return cache.get_json(_key(token))


def store(token: str, user_id: str) -> None:
    cache.set_json(_key(token), user_id, TTL_SECONDS)


def invalidate(token: str) -> None:
    cache.drop(_key(token))
