"""Cloud save routes."""
from fastapi import APIRouter, Depends, HTTPException

from ..core.security import current_user_id
from ..models.schemas import ProgressPutRequest, ProgressPutResponse
from ..services import progress_service, user_service

router = APIRouter(prefix="/api/v1/progress", tags=["progress"])


@router.get("")
def read_progress(user_id: str = Depends(current_user_id)):
    data = progress_service.get_progress(user_id)
    if data is None:
        raise HTTPException(status_code=404, detail="no saved progress")
    return data


@router.put("", response_model=ProgressPutResponse)
def write_progress(payload: ProgressPutRequest, user_id: str = Depends(current_user_id)):
    try:
        result = progress_service.put_progress(user_id, payload.state, payload.updated_at)
    except ValueError as exc:
        raise HTTPException(status_code=413, detail=str(exc))
    user_service.touch(user_id)
    return result
