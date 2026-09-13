"""Connection pool and tiny query helpers (sync psycopg2 under FastAPI)."""
import json

import psycopg2
import psycopg2.extras

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


def query_one(sql: str, params=()):
    """Run a statement and return the first row (dict) or None. Works for
    INSERT .. RETURNING too."""
    with _pool.getconn() as conn:
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, params)
                row = cur.fetchone()
            conn.commit()
        finally:
            _pool.putconn(conn)
    return row


def query_all(sql: str, params=()):
    with _pool.getconn() as conn:
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()
            conn.commit()
        finally:
            _pool.putconn(conn)
    return rows


def execute(sql: str, params=()) -> bool:
    """Run a mutation without RETURNING; True when rows were affected."""
    with _pool.getconn() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                affected = cur.rowcount > 0
            conn.commit()
        finally:
            _pool.putconn(conn)
    return affected


def as_dict(raw):
    """JSONB columns arrive as dict already; guard the legacy text form."""
    if isinstance(raw, (str, bytes)):
        return json.loads(raw)
    return raw
