"""Unit coverage for core primitives, transaction semantics and degradation
paths — complements the route-level suites in test_users_auth / test_progress /
test_records_leaderboard / test_engagement."""
import uuid

import pytest

from app.core import db, migrations, ratelimit, redis_client, security
from app.repositories import users_repo
from app.services import engagement_service


# ── token primitives (core/security) ──

def test_mint_token_is_unique_hex64():
    tokens = {security.mint_token() for _ in range(16)}
    assert len(tokens) == 16
    assert all(len(t) == 64 and int(t, 16) >= 0 for t in tokens)


def test_hash_token_is_deterministic_sha256():
    assert security.hash_token("abc") == security.hash_token("abc")
    import hashlib
    assert security.hash_token("abc") == hashlib.sha256(b"abc").hexdigest()
    assert security.hash_token("abc") != security.hash_token("abd")


# ── db helpers ──

def test_as_dict_passes_jsonb_dict_through_and_parses_legacy_text():
    assert db.as_dict({"a": 1}) == {"a": 1}
    assert db.as_dict('{"a": 1}') == {"a": 1}
    assert db.as_dict(b'{"a": 1}') == {"a": 1}


def test_ping_returns_false_when_database_unreachable(monkeypatch):
    def boom(*_a, **_k):
        raise RuntimeError("db down")
    monkeypatch.setattr(db, "query_one", boom)
    assert db.ping() is False


def test_transaction_commits_and_nests_flat(client):
    user_id = str(uuid.uuid4())
    with db.transaction():
        users_repo.insert_user(user_id, "outer")
        with db.transaction():  # nested: reuses the outer connection
            users_repo.touch(user_id)
    assert users_repo.get_user(user_id)["nickname"] == "outer"


def test_transaction_rolls_back_on_error(client):
    user_id = str(uuid.uuid4())
    with pytest.raises(RuntimeError):
        with db.transaction():
            users_repo.insert_user(user_id, "doomed")
            raise RuntimeError("force rollback")
    assert users_repo.get_user(user_id) is None


# ── redis client degradation ladder ──

def test_redis_client_none_when_disabled(monkeypatch):
    monkeypatch.setattr("app.core.config.redis_enabled", lambda: False)
    redis_client.reset()
    assert redis_client.get_client() is None
    assert redis_client.ping() is False


def test_redis_client_warns_once_when_unreachable(monkeypatch):
    monkeypatch.setattr("app.core.config.redis_enabled", lambda: True)
    monkeypatch.setattr("app.core.config.redis_url", lambda: "redis://127.0.0.1:1/0")
    redis_client.reset()
    import redis as redis_lib
    real_from_url = redis_lib.Redis.from_url

    def failing_from_url(*a, **k):
        client = real_from_url(*a, **k)
        client.setsockopt = client.setsockopt  # keep attrs
        raise ConnectionError("refused")
    monkeypatch.setattr(redis_lib.Redis, "from_url", staticmethod(failing_from_url))
    assert redis_client.get_client() is None
    assert redis_client.get_client() is None  # second call: still None, no crash
    redis_client.reset()


def test_redis_ping_false_when_client_raises(monkeypatch):
    class Broken:
        def ping(self):
            raise ConnectionError("gone")

    monkeypatch.setattr(redis_client, "get_client", lambda: Broken())
    assert redis_client.ping() is False


# ── rate limiter: redis down must degrade to memory, never fail ──

def test_ratelimit_falls_back_to_memory_when_redis_unavailable(monkeypatch):
    monkeypatch.setattr(redis_client, "get_client", lambda: None)
    ratelimit.reset()
    key = "bucket:fallback"
    assert ratelimit.allow(key, limit=2, window_seconds=60)
    assert ratelimit.allow(key, limit=2, window_seconds=60)
    assert not ratelimit.allow(key, limit=2, window_seconds=60)  # window full
    ratelimit.reset()


# ── migrations: skip non-sql files, skip applied versions ──

def test_migrations_skip_non_sql_and_applied_versions(client, monkeypatch, tmp_path):
    (tmp_path / "0099_unitscratch.sql").write_text(
        "CREATE TABLE IF NOT EXISTS unit_mig_scratch (id INT)", encoding="utf-8")
    (tmp_path / "README.txt").write_text("not sql", encoding="utf-8")
    monkeypatch.setattr(migrations, "MIGRATIONS_DIR", str(tmp_path))
    migrations.apply_all()
    migrations.apply_all()  # second pass: version already applied -> skipped
    rows = db.query_all("SELECT version FROM schema_migrations WHERE version = 99")
    assert [r["version"] for r in rows] == [99]


# ── service invariants that schemas make unreachable over HTTP ──

def test_wallet_append_rejects_delta_beyond_limit():
    with pytest.raises(ValueError):
        engagement_service.wallet_append("00000000-0000-0000-0000-000000000000", 2_000_000, "nope")
