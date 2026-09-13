"""Cloud save roundtrip, stale rejection, size gate."""

from tests.conftest import auth, register


def test_roundtrip_and_stale_rejection(client):
    user = register(client)
    auth(client, user)

    assert client.get("/api/v1/progress").status_code == 404
    body = {"state": {"coins": 5, "current_level_index": 2}, "updated_at": 1000}
    assert client.put("/api/v1/progress", json=body).json() == {"saved": True, "updated_at": 1000}
    got = client.get("/api/v1/progress").json()
    assert got["state"]["coins"] == 5 and got["updated_at"] == 1000

    stale = {"state": {"coins": 1}, "updated_at": 999}
    assert client.put("/api/v1/progress", json=stale).json() == {"saved": False, "updated_at": 1000}
    assert client.get("/api/v1/progress").json()["state"]["coins"] == 5

    equal = {"state": {"coins": 5, "current_level_index": 2, "extra": True}, "updated_at": 1000}
    assert client.put("/api/v1/progress", json=equal).json()["saved"] is True

    fresh = {"state": {"coins": 9}, "updated_at": 2000}
    assert client.put("/api/v1/progress", json=fresh).json()["saved"] is True
    assert client.get("/api/v1/progress").json()["state"]["coins"] == 9


def test_state_size_gate(client):
    user = register(client)
    auth(client, user)
    huge = {"blob": "x" * (300 * 1024)}
    resp = client.put("/api/v1/progress", json={"state": huge, "updated_at": 1})
    assert resp.status_code == 413
