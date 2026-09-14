"""Shared FastAPI dependencies: auth, rate limiting, request id.

Application-level (not core/): they bind HTTP concerns (headers, 401/429) to
repositories and the rate limiter, so core stays framework-light.
"""
import uuid

from fastapi import Depends, HTTPException, Request

from .core import ratelimit, token_cache
from .repositories import users_repo


def _bearer_token(request: Request) -> str:
    header = request.headers.get("Authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    return header[7:].strip()


def current_user(request: Request) -> str:
    """Dependency: bearer token -> user_id (401 when absent/unknown/expired).

    Cache hit skips the DB entirely; a miss falls through and backfills.
    """
    token = _bearer_token(request)
    user_id = token_cache.lookup(token)
    if user_id is not None:
        return user_id
    row = users_repo.find_active_user_by_token(token)
    if row is None:
        raise HTTPException(status_code=401, detail="invalid or expired token")
    user_id = str(row["user_id"])
    token_cache.store(token, user_id)
    return user_id


def current_token(request: Request) -> str:
    token = _bearer_token(request)
    if token_cache.lookup(token) is not None:
        return token
    if users_repo.find_active_user_by_token(token) is None:
        raise HTTPException(status_code=401, detail="invalid or expired token")
    return token


def rate_limit(bucket: str, limit: int, window_seconds: float):
    """Dependency factory: per-IP sliding window on public endpoints.

    IP scoping alone punishes real players behind shared NAT (offices,
    campuses); authenticated hot paths pair a loose IP ceiling with a tight
    per-user one (see user_rate_limit).
    """
    def _guard(request: Request) -> None:
        ip = request.client.host if request.client else "unknown"
        if not ratelimit.allow(f"{bucket}:{ip}", limit, window_seconds):
            raise HTTPException(status_code=429, detail="too many requests")
    return _guard


def user_rate_limit(bucket: str, limit: int, window_seconds: float):
    """Dependency factory: per-user sliding window on authenticated writes.

    One rogue token can only throttle itself; a full NAT office still gets
    its own budget per player.
    """
    def _guard(user_id: str = Depends(current_user)) -> None:
        if not ratelimit.allow(f"{bucket}:u:{user_id}", limit, window_seconds):
            raise HTTPException(status_code=429, detail="too many requests")
    return _guard


def new_request_id() -> str:
    return uuid.uuid4().hex[:12]
