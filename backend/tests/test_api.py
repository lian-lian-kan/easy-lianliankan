"""API tests. Require a reachable PostgreSQL via DATABASE_URL (CI provides a
service container); every test uses a unique player id so runs are repeatable."""
import os
import uuid

import pytest
from fastapi.testclient import TestClient

from app import store
from app.main import app, _require_player_id

pytestmark = pytest.mark.skipif(
    os.environ.get("SKIP_PG_TESTS", "") == "1",
    reason="needs a PostgreSQL DATABASE_URL",
)


@pytest.fixture(scope="module")
def client():
    store.init_pool()
    store.ensure_schema()
    with TestClient(app) as c:
        # TestClient triggers lifespan again; ensure_schema is idempotent.
        yield c
    store.close_pool()


def _pid() -> str:
    return uuid.uuid4().hex


def test_healthz(client):
    assert client.get("/healthz").json() == {"ok": True}


def test_player_id_validation(client):
    assert client.get("/api/v1/progress/short").status_code == 400
    assert client.get("/api/v1/progress/" + "g" * 32).status_code == 400


def test_roundtrip_and_stale_rejection(client):
    pid = _pid()
    assert client.get(f"/api/v1/progress/{pid}").status_code == 404

    body = {"state": {"coins": 5, "current_level_index": 2}, "updated_at": 1000}
    assert client.put(f"/api/v1/progress/{pid}", json=body).json() == {
        "saved": True,
        "updated_at": 1000,
    }
    got = client.get(f"/api/v1/progress/{pid}").json()
    assert got["state"]["coins"] == 5
    assert got["updated_at"] == 1000

    # Stale write must be refused and leave the server copy untouched.
    stale = {"state": {"coins": 1}, "updated_at": 999}
    r = client.put(f"/api/v1/progress/{pid}", json=stale)
    assert r.json() == {"saved": False, "updated_at": 1000}
    assert client.get(f"/api/v1/progress/{pid}").json()["state"]["coins"] == 5

    # Newer write wins.
    fresh = {"state": {"coins": 9}, "updated_at": 2000}
    assert client.put(f"/api/v1/progress/{pid}", json=fresh).json()["saved"] is True
    assert client.get(f"/api/v1/progress/{pid}").json()["state"]["coins"] == 9


def test_equal_timestamp_overwrites(client):
    """Same-timestamp writes land (idempotent re-push after throttle)."""
    pid = _pid()
    body = {"state": {"a": 1}, "updated_at": 500}
    assert client.put(f"/api/v1/progress/{pid}", json=body).json()["saved"] is True
    assert client.put(f"/api/v1/progress/{pid}", json=body).json()["saved"] is True


def test_player_id_guard_unit():
    assert _require_player_id("a" * 32) is None
    with pytest.raises(Exception):
        _require_player_id("xyz")
