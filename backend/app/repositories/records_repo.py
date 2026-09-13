"""SQL for the mode registry and per-user mode records."""
from ..core import db


def list_modes() -> list:
    return db.query_all(
        "SELECT mode_id, label, unlock_level FROM modes ORDER BY unlock_level, mode_id"
    )


def mode_exists(mode_id: str) -> bool:
    return db.query_one("SELECT 1 AS ok FROM modes WHERE mode_id = %s", (mode_id,)) is not None


def upsert_mode(mode_id: str, label: str, unlock_level: int) -> None:
    db.execute(
        """
        INSERT INTO modes (mode_id, label, unlock_level)
        VALUES (%s, %s, %s)
        ON CONFLICT (mode_id) DO UPDATE SET label = EXCLUDED.label,
            unlock_level = EXCLUDED.unlock_level
        """,
        (mode_id, label, unlock_level),
    )


def list_records(user_id: str) -> list:
    return db.query_all(
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


def upsert_record(user_id: str, mode_id: str, best_score: int,
                  plays_delta: int, wins_delta: int, updated_at: int):
    return db.query_one(
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
        (user_id, mode_id, best_score, plays_delta, wins_delta, updated_at),
    )
