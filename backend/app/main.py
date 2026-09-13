"""Sophia's lianliankan progress API (FastAPI + PostgreSQL).

Identity model: the client generates a random 32-hex player id once and
keeps it in local storage; the id IS the credential (casual game, no PII).
Progress is stored as one JSONB blob per player with a monotonic
client-supplied updated_at; stale writes are rejected so an older device
can never clobber a newer save.
"""
import json
import re
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from . import config, store

PLAYER_ID_RE = re.compile(r"^[0-9a-f]{32}$")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    store.init_pool()
    store.ensure_schema()
    yield
    store.close_pool()


app = FastAPI(title="sophia-lianliankan-progress", lifespan=lifespan)


class ProgressPayload(BaseModel):
    state: dict = Field(..., description="full progression_state blob")
    updated_at: int = Field(..., ge=0, description="client unix ms")


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/api/v1/progress/{player_id}")
def read_progress(player_id: str):
    _require_player_id(player_id)
    row = store.get_progress(player_id)
    if row is None:
        raise HTTPException(status_code=404, detail="no saved progress")
    return {"state": row[0], "updated_at": row[1]}


@app.put("/api/v1/progress/{player_id}")
def write_progress(player_id: str, payload: ProgressPayload):
    _require_player_id(player_id)
    if len(json.dumps(payload.state)) > config.max_state_bytes():
        raise HTTPException(status_code=413, detail="state too large")
    result = store.put_progress(player_id, payload.state, int(payload.updated_at))
    return result


def _require_player_id(player_id: str) -> None:
    if not PLAYER_ID_RE.match(player_id):
        raise HTTPException(status_code=400, detail="player_id must be 32 hex chars")
