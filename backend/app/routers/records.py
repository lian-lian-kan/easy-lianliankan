"""Mode registry + per-user mode records + leaderboards."""
from fastapi import APIRouter, Depends, HTTPException, Query

from ..dependencies import current_user, rate_limit, user_rate_limit
from ..models.schemas import RecordPutRequest
from ..services import leaderboard_service, records_service
from ..services.records_service import ScoreRejected

router = APIRouter(prefix="/api/v1", tags=["records"])


@router.get("/modes")
def list_modes():
    return {"modes": records_service.list_modes()}


@router.get("/records")
def list_records(user_id: str = Depends(current_user)):
    return {"records": records_service.list_records(user_id)}


@router.put("/records/{mode_id}",
            dependencies=[Depends(rate_limit("records_put", limit=3000, window_seconds=60)),
                          Depends(user_rate_limit("records_put", limit=60, window_seconds=60))])
def record_result(mode_id: str, payload: RecordPutRequest,
                  user_id: str = Depends(current_user)):
    try:
        record = records_service.record_result(
            user_id, mode_id, payload.best_score, payload.play, payload.win)
    except ScoreRejected as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    if record is None:
        raise HTTPException(status_code=404, detail="unknown mode_id")
    return {"record": record}


@router.get("/leaderboard/{mode_id}")
def leaderboard(mode_id: str, limit: int = Query(20, ge=1, le=100),
                period: str = Query("all", pattern="^(all|weekly|daily)$"),
                user_id: str = Depends(current_user)):
    return leaderboard_service.board(mode_id, period, limit, user_id)
