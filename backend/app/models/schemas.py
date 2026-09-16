"""Request/response schemas with hard input bounds (fail fast at the edge)."""
from pydantic import BaseModel, Field

from ..core import config

DAY_PATTERN = r"^\d{4}-\d{2}-\d{2}$"


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
    updated_at: int = Field(..., ge=0, le=4_102_444_800_000, description="client unix ms")


class ProgressPutResponse(BaseModel):
    saved: bool
    updated_at: int


class RecordPutRequest(BaseModel):
    best_score: int = Field(0, ge=0, le=100_000_000)
    play: bool = True
    win: bool = False


class MissionPutRequest(BaseModel):
    mission_id: str = Field(..., min_length=1, max_length=64)
    week_key: int = Field(..., ge=0, le=1_000_000_000)
    progress: int = Field(0, ge=0, le=100_000_000)
    claimed: bool = False


class WalletEntryRequest(BaseModel):
    delta: int = Field(..., description="positive income or negative spend",
                       ge=-config.max_wallet_delta(), le=config.max_wallet_delta())
    reason: str = Field("", max_length=64)


class SigninRequest(BaseModel):
    day: str = Field(..., pattern=DAY_PATTERN)
    streak: int = Field(1, ge=1, le=10_000)


class MigrationCodeResponse(BaseModel):
    code: str
    expires_in: int


class MigrationClaimRequest(BaseModel):
    code: str = Field(..., min_length=1, max_length=32)
