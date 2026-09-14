"""Storage & API performance: balance cache, gzip, retention, pool safety."""
import time

import psycopg2
import pytest

from app.core import db, maintenance, redis_client
from app.repositories import engagement_repo, score_repo
from app.services import engagement_service

from tests.conftest import auth, register


def test_pool_survives_concurrent_checkouts(client):
    """ThreadedConnectionPool: parallel sync workers race getconn/putconn."""
    assert isinstance(db._pool, psycopg2.pool.ThreadedConnectionPool)
    import threading
    errors = []

    def hammer():
        try:
            for _ in range(20):
                db.query_one("SELECT 1 AS ok")
        except Exception as exc:  # pragma: no cover - only on regression
            errors.append(exc)

    threads = [threading.Thread(target=hammer) for _ in range(16)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert errors == []


def test_balance_served_from_cache(client, monkeypatch):
    user = register(client)
    auth(client, user)
    client.post("/api/v1/wallet/entries",
                json={"delta": 5, "reason": "test"}).raise_for_status()

    def explode(_user_id):
        raise AssertionError("balance must come from cache, not the ledger")
    monkeypatch.setattr(engagement_repo, "ledger_balance", explode)
    resp = client.get("/api/v1/wallet")
    assert resp.json()["balance"] == 5


def test_balance_degrades_to_ledger_without_redis(client, monkeypatch):
    user = register(client)
    auth(client, user)
    client.post("/api/v1/wallet/entries",
                json={"delta": 7, "reason": "test"}).raise_for_status()
    monkeypatch.setattr(redis_client, "get_client", lambda: None)
    resp = client.get("/api/v1/wallet")
    assert resp.json()["balance"] == 7


def test_balance_refreshes_after_append(client, monkeypatch):
    user = register(client)
    auth(client, user)
    client.post("/api/v1/wallet/entries",
                json={"delta": 5, "reason": "test"}).raise_for_status()
    client.post("/api/v1/wallet/entries",
                json={"delta": 3, "reason": "test"}).raise_for_status()
    # with the ledger read broken, only the cache can answer: it must hold
    # the balance the last append wrote, not a stale earlier one
    def explode(_user_id):
        raise AssertionError("balance must come from the refreshed cache")
    monkeypatch.setattr(engagement_repo, "ledger_balance", explode)
    resp = client.get("/api/v1/wallet")
    assert resp.json()["balance"] == 8


def test_balance_tolerates_redis_outage_on_append(client, monkeypatch):
    user = register(client)
    auth(client, user)

    def broken():
        raise ConnectionError("redis down")
    monkeypatch.setattr(redis_client, "get_client", broken)
    resp = client.post("/api/v1/wallet/entries",
                       json={"delta": 2, "reason": "test"})
    assert resp.status_code == 200 and resp.json()["balance"] == 2


def test_gzip_compresses_large_progress_responses(client):
    user = register(client)
    auth(client, user)
    big = {"pad": "x" * 8000, "zen_best_score": 1}
    import time as _time
    client.put("/api/v1/progress",
               json={"state": big, "updated_at": int(_time.time() * 1000)})
    resp = client.get("/api/v1/progress")
    assert resp.headers.get("content-encoding") == "gzip"


def test_small_responses_stay_uncompressed(client):
    user = register(client)
    auth(client, user)
    resp = client.get("/api/v1/users/me")
    assert resp.headers.get("content-encoding") is None


def test_prune_removes_only_expired_events(client):
    user = register(client)
    old_ms = score_repo.now_ms() - 91 * 86_400_000
    score_repo.insert_event(user["user_id"], "zen", 10, created_ms=old_ms)
    score_repo.insert_event(user["user_id"], "zen", 20)  # fresh
    removed = maintenance.prune_events()
    assert removed >= 1
    assert score_repo.last_event_ms(user["user_id"], "zen") is not None  # fresh survives


class _FlakyRedis:
    """Redis client whose every verb raises: cache must degrade silently."""

    def get(self, _key):
        raise ConnectionError("get failed")

    def setex(self, *_args):
        raise ConnectionError("setex failed")


def test_balance_survives_redis_read_and_write_failures(client, monkeypatch):
    user = register(client)
    auth(client, user)
    monkeypatch.setattr(redis_client, "get_client", lambda: _FlakyRedis())
    client.post("/api/v1/wallet/entries",
                json={"delta": 4, "reason": "test"}).raise_for_status()
    resp = client.get("/api/v1/wallet")
    assert resp.json()["balance"] == 4  # fell back to the ledger both times


def test_append_skips_cache_write_without_redis(client, monkeypatch):
    user = register(client)
    auth(client, user)
    monkeypatch.setattr(redis_client, "get_client", lambda: None)
    resp = client.post("/api/v1/wallet/entries",
                       json={"delta": 6, "reason": "test"})
    assert resp.status_code == 200 and resp.json()["balance"] == 6
