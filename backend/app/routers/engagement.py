"""Achievements, weekly missions, wallet, sign-ins."""
from fastapi import APIRouter, Depends, HTTPException, Query

from ..dependencies import current_user, rate_limit
from ..models.schemas import MissionPutRequest, SigninRequest, WalletEntryRequest
from ..services import engagement_service

router = APIRouter(prefix="/api/v1", tags=["engagement"])


@router.get("/achievements")
def list_achievements(user_id: str = Depends(current_user)):
    return {"achievements": engagement_service.list_achievements(user_id)}


@router.post("/achievements/{achievement_id}")
def unlock(achievement_id: str, user_id: str = Depends(current_user)):
    return {"newly_unlocked": engagement_service.unlock(user_id, achievement_id)}


@router.get("/missions")
def list_missions(week_key: int = Query(..., ge=0), user_id: str = Depends(current_user)):
    return {"missions": engagement_service.list_missions(user_id, week_key)}


@router.put("/missions")
def upsert_mission(payload: MissionPutRequest, user_id: str = Depends(current_user)):
    mission = engagement_service.upsert_mission(
        user_id, payload.week_key, payload.mission_id, payload.progress, payload.claimed)
    return {"mission": mission}


@router.get("/wallet")
def wallet(user_id: str = Depends(current_user),
           limit: int = Query(20, ge=1, le=100)):
    return {
        "balance": engagement_service.wallet_balance(user_id),
        "entries": engagement_service.wallet_entries(user_id, limit),
    }


@router.post("/wallet/entries",
             dependencies=[Depends(rate_limit("wallet", limit=30, window_seconds=60))])
def wallet_append(payload: WalletEntryRequest, user_id: str = Depends(current_user)):
    return engagement_service.wallet_append(user_id, payload.delta, payload.reason)


@router.post("/signin",
             dependencies=[Depends(rate_limit("signin", limit=10, window_seconds=60))])
def signin(payload: SigninRequest, user_id: str = Depends(current_user)):
    first_today = engagement_service.signin(user_id, payload.day, payload.streak)
    return {"first_today": first_today, "signins": engagement_service.list_signins(user_id, 14)}


@router.get("/signin")
def list_signins(user_id: str = Depends(current_user),
                 limit: int = Query(14, ge=1, le=60)):
    return {"signins": engagement_service.list_signins(user_id, limit)}
