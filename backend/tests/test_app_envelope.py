"""App shell behaviours: error envelopes, health degradation, request ids —
plus the /me 404 branch when the account row vanished under a live token."""
import uuid

from fastapi.testclient import TestClient

from app.core import db
from app.main import app


def test_healthz_reports_503_when_db_down(monkeypatch):
    monkeypatch.setattr(db, "ping", lambda: False)
    client = TestClient(app)
    resp = client.get("/healthz")
    assert resp.status_code == 503
    assert resp.json() == {"ok": False, "db": False}


def test_unhandled_exception_returns_envelope_not_stacktrace():
    @app.get("/__unit_boom")
    def boom():
        raise RuntimeError("hidden from clients")

    try:
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.get("/__unit_boom")
        assert resp.status_code == 500
        body = resp.json()
        assert body["error"]["code"] == 500
        assert body["error"]["detail"] == "internal error"
    finally:
        app.router.routes = [r for r in app.router.routes if getattr(r, "path", "") != "/__unit_boom"]


def test_request_id_header_is_echoed(client):
    resp = client.get("/healthz", headers={"X-Request-Id": "unit-test-rid"})
    assert resp.headers["X-Request-Id"] == "unit-test-rid"


def test_me_returns_404_when_account_row_missing(client, monkeypatch):
    # auth_tokens FK-cascades on user deletion, so a valid token normally
    # implies a live account row; simulate the impossible state directly.
    monkeypatch.setattr("app.repositories.users_repo.get_user", lambda user_id: None)
    user = client.post("/api/v1/users/register", json={"nickname": "vanish"}).json()
    resp = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {user['token']}"})
    assert resp.status_code == 404
    assert resp.json()["error"]["detail"] == "user not found"


def test_refresh_rejects_unknown_token(client):
    resp = client.post("/api/v1/auth/refresh",
                       headers={"Authorization": f"Bearer {uuid.uuid4().hex}"})
    assert resp.status_code == 401
    assert resp.json()["error"]["detail"] == "invalid or expired token"


def test_healthz_stays_200_when_redis_is_down(client, monkeypatch):
    """Redis is an accelerator, not a dependency: the API reports the
    degradation but stays healthy."""
    from app.core import redis_client

    monkeypatch.setattr(redis_client, "ping", lambda: False)
    resp = client.get("/healthz")
    assert resp.status_code == 200
    body = resp.json()
    assert body == {"ok": True, "db": True, "redis": False}
