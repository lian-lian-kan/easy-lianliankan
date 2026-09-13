"""Token primitives: minting, hashing, storage, lookup, revocation.

HTTP concerns (header parsing, 401s) live in core/guards; this module is
pure token <-> DB operations so services can compose them inside transactions.
"""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from . import config, db


def mint_token() -> str:
    return secrets.token_hex(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_token(user_id: str) -> str:
    token = mint_token()
    expires = datetime.now(timezone.utc) + timedelta(days=config.token_ttl_days())
    db.execute(
        "INSERT INTO auth_tokens (token_hash, user_id, expires_at) VALUES (%s, %s, %s)",
        (hash_token(token), user_id, expires),
    )
    return token


def revoke_token(token: str) -> None:
    db.execute("DELETE FROM auth_tokens WHERE token_hash = %s", (hash_token(token),))


def find_active_user_by_token(token: str):
    return db.query_one(
        "SELECT user_id FROM auth_tokens WHERE token_hash = %s AND expires_at > now()",
        (hash_token(token),),
    )
