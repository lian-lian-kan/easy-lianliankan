"""SQL for the per-user progress snapshot."""
import json

from ..core import db


def get_snapshot(user_id: str):
    return db.query_one(
        "SELECT state, updated_at FROM progress_snapshots WHERE user_id = %s",
        (user_id,),
    )


def upsert_snapshot(user_id: str, state: dict, updated_at: int):
    """Stale-write guard lives in the WHERE clause: an older timestamp is a
    no-op (no row returned). Same-or-newer lands."""
    return db.query_one(
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
