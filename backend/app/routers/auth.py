"""Token refresh route: rotates the caller's token."""
from fastapi import APIRouter, Depends

from .. import dependencies
from ..core import ratelimit
from ..dependencies import current_user, rate_limit
from ..models.schemas import RefreshResponse
from ..services import user_service

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/refresh", response_model=RefreshResponse,
             dependencies=[Depends(rate_limit("refresh", limit=300, window_seconds=60))])
def refresh(token: str = Depends(dependencies.current_token),
            user_id: str = Depends(current_user)):
    return user_service.refresh_token(token, user_id)
