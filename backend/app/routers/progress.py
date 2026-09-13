"""Cloud save routes."""
from fastapi import APIRouter, Depends, HTTPException

from ..dependencies import current_user, rate_limit
from ..models.schemas import ProgressPutRequest, ProgressPutResponse
from ..services import progress_service, user_service
from ..services.progress_service import StateTooLarge, StaleTimestamp

router = APIRouter(prefix="/api/v1/progress", tags=["progress"])


@router.get("")
def read_progress(user_id: str = Depends(current_user)):
    data = progress_service.get_progress(user_id)
    if data is None:
        raise HTTPException(status_code=404, detail="no saved progress")
    return data


@router.put("", response_model=ProgressPutResponse,
            dependencies=[Depends(rate_limit("progress_put", limit=60, window_seconds=60))])
def write_progress(payload: ProgressPutRequest, user_id: str = Depends(current_user)):
    try:
        result = progress_service.put_progress(user_id, payload.state, payload.updated_at)
    except StateTooLarge as exc:
        raise HTTPException(status_code=413, detail=str(exc))
    except StaleTimestamp as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    user_service.touch(user_id)
    return result
