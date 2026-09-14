"""Achievements, weekly missions, wallet ledger and sign-ins — business rules."""
from ..core import config, db, redis_client
from ..repositories import engagement_repo

TEXT_ID_MAX = 64
REASON_MAX = 64


# ── achievements ──

def list_achievements(user_id: str) -> list:
    return [dict(r) for r in engagement_repo.list_achievements(user_id)]


def unlock(user_id: str, achievement_id: str) -> bool:
    """Idempotent; True when this call newly unlocked it."""
    row = engagement_repo.insert_achievement(user_id, achievement_id[:TEXT_ID_MAX])
    return row is not None


# ── weekly missions ──

def upsert_mission(user_id: str, week_key: int, mission_id: str, progress: int, claimed: bool) -> dict:
    row = engagement_repo.upsert_mission(
        user_id, week_key, mission_id[:TEXT_ID_MAX], max(0, progress), claimed)
    return dict(row)


def list_missions(user_id: str, week_key: int) -> list:
    return [dict(r) for r in engagement_repo.list_missions(user_id, week_key)]


# ── wallet ──

BALANCE_TTL_SECONDS = 300


def _balance_key(user_id: str) -> str:
    return f"bal:{user_id}"


def wallet_balance(user_id: str) -> int:
    """Balance is a SUM over the append-only ledger — cache it so wallet
    reads never aggregate a growing ledger. Writes invalidate (see append),
    TTL bounds staleness if an invalidation is ever lost."""
    client = redis_client.get_client()
    if client is not None:
        try:
            raw = client.get(_balance_key(user_id))
            if raw is not None:
                return int(raw)
        except Exception:
            pass
    balance = engagement_repo.ledger_balance(user_id)
    if client is not None:
        try:
            client.setex(_balance_key(user_id), BALANCE_TTL_SECONDS, balance)
        except Exception:
            pass
    return balance


def wallet_append(user_id: str, delta: int, reason: str) -> dict:
    """Append + balance read in one transaction so the returned balance can
    never reflect another concurrent write of the same user."""
    if abs(delta) > config.max_wallet_delta():
        raise ValueError("delta out of range")
    with db.transaction():
        engagement_repo.append_ledger(user_id, delta, reason[:REASON_MAX])
        balance = engagement_repo.ledger_balance(user_id)
    try:
        client = redis_client.get_client()
        if client is not None:
            client.setex(_balance_key(user_id), BALANCE_TTL_SECONDS, balance)
    except Exception:
        pass
    return {"balance": balance}


def wallet_entries(user_id: str, limit: int) -> list:
    return [dict(r) for r in engagement_repo.ledger_entries(user_id, limit)]


# ── sign-ins ──

def signin(user_id: str, day: str, streak: int) -> bool:
    """Idempotent per day; True when this call is the first sign-in that day."""
    return engagement_repo.insert_signin(user_id, day, max(1, streak))


def list_signins(user_id: str, limit: int) -> list:
    return [dict(r) for r in engagement_repo.list_signins(user_id, limit)]
