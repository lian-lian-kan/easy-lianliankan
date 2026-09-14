"""Storage maintenance: keep the append-only streams bounded.

Runs once per process startup (pod restart cadence bounds the worst case
between prunes). The DELETE is idempotent, so both replicas racing is fine.
"""
from ..repositories import score_repo

EVENTS_RETENTION_DAYS = 90


def prune_events(retention_days: int = EVENTS_RETENTION_DAYS) -> int:
    return score_repo.prune_expired(retention_days)
