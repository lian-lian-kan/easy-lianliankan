"""Shared FastAPI dependencies: auth, rate limiting, request id."""
import uuid

from fastapi import HTTPException, Request

from . import ratelimit, security


def current_user(request: Request) -> str:
    """Dependency: bearer token -> user_id (401 when absent/unknown/expired)."""
    header = request.headers.get("Authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    token = header[7:].strip()
    row = security.find_active_user_by_token(token)
    if row is None:
        raise HTTPException(status_code=401, detail="invalid or expired token")
    return str(row["user_id"])


def current_token(request: Request) -> str:
    header = request.headers.get("Authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    token = header[7:].strip()
    if security.find_active_user_by_token(token) is None:
        raise HTTPException(status_code=401, detail="invalid or expired token")
    return token


def rate_limit(bucket: str, limit: int, window_seconds: float):
    """Dependency factory: per-IP sliding window on public endpoints."""
    def _guard(request: Request) -> None:
        ip = request.client.host if request.client else "unknown"
        if not ratelimit.allow(f"{bucket}:{ip}", limit, window_seconds):
            raise HTTPException(status_code=429, detail="too many requests")
    return _guard


def new_request_id() -> str:
    return uuid.uuid4().hex[:12]
