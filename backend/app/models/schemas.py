"""Request/response schemas."""
from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    nickname: str = Field("", max_length=32)


class TokenResponse(BaseModel):
    user_id: str
    token: str


class RefreshResponse(BaseModel):
    token: str


class RenameRequest(BaseModel):
    nickname: str = Field(..., min_length=1, max_length=32)


class ProgressPutRequest(BaseModel):
    state: dict = Field(..., description="full progression_state blob")
    updated_at: int = Field(..., ge=0, description="client unix ms")


class ProgressPutResponse(BaseModel):
    saved: bool
    updated_at: int


class RecordPutRequest(BaseModel):
    best_score: int = Field(0, ge=0)
    play: bool = True
    win: bool = False


class MissionPutRequest(BaseModel):
    mission_id: str = Field(..., min_length=1, max_length=64)
    week_key: int = Field(..., ge=0)
    progress: int = Field(0, ge=0)
    claimed: bool = False


class WalletEntryRequest(BaseModel):
    delta: int = Field(..., description="positive income or negative spend")
    reason: str = Field("", max_length=64)


class SigninRequest(BaseModel):
    day: str = Field(..., description="YYYY-MM-DD")
    streak: int = Field(1, ge=1)
