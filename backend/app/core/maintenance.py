"""Storage maintenance: keep the append-only streams bounded.

Runs once per process startup (pod restart cadence bounds the worst case
between prunes). Every prune is an idempotent DELETE, so both replicas
racing is fine.
"""
from ..repositories import score_repo, users_repo

EVENTS_RETENTION_DAYS = 90


def prune_events(retention_days: int = EVENTS_RETENTION_DAYS) -> int:
    return score_repo.prune_expired(retention_days)


def prune_expired_tokens() -> int:
    """Tokens past their expiry are never selected again but would linger
    forever without this — every abandoned account leaves rows behind."""
    return users_repo.delete_expired_tokens()


def run_startup_maintenance():
    """Both prunes in one call; returns (tokens_removed, events_removed)."""
    tokens = prune_expired_tokens()
    events = prune_events(EVENTS_RETENTION_DAYS)
    return tokens, events
