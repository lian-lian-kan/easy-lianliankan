"""User accounts: device-style register, token issue/refresh."""
import uuid as uuid_lib

from ..core import db, security


def register(nickname: str = "") -> dict:
    user_id = str(uuid_lib.uuid4())
    db.execute(
        "INSERT INTO users (user_id, nickname) VALUES (%s, %s)",
        (user_id, nickname[:32]),
    )
    token = security.issue_token(user_id)
    touch(user_id)
    return {"user_id": user_id, "token": token}


def refresh_token(old_token: str, user_id: str) -> dict:
    security.revoke_token(old_token)
    token = security.issue_token(user_id)
    return {"token": token}


def rename(user_id: str, nickname: str) -> None:
    db.execute(
        "UPDATE users SET nickname = %s WHERE user_id = %s",
        (nickname[:32], user_id),
    )


def profile(user_id: str) -> dict:
    row = db.query_one(
        "SELECT user_id::text, nickname, created_at, last_seen_at FROM users WHERE user_id = %s",
        (user_id,),
    )
    return dict(row) if row else {}


def touch(user_id: str) -> None:
    db.execute("UPDATE users SET last_seen_at = now() WHERE user_id = %s", (user_id,))
