"""Account + auth routes."""
from fastapi import APIRouter, Depends, HTTPException

from ..core import config
from ..dependencies import current_user, rate_limit
from ..models.schemas import RegisterRequest, RenameRequest, TokenResponse
from ..services import user_service

router = APIRouter(prefix="/api/v1/users", tags=["users"])


@router.post("/register", response_model=TokenResponse, status_code=201,
             dependencies=[Depends(rate_limit("register",
                                              limit=config.register_limit_per_minute(),
                                              window_seconds=60))])
def register(payload: RegisterRequest):
    return user_service.register(payload.nickname)


@router.get("/me")
def me(user_id: str = Depends(current_user)):
    profile = user_service.profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="user not found")
    return profile


@router.post("/rename")
def rename(payload: RenameRequest, user_id: str = Depends(current_user)):
    user_service.rename(user_id, payload.nickname)
    return {"ok": True}
