"""Pairing-code migration: the server mints a short-lived code on the old
device; the new device burns it and adopts the bound account (cloud-first —
any fresh local progress on the new device yields to the migrated save)."""
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from ..core import config, db, security
from ..repositories import migration_repo, users_repo
from . import user_service

# Unambiguous alphabet: no 0/O/1/I/L — codes are read aloud and hand-typed.
ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
CODE_LEN = 8


def generate_code(user_id: str) -> dict:
    code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LEN))
    expires = datetime.now(timezone.utc) + timedelta(seconds=config.migration_code_ttl_seconds())
    migration_repo.replace_user_code(code, user_id, expires)
    migration_repo.delete_expired()
    return {"code": _format(code), "expires_in": config.migration_code_ttl_seconds()}


def claim(code: str) -> dict:
    normalized = _normalize(code)
    if len(normalized) != CODE_LEN:
        raise HTTPException(status_code=404, detail="invalid or expired code")
    claimed = migration_repo.consume(normalized)
    if claimed is None:
        raise HTTPException(*_miss_reason(normalized))
    user_id = str(claimed["user_id"])
    with db.transaction():
        token = user_service.issue_token(user_id)
        # Revoke every other device session: a forgotten old device must
        # never push a stale save over the one the player just migrated to.
        users_repo.revoke_other_tokens(user_id, security.hash_token(token))
    users_repo.touch(user_id)
    return {"user_id": user_id, "token": token}


def _miss_reason(normalized: str):
    """Distinguish the three failure shapes for honest client copy."""
    row = migration_repo.find_by_hash(normalized)
    if row is None:
        return (404, "invalid or expired code")
    if row["consumed_at"] is not None:
        return (409, "code already used")
    return (410, "code expired")


def _format(code: str) -> str:
    return code[:4] + "-" + code[4:]


def _normalize(raw: str) -> str:
    """Strip separators/whitespace and uppercase — typed codes forgive."""
    return "".join(ch for ch in raw.upper() if ch in ALPHABET)
