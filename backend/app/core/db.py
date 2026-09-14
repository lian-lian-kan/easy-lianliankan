"""Connection pool, query helpers and transactions (sync psycopg2 under FastAPI).

Every helper runs on the connection held by the active `transaction()` context
when one is open, so multi-statement service calls become atomic without the
repository layer knowing about transactions.
"""
import json
import threading
from contextlib import contextmanager

import psycopg2
import psycopg2.extras
import psycopg2.pool

from . import config

_pool = None
_slots = None
_local = threading.local()


def init_pool():
    global _pool, _slots
    if _pool is None:
        # Threaded variant is mandatory here: sync endpoints run on a shared
        # thread pool (THREAD_CAPACITY=100), so getconn/putconn race.
        _pool = psycopg2.pool.ThreadedConnectionPool(
            config.pool_min(),
            config.pool_max(),
            dsn=config.database_url(),
        )
        # psycopg2 pools raise PoolError the moment maxconn connections are
        # checked out — with THREAD_CAPACITY above pool_max that turns any
        # burst into 500s. The semaphore makes excess threads block until a
        # connection is returned instead, so the pool can never overflow.
        _slots = threading.BoundedSemaphore(config.pool_max())


def close_pool():
    global _pool, _slots
    if _pool is not None:
        _pool.closeall()
        _pool = None
    _slots = None


@contextmanager
def _checkout():
    """Block for a pool slot, then hand out a connection for the with-block."""
    _slots.acquire()
    conn = None
    try:
        conn = _pool.getconn()
        yield conn
    finally:
        if conn is not None:
            _pool.putconn(conn)
        _slots.release()


def ping() -> bool:
    """Cheap liveness probe for /healthz."""
    try:
        return query_one("SELECT 1 AS ok")["ok"] == 1
    except Exception:
        return False


@contextmanager
def transaction():
    """Group the enclosed db.* calls into one connection with a single
    commit/rollback. Nesting is flat: an inner transaction() reuses the outer
    connection (savepoints are unnecessary for our short service calls)."""
    if getattr(_local, "conn", None) is not None:
        yield _local.conn
        return
    with _checkout() as conn:
        _local.conn = conn
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            _local.conn = None


def _run(sql, params, fetch):
    conn = getattr(_local, "conn", None)
    if conn is not None:
        # Inside an open transaction(): reuse its connection, no own slot.
        return _execute(conn, sql, params, fetch, commit=False)
    with _checkout() as conn:
        return _execute(conn, sql, params, fetch, commit=True)


def _execute(conn, sql, params, fetch, commit):
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql, params)
        if fetch == "one":
            result = cur.fetchone()
        elif fetch == "all":
            result = cur.fetchall()
        else:
            result = cur.rowcount > 0
    if commit:
        conn.commit()
    return result


def query_one(sql: str, params=()):
    """Run a statement and return the first row (dict) or None. Works for
    INSERT .. RETURNING too."""
    return _run(sql, params, "one")


def query_all(sql: str, params=()):
    return _run(sql, params, "all")


def execute(sql: str, params=()) -> bool:
    """Run a mutation without RETURNING; True when rows were affected."""
    return _run(sql, params, None)


def as_dict(raw):
    """JSONB columns arrive as dict already; guard the legacy text form."""
    if isinstance(raw, (str, bytes)):
        return json.loads(raw)
    return raw
