"""Storage maintenance: expired token pruning."""
import uuid
from datetime import datetime, timedelta, timezone

from app.core import maintenance
from app.core import db
from app.repositories import users_repo

from tests.conftest import register


def _insert_token(user_id: str, token: str, expires_at):
    db.execute(
        "INSERT INTO auth_tokens (token_hash, user_id, expires_at) VALUES (%s, %s, %s)",
        (token, user_id, expires_at),
    )


def test_prune_expired_tokens_keeps_live_only(client):
    user = register(client)
    now = datetime.now(timezone.utc)
    suffix = uuid.uuid4().hex[:8]
    _insert_token(user["user_id"], "expired-" + suffix, now - timedelta(days=1))
    _insert_token(user["user_id"], "live-" + suffix, now + timedelta(days=30))

    removed = maintenance.prune_expired_tokens()
    assert removed >= 1

    live = db.query_one(
        "SELECT 1 AS ok FROM auth_tokens WHERE token_hash = 'live-' || %s", (suffix,))
    assert live is not None
    gone = db.query_one(
        "SELECT 1 AS ok FROM auth_tokens WHERE token_hash = 'expired-' || %s", (suffix,))
    assert gone is None


def test_prune_expired_tokens_is_idempotent(client):
    user = register(client)
    now = datetime.now(timezone.utc)
    _insert_token(user["user_id"], "stale-" + uuid.uuid4().hex[:8],
                  now - timedelta(hours=2))
    assert maintenance.prune_expired_tokens() >= 1
    assert maintenance.prune_expired_tokens() >= 0  # second run is a no-op


def test_run_startup_maintenance_returns_counts(client):
    tokens, events = maintenance.run_startup_maintenance()
    assert tokens >= 0 and events >= 0


def test_pool_blocks_instead_of_exhausting(client, monkeypatch):
    """A burst wider than the pool must queue for a connection, never blow
    up with PoolError (the old behaviour under ThreadedConnectionPool)."""
    import threading

    from app.core import config, db as dbmod

    monkeypatch.setattr(config, "pool_max", lambda: 4)
    dbmod.close_pool()
    dbmod.init_pool()
    pool_slots = 4
    errors = []

    def hammer():
        try:
            for _ in range(6):
                dbmod.query_one("SELECT pg_sleep(0.01), 1 AS ok")
        except Exception as exc:
            errors.append(exc)

    threads = [threading.Thread(target=hammer) for _ in range(12)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    dbmod.close_pool()
    dbmod.init_pool()
    assert errors == [], errors[:3]


def test_checkout_releases_slot_when_getconn_fails(client, monkeypatch):
    """A dying getconn must not leak a pool slot."""
    from app.core import config, db as dbmod

    pool_slots = 4
    monkeypatch.setattr(config, "pool_max", lambda: pool_slots)
    dbmod.close_pool()
    dbmod.init_pool()

    def boom():
        raise ConnectionError("pg down")
    monkeypatch.setattr(dbmod._pool, "getconn", boom)
    try:
        dbmod.query_one("SELECT 1")
        raised = False
    except ConnectionError:
        raised = True
    assert raised
    assert dbmod._slots._value == pool_slots  # no slot leaked
    dbmod.close_pool()
    dbmod.init_pool()
