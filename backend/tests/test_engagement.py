"""Achievements, weekly missions, wallet ledger, sign-ins."""

from tests.conftest import auth, register


def test_achievements_idempotent(client):
    user = register(client)
    auth(client, user)
    first = client.post("/api/v1/achievements/rock_first").json()
    assert first == {"newly_unlocked": True}
    again = client.post("/api/v1/achievements/rock_first").json()
    assert again == {"newly_unlocked": False}
    ids = [a["achievement_id"] for a in client.get("/api/v1/achievements").json()["achievements"]]
    assert ids == ["rock_first"]


def test_missions_upsert_and_claim(client):
    user = register(client)
    auth(client, user)
    body = {"mission_id": "pairs_30", "week_key": 1000, "progress": 10, "claimed": False}
    assert client.put("/api/v1/missions", json=body).json()["mission"]["progress"] == 10
    higher = {"mission_id": "pairs_30", "week_key": 1000, "progress": 25, "claimed": False}
    assert client.put("/api/v1/missions", json=higher).json()["mission"]["progress"] == 25
    lower = {"mission_id": "pairs_30", "week_key": 1000, "progress": 5, "claimed": True}
    merged = client.put("/api/v1/missions", json=lower).json()["mission"]
    assert merged["progress"] == 25 and merged["claimed"] is True
    missions = client.get("/api/v1/missions", params={"week_key": 1000}).json()["missions"]
    assert [m["mission_id"] for m in missions] == ["pairs_30"]


def test_wallet_ledger_and_signin(client):
    user = register(client)
    auth(client, user)
    assert client.get("/api/v1/wallet").json()["balance"] == 0
    client.post("/api/v1/wallet/entries", json={"delta": 20, "reason": "clear_bonus"})
    client.post("/api/v1/wallet/entries", json={"delta": -5, "reason": "hint"})
    wallet = client.get("/api/v1/wallet").json()
    assert wallet["balance"] == 15
    assert [e["reason"] for e in wallet["entries"]] == ["hint", "clear_bonus"]

    day = {"day": "2026-09-13", "streak": 3}
    assert client.post("/api/v1/signin", json=day).json()["first_today"] is True
    assert client.post("/api/v1/signin", json=day).json()["first_today"] is False
    signins = client.get("/api/v1/signin").json()["signins"]
    assert signins[0]["streak"] == 3
