"""Device migration: pairing-code issue (old device) and claim (new device).

Issue is user-scoped (the code belongs to the caller's account); claim is
anonymous — the new device has no session yet, so its only guard is a hard
per-IP ceiling. Claim responses share the register shape so clients can
adopt the session with the same code path.
"""
from fastapi import APIRouter, Depends

from ..dependencies import current_user, rate_limit, user_rate_limit
from ..models.schemas import MigrationClaimRequest, MigrationCodeResponse, TokenResponse
from ..services import migration_service

router = APIRouter(prefix="/api/v1/migration", tags=["migration"])


@router.post("/code", response_model=MigrationCodeResponse,
             dependencies=[Depends(user_rate_limit("migration_code", limit=2, window_seconds=60))])
def issue_code(user_id: str = Depends(current_user)):
    return migration_service.generate_code(user_id)


@router.post("/claim", response_model=TokenResponse,
             dependencies=[Depends(rate_limit("migration_claim", limit=5, window_seconds=60))])
def claim(payload: MigrationClaimRequest):
    return migration_service.claim(payload.code)
