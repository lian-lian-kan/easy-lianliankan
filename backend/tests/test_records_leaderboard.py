"""Mode registry, per-mode records merge, leaderboards."""

import pytest

from app.core import db
from app.services import anticheat

from tests.conftest import auth, register


@pytest.fixture(autouse=True)
def _legal_run_spacing(monkeypatch):
    """The suite submits several wins back-to-back; collapse the pace floor
    so only the anticheat suite exercises the gate itself."""
    monkeypatch.setattr(anticheat, "DEFAULT_MIN_RUN_MS", 0)
    monkeypatch.setattr(anticheat, "MIN_RUN_OVERRIDES_MS", {})


def test_modes_registry_seeded(client):
    modes = client.get("/api/v1/modes").json()["modes"]
    ids = {m["mode_id"] for m in modes}
    assert {"daily", "zen", "duel", "sum10", "defense"} <= ids
    assert len(ids) == 27
    duel = next(m for m in modes if m["mode_id"] == "duel")
    assert duel["unlock_level"] == 17 and duel["label"] == "同屏对战"


def test_record_merge_and_listing(client):
    user = register(client)
    auth(client, user)

    first = client.put("/api/v1/records/zen", json={"best_score": 120, "play": True, "win": True})
    assert first.status_code == 200
    assert first.json()["record"] == {"best_score": 120, "plays": 1, "wins": 1, "updated_at": first.json()["record"]["updated_at"]}

    worse = client.put("/api/v1/records/zen", json={"best_score": 90, "play": True, "win": False})
    rec = worse.json()["record"]
    assert rec["best_score"] == 120 and rec["plays"] == 2 and rec["wins"] == 1

    better = client.put("/api/v1/records/zen", json={"best_score": 200, "play": True, "win": True})
    assert better.json()["record"]["best_score"] == 200

    records = {r["mode_id"]: r for r in client.get("/api/v1/records").json()["records"]}
    assert records["zen"]["best_score"] == 200
    assert records["daily"]["best_score"] == 0  # unplayed modes still listed


def test_unknown_mode_rejected(client):
    user = register(client)
    auth(client, user)
    resp = client.put("/api/v1/records/nope", json={"best_score": 1})
    assert resp.status_code == 404


def test_leaderboard_ranks(client):
    # rerunnable: prior runs of this suite must not shift the exact ranks
    db.execute("DELETE FROM mode_records WHERE mode_id = 'hell'")
    db.execute("DELETE FROM mode_score_events WHERE mode_id = 'hell'")
    alice, bob = register(client, "alice"), register(client, "bob")
    auth(client, alice)
    client.put("/api/v1/records/hell", json={"best_score": 500, "play": True, "win": True})
    auth(client, bob)
    client.put("/api/v1/records/hell", json={"best_score": 800, "play": True, "win": True})

    board = client.get("/api/v1/leaderboard/hell").json()
    assert [t["score"] for t in board["top"]] == [800, 500]
    assert board["top"][0]["nickname"] == "bob"
    assert board["top"][0]["rank"] == 1
    assert board["my_rank"] == 1  # bob is asking

    auth(client, alice)
    assert client.get("/api/v1/leaderboard/hell").json()["my_rank"] == 2
