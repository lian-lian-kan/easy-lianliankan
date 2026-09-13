"""Per-mode records: best score via max, plays/wins via increments."""
import time

from ..repositories import records_repo


def list_records(user_id: str) -> list:
    return [dict(r) for r in records_repo.list_records(user_id)]


def record_result(user_id: str, mode_id: str, best_score: int, play: bool, win: bool):
    """Merge a finished run into the record row. Unknown modes are rejected."""
    if not records_repo.mode_exists(mode_id):
        return None
    row = records_repo.upsert_record(
        user_id, mode_id, max(0, int(best_score)),
        1 if play else 0, 1 if win else 0, _now_ms(),
    )
    return dict(row)


def seed_modes(modes: list) -> None:
    """Idempotently sync the mode registry from the game's data table."""
    for mode in modes:
        records_repo.upsert_mode(mode["mode_id"], mode["label"], int(mode.get("unlock_level", 1)))


def list_modes() -> list:
    return [dict(r) for r in records_repo.list_modes()]


def _now_ms() -> int:
    return int(time.time() * 1000)
