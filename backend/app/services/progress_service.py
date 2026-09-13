"""Cloud save: one JSONB snapshot per user with stale-write rejection."""
import json

from ..core import config, db


def get_progress(user_id: str):
    row = db.query_one(
        "SELECT state, updated_at FROM progress_snapshots WHERE user_id = %s",
        (user_id,),
    )
    if row is None:
        return None
    return {"state": db.as_dict(row["state"]), "updated_at": int(row["updated_at"])}


def put_progress(user_id: str, state: dict, updated_at: int) -> dict:
    if len(json.dumps(state)) > config.max_state_bytes():
        raise ValueError("state too large")
    row = db.query_one(
        """
        INSERT INTO progress_snapshots (user_id, state, updated_at)
        VALUES (%s, %s, %s)
        ON CONFLICT (user_id) DO UPDATE
            SET state = EXCLUDED.state, updated_at = EXCLUDED.updated_at
            WHERE progress_snapshots.updated_at <= EXCLUDED.updated_at
        RETURNING updated_at
        """,
        (user_id, json.dumps(state), updated_at),
    )
    if row is not None:
        return {"saved": True, "updated_at": int(row["updated_at"])}
    stored = get_progress(user_id)
    return {"saved": False, "updated_at": stored["updated_at"] if stored else updated_at}
