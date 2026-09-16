"""token_hash -> user_id cache, with per-account session epochs.

Replaces the per-request PG lookup on the auth hot path. Only the token
hash ever reaches Redis. Entries carry the account's session epoch; when a
migration claim revokes an account's other sessions, the epoch bumps and
every cached token of that account instantly reads as a miss — the database
verdict rules instead of a stale cache entry. Every outage degrades to the
database lookup.
"""
from . import cache, security

TTL_SECONDS = 300


def _key(token: str) -> str:
    return f"tk:{security.hash_token(token)}"


def _epoch_key(user_id: str) -> str:
    return f"sess_epoch:{user_id}"


def session_epoch(user_id: str) -> int:
    value = cache.get_json(_epoch_key(user_id))
    return int(value) if value is not None else 0


def revoke_sessions(user_id: str) -> None:
    """Kill every cached session of the account at once (used by migration
    claims; the DB rows are revoked in the same transaction)."""
    cache.set_json(_epoch_key(user_id), session_epoch(user_id) + 1, TTL_SECONDS)


def lookup(token: str):
    """Cached user_id, or None on miss/stale. A stored entry whose epoch no
    longer matches the account's current epoch reads as a miss so the caller
    falls through to the database instead of trusting revoked identity."""
    entry = cache.get_json(_key(token))
    if not isinstance(entry, list) or len(entry) != 2:
        return None
    if int(entry[0]) != session_epoch(str(entry[1])):
        return None
    return str(entry[1])


def store(token: str, user_id: str) -> None:
    cache.set_json(_key(token), [session_epoch(user_id), user_id], TTL_SECONDS)


def invalidate(token: str) -> None:
    cache.drop(_key(token))
