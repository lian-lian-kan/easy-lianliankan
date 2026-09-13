"""Token refresh route: rotates the caller's token."""
from fastapi import APIRouter, Depends

from ..core import guards, security
from ..models.schemas import RefreshResponse
from ..services import user_service

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/refresh", response_model=RefreshResponse)
def refresh(token: str = Depends(guards.current_token),
            user_id: str = Depends(guards.current_user)):
    return user_service.refresh_token(token, user_id)
