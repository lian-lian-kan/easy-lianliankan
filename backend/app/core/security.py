"""Token auth: clients hold a raw token; the DB stores only its SHA-256."""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import config, db

_bearer = HTTPBearer(auto_error=False)


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


def current_credentials(credentials: HTTPAuthorizationCredentials = Depends(_bearer)) -> str:
    """Return the raw bearer token; 401 when absent/unknown/expired."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="missing bearer token")
    token_hash = hash_token(credentials.credentials)
    row = db.query_one(
        "SELECT user_id FROM auth_tokens WHERE token_hash = %s AND expires_at > now()",
        (token_hash,),
    )
    if row is None:
        raise HTTPException(status_code=401, detail="invalid or expired token")
    return credentials.credentials


def current_user_id(token: str = Depends(current_credentials)) -> str:
    row = db.query_one(
        "SELECT user_id FROM auth_tokens WHERE token_hash = %s",
        (hash_token(token),),
    )
    return str(row["user_id"])
