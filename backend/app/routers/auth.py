"""Token refresh route: rotates the caller's token."""
from fastapi import APIRouter, Depends

from ..core import security
from ..models.schemas import RefreshResponse

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/refresh", response_model=RefreshResponse)
def refresh(token: str = Depends(security.current_credentials),
            user_id: str = Depends(security.current_user_id)):
    security.revoke_token(token)
    return {"token": security.issue_token(user_id)}
