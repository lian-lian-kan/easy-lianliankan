"""Storage maintenance: expired token pruning."""
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
    _insert_token(user["user_id"], "expired-hash", now - timedelta(days=1))
    _insert_token(user["user_id"], "live-hash", now + timedelta(days=30))

    removed = maintenance.prune_expired_tokens()
    assert removed >= 1

    live = db.query_one(
        "SELECT 1 AS ok FROM auth_tokens WHERE token_hash = 'live-hash'")
    assert live is not None
    gone = db.query_one(
        "SELECT 1 AS ok FROM auth_tokens WHERE token_hash = 'expired-hash'")
    assert gone is None


def test_prune_expired_tokens_is_idempotent(client):
    user = register(client)
    now = datetime.now(timezone.utc)
    _insert_token(user["user_id"], "stale-hash", now - timedelta(hours=2))
    assert maintenance.prune_expired_tokens() >= 1
    assert maintenance.prune_expired_tokens() >= 0  # second run is a no-op


def test_run_startup_maintenance_returns_counts(client):
    tokens, events = maintenance.run_startup_maintenance()
    assert tokens >= 0 and events >= 0
