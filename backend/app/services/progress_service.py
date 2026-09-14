"""Cloud save: one JSONB snapshot per user with stale-write rejection."""
import json
import time

from ..core import config
from ..repositories import progress_repo
from . import score_intake

MAX_FUTURE_SKEW_MS = 5 * 60 * 1000


def get_progress(user_id: str):
    row = progress_repo.get_snapshot(user_id)
    if row is None:
        return None
    return {"state": row["state"], "updated_at": int(row["updated_at"])}


def put_progress(user_id: str, state: dict, updated_at: int) -> dict:
    _require_sane_stamp(updated_at)
    if len(json.dumps(state)) > config.max_state_bytes():
        raise StateTooLarge()
    prev = progress_repo.get_snapshot(user_id)
    row = progress_repo.upsert_snapshot(user_id, state, updated_at)
    if row is not None:
        # Leaderboard intake runs only when the save actually landed, so a
        # stale retry can never re-record an already-gated score.
        score_intake.process(user_id, prev["state"] if prev else None, state)
        return {"saved": True, "updated_at": int(row["updated_at"])}
    stored = get_progress(user_id)
    return {"saved": False, "updated_at": stored["updated_at"] if stored else updated_at}


def _require_sane_stamp(updated_at: int) -> None:
    """Reject absurd stamps: a far-future write would brick all later saves."""
    ceiling = int(time.time() * 1000) + MAX_FUTURE_SKEW_MS
    if updated_at > ceiling:
        raise StaleTimestamp("updated_at is too far in the future")


class StateTooLarge(ValueError):
    pass


class StaleTimestamp(ValueError):
    pass
