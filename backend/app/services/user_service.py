"""User accounts: register (atomic), profile, rename, token issue/refresh."""
import uuid as uuid_lib
from datetime import datetime, timedelta, timezone

from ..core import config, db
from ..repositories import users_repo

NICKNAME_MAX = 32


def register(nickname: str = "") -> dict:
    user_id = str(uuid_lib.uuid4())
    with db.transaction():
        users_repo.insert_user(user_id, _clean_nickname(nickname))
        token = _issue_token(user_id)
    users_repo.touch(user_id)
    return {"user_id": user_id, "token": token}


def refresh_token(old_token: str, user_id: str) -> dict:
    """Rotate: the old token dies, a fresh one is minted — atomically."""
    with db.transaction():
        users_repo.delete_token(old_token)
        token = _issue_token(user_id)
    return {"token": token}


def rename(user_id: str, nickname: str) -> None:
    users_repo.rename(user_id, _clean_nickname(nickname))


def profile(user_id: str) -> dict:
    row = users_repo.get_user(user_id)
    return dict(row) if row else {}


def touch(user_id: str) -> None:
    users_repo.touch(user_id)


def _issue_token(user_id: str) -> str:
    from ..core import security
    token = security.mint_token()
    expires = datetime.now(timezone.utc) + timedelta(days=config.token_ttl_days())
    users_repo.insert_token(token, user_id, expires)
    return token


def _clean_nickname(nickname: str) -> str:
    return nickname.strip()[:NICKNAME_MAX]
