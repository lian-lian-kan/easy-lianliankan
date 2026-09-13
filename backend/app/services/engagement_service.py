"""Achievements, weekly missions, wallet ledger and sign-ins."""
from ..core import db


# ── achievements ──

def list_achievements(user_id: str) -> list:
    rows = db.query_all(
        "SELECT achievement_id, unlocked_at FROM achievements WHERE user_id = %s ORDER BY unlocked_at",
        (user_id,),
    )
    return [dict(r) for r in rows]


def unlock(user_id: str, achievement_id: str) -> bool:
    """Idempotent; True when this call newly unlocked it."""
    row = db.query_one(
        """
        INSERT INTO achievements (user_id, achievement_id) VALUES (%s, %s)
        ON CONFLICT (user_id, achievement_id) DO NOTHING
        RETURNING achievement_id
        """,
        (user_id, achievement_id[:64]),
    )
    return row is not None


# ── weekly missions ──

def upsert_mission(user_id: str, week_key: int, mission_id: str, progress: int, claimed: bool) -> dict:
    row = db.query_one(
        """
        INSERT INTO missions_progress (user_id, week_key, mission_id, progress, claimed)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (user_id, week_key, mission_id) DO UPDATE SET
            progress = GREATEST(missions_progress.progress, EXCLUDED.progress),
            claimed = missions_progress.claimed OR EXCLUDED.claimed
        RETURNING mission_id, progress, claimed
        """,
        (user_id, week_key, mission_id[:64], max(0, progress), claimed),
    )
    return dict(row)


def list_missions(user_id: str, week_key: int) -> list:
    rows = db.query_all(
        "SELECT mission_id, progress, claimed FROM missions_progress "
        "WHERE user_id = %s AND week_key = %s",
        (user_id, week_key),
    )
    return [dict(r) for r in rows]


# ── wallet ──

def wallet_balance(user_id: str) -> int:
    row = db.query_one(
        "SELECT COALESCE(SUM(delta), 0) AS balance FROM economy_ledger WHERE user_id = %s",
        (user_id,),
    )
    return int(row["balance"])


def wallet_append(user_id: str, delta: int, reason: str) -> dict:
    db.execute(
        "INSERT INTO economy_ledger (user_id, delta, reason) VALUES (%s, %s, %s)",
        (user_id, delta, reason[:64]),
    )
    return {"balance": wallet_balance(user_id)}


def wallet_entries(user_id: str, limit: int = 20) -> list:
    rows = db.query_all(
        "SELECT delta, reason, created_at FROM economy_ledger "
        "WHERE user_id = %s ORDER BY entry_id DESC LIMIT %s",
        (user_id, max(1, min(limit, 100))),
    )
    return [dict(r) for r in rows]


# ── sign-in ──

def signin(user_id: str, day: str, streak: int) -> bool:
    """Idempotent per day; True when this call is the first sign-in that day."""
    return db.execute(
        """
        INSERT INTO signin_log (user_id, signin_date, streak) VALUES (%s, %s, %s)
        ON CONFLICT (user_id, signin_date) DO NOTHING
        """,
        (user_id, day, max(1, streak)),
    )


def list_signins(user_id: str, limit: int = 14) -> list:
    rows = db.query_all(
        "SELECT signin_date, streak FROM signin_log WHERE user_id = %s "
        "ORDER BY signin_date DESC LIMIT %s",
        (user_id, max(1, min(limit, 60))),
    )
    return [dict(r) for r in rows]
