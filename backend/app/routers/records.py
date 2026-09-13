"""Mode registry + per-user mode records + leaderboards."""
from fastapi import APIRouter, Depends, HTTPException, Query

from ..core.guards import current_user
from ..models.schemas import RecordPutRequest
from ..services import leaderboard_service, records_service

router = APIRouter(prefix="/api/v1", tags=["records"])


@router.get("/modes")
def list_modes():
    return {"modes": records_service.list_modes()}


@router.get("/records")
def list_records(user_id: str = Depends(current_user)):
    return {"records": records_service.list_records(user_id)}


@router.put("/records/{mode_id}")
def record_result(mode_id: str, payload: RecordPutRequest,
                  user_id: str = Depends(current_user)):
    record = records_service.record_result(
        user_id, mode_id, payload.best_score, payload.play, payload.win)
    if record is None:
        raise HTTPException(status_code=404, detail="unknown mode_id")
    return {"record": record}


@router.get("/leaderboard/{mode_id}")
def leaderboard(mode_id: str, limit: int = Query(20, ge=1, le=100),
                user_id: str = Depends(current_user)):
    return {
        "mode_id": mode_id,
        "top": leaderboard_service.top_scores(mode_id, limit),
        "my_rank": leaderboard_service.user_rank(user_id, mode_id),
    }
