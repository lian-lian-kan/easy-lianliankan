"""Capacity path: token cache short-circuits, throttled presence writes."""
import pytest

from app.core import redis_client, token_cache
from app.repositories import users_repo
from app.services import user_service

from tests.conftest import auth, register


def test_token_cache_roundtrip():
    assert token_cache.lookup("no-such-token") is None
    token_cache.store("a-token", "user-1")
    assert token_cache.lookup("a-token") == "user-1"
    token_cache.invalidate("a-token")
    assert token_cache.lookup("a-token") is None


def test_token_cache_keys_are_hashed_not_raw():
    """Only token hashes may live in redis, never the bearer value itself."""
    raw = redis_client.get_client().keys("*")
    token_cache.store("super-secret-bearer", "user-2")
    after = redis_client.get_client().keys("*")
    new_keys = [k.decode() for k in after if k not in raw]
    assert new_keys and all("super-secret-bearer" not in k for k in new_keys)


def test_current_user_served_from_cache(client, monkeypatch):
    user = register(client)
    auth(client, user)
    assert client.get("/api/v1/users/me").status_code == 200  # backfills cache

    def explode(_token):
        raise AssertionError("DB must not be hit on a cache hit")
    monkeypatch.setattr(users_repo, "find_active_user_by_token", explode)
    resp = client.get("/api/v1/users/me")
    assert resp.status_code == 200 and resp.json()["user_id"] == user["user_id"]


def test_refresh_invalidates_cached_token(client):
    user = register(client)
    auth(client, user)
    client.get("/api/v1/users/me")  # cache the old token

    fresh = client.post("/api/v1/auth/refresh").json()["token"]
    client.headers.update({"Authorization": f"Bearer {user['token']}"})
    assert client.get("/api/v1/users/me").status_code == 401  # old is dead now
    client.headers.update({"Authorization": f"Bearer {fresh}"})
    assert client.get("/api/v1/users/me").status_code == 200


def test_touch_throttled_collapses_hot_writes(client, monkeypatch):
    user = register(client)
    calls = []
    monkeypatch.setattr(users_repo, "touch", lambda uid: calls.append(uid))
    user_service.touch_throttled(user["user_id"])
    user_service.touch_throttled(user["user_id"])
    user_service.touch_throttled(user["user_id"])
    assert calls == [user["user_id"]]  # first write wins, rest collapse


def test_touch_throttled_degrades_to_write_without_redis(client, monkeypatch):
    user = register(client)
    calls = []
    monkeypatch.setattr(users_repo, "touch", lambda uid: calls.append(uid))
    monkeypatch.setattr(redis_client, "get_client", lambda: None)
    user_service.touch_throttled(user["user_id"])
    user_service.touch_throttled(user["user_id"])
    assert len(calls) == 2  # no throttle available: always write


def test_touch_throttled_tolerates_redis_errors(client, monkeypatch):
    user = register(client)
    calls = []
    monkeypatch.setattr(users_repo, "touch", lambda uid: calls.append(uid))

    def broken_get():
        raise ConnectionError("redis down")
    monkeypatch.setattr(redis_client, "get_client", broken_get)
    user_service.touch_throttled(user["user_id"])
    assert calls == [user["user_id"]]
