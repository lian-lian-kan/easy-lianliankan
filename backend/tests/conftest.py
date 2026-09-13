"""Shared fixtures: TestClient against the real PG (CI service container)."""
import os
import uuid

import pytest
from fastapi.testclient import TestClient

from app import db
from app.main import app

pytestmark = pytest.mark.skipif(
    os.environ.get("SKIP_PG_TESTS", "") == "1",
    reason="needs a PostgreSQL DATABASE_URL",
)


@pytest.fixture(scope="session")
def client():
    db.init_pool()
    from app.core import migrations
    migrations.apply_all()
    with TestClient(app) as c:
        yield c
    db.close_pool()


def register(client, nickname="tester") -> dict:
    resp = client.post("/api/v1/users/register", json={"nickname": nickname})
    assert resp.status_code == 201, resp.text
    return resp.json()


def auth(client, user: dict):
    """Convenience: set the bearer header for subsequent calls."""
    client.headers.update({"Authorization": f"Bearer {user['token']}"})
    return client


def unique_suffix() -> str:
    return uuid.uuid4().hex[:8]
