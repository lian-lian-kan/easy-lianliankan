"""Per-mode records: best score via max, plays/wins via increments."""
import time

from ..repositories import records_repo, score_repo
from . import anticheat


def list_records(user_id: str) -> list:
    return [dict(r) for r in records_repo.list_records(user_id)]


def record_result(user_id: str, mode_id: str, best_score: int, play: bool, win: bool):
    """Merge a finished run into the record row. Unknown modes are rejected;
    implausible scores are rejected the same way as intake (422 upstream)."""
    if not records_repo.mode_exists(mode_id):
        return None
    _gate(user_id, mode_id, best_score, win)
    row = records_repo.upsert_record(
        user_id, mode_id, max(0, int(best_score)),
        1 if play else 0, 1 if win else 0, _now_ms(),
    )
    if win:
        score_repo.insert_event(user_id, mode_id, best_score)
    return dict(row)


def _gate(user_id: str, mode_id: str, best_score: int, win: bool) -> None:
    if not anticheat.enabled():
        return
    if not anticheat.check_score(best_score):
        anticheat.audit(user_id, mode_id, best_score, "ceiling")
        raise ScoreRejected("score above the reachable ceiling")
    if win and not anticheat.check_pace(user_id, mode_id):
        anticheat.audit(user_id, mode_id, best_score, "pace")
        raise ScoreRejected("submissions too fast for a real run")


def seed_modes(modes: list) -> None:
    """Idempotently sync the mode registry from the game's data table."""
    for mode in modes:
        records_repo.upsert_mode(mode["mode_id"], mode["label"], int(mode.get("unlock_level", 1)))


def list_modes() -> list:
    return [dict(r) for r in records_repo.list_modes()]


def _now_ms() -> int:
    return int(time.time() * 1000)


class ScoreRejected(ValueError):
    pass
