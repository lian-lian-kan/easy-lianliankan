"""Per-mode records: best score via max, plays/wins via increments."""
from ..core import db


def list_records(user_id: str) -> list:
    rows = db.query_all(
        """
        SELECT m.mode_id, COALESCE(r.best_score, 0) AS best_score,
               COALESCE(r.plays, 0) AS plays, COALESCE(r.wins, 0) AS wins,
               COALESCE(r.updated_at, 0) AS updated_at
        FROM modes m
        LEFT JOIN mode_records r ON r.mode_id = m.mode_id AND r.user_id = %s
        ORDER BY m.mode_id
        """,
        (user_id,),
    )
    return [dict(r) for r in rows]


def record_result(user_id: str, mode_id: str, best_score: int, play: bool, win: bool) -> dict:
    """Merge a finished run into the record row. Unknown modes are rejected."""
    exists = db.query_one("SELECT 1 AS ok FROM modes WHERE mode_id = %s", (mode_id,))
    if exists is None:
        return None
    row = db.query_one(
        """
        INSERT INTO mode_records (user_id, mode_id, best_score, plays, wins, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (user_id, mode_id) DO UPDATE SET
            best_score = GREATEST(mode_records.best_score, EXCLUDED.best_score),
            plays = mode_records.plays + EXCLUDED.plays,
            wins = mode_records.wins + EXCLUDED.wins,
            updated_at = EXCLUDED.updated_at
        RETURNING best_score, plays, wins, updated_at
        """,
        (user_id, mode_id, max(0, best_score), 1 if play else 0, 1 if win else 0, _now_ms()),
    )
    return dict(row)


def seed_modes(modes: list) -> None:
    """Idempotently sync the mode registry from the game's data table."""
    for mode in modes:
        db.execute(
            """
            INSERT INTO modes (mode_id, label, unlock_level)
            VALUES (%s, %s, %s)
            ON CONFLICT (mode_id) DO UPDATE SET label = EXCLUDED.label,
                unlock_level = EXCLUDED.unlock_level
            """,
            (mode["mode_id"], mode["label"], int(mode.get("unlock_level", 1))),
        )


def list_modes() -> list:
    rows = db.query_all("SELECT mode_id, label, unlock_level FROM modes ORDER BY unlock_level, mode_id")
    return [dict(r) for r in rows]


def _now_ms() -> int:
    import time
    return int(time.time() * 1000)
