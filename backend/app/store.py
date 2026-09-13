"""PostgreSQL persistence for player progress blobs."""
import json

import psycopg2
import psycopg2.pool

from . import config

_pool = None


def init_pool():
    global _pool
    if _pool is None:
        _pool = psycopg2.pool.SimpleConnectionPool(
            config.pool_min(),
            config.pool_max(),
            dsn=config.database_url(),
        )


def close_pool():
    global _pool
    if _pool is not None:
        _pool.closeall()
        _pool = None


def ensure_schema() -> None:
    """Create the progress table if it does not exist (idempotent)."""
    with _pool.getconn() as conn:  # psycopg2 connection context manager does not commit
        try:
            with conn.cursor() as cur:
                cur.execute(SCHEMA_SQL)
            conn.commit()
        finally:
            _pool.putconn(conn)


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS player_progress (
    player_id  TEXT PRIMARY KEY,
    state      JSONB NOT NULL,
    updated_at BIGINT NOT NULL
);
"""


def get_progress(player_id: str):
    """Return (state_dict, updated_at) or None when the player is unknown."""
    with _pool.getconn() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT state, updated_at FROM player_progress WHERE player_id = %s",
                    (player_id,),
                )
                row = cur.fetchone()
            conn.commit()
        finally:
            _pool.putconn(conn)
    if row is None:
        return None
    return _as_state(row[0]), int(row[1])


def put_progress(player_id: str, state: dict, updated_at: int) -> dict:
    """Upsert progress.

    Returns a result dict:
      - {"saved": True, "updated_at": n}          the write landed
      - {"saved": False, "updated_at": stored}    incoming is stale, keep server copy
    """
    with _pool.getconn() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO player_progress (player_id, state, updated_at)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (player_id) DO UPDATE
                        SET state = EXCLUDED.state,
                            updated_at = EXCLUDED.updated_at
                        WHERE player_progress.updated_at <= EXCLUDED.updated_at
                    RETURNING updated_at
                    """,
                    (player_id, json.dumps(state), updated_at),
                )
                row = cur.fetchone()
            conn.commit()
        finally:
            _pool.putconn(conn)
    if row is None:
        stored = get_progress(player_id)
        return {"saved": False, "updated_at": stored[1] if stored else updated_at}
    return {"saved": True, "updated_at": int(row[0])}


def _as_state(raw):
    """psycopg2 parses JSONB into dict already; guard the legacy text form."""
    if isinstance(raw, (str, bytes)):
        return json.loads(raw)
    return raw
