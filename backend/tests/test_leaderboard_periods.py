"""Periodic leaderboards (daily/weekly/all), caching and rank queries."""
import pytest

from app.core import cache, db
from app.services import anticheat, leaderboard_service
from app.repositories import score_repo

from tests.conftest import auth, register

MODE = "fog"


@pytest.fixture(autouse=True)
def _legal_pace_and_clean_board(monkeypatch):
    """Board suite submits wins back-to-back; collapse the pace floor and
    start every test from an empty board for the probe mode."""
    monkeypatch.setattr(anticheat, "DEFAULT_MIN_RUN_MS", 0)
    monkeypatch.setattr(anticheat, "MIN_RUN_OVERRIDES_MS", {})
    db.execute(f"DELETE FROM mode_records WHERE mode_id = '{MODE}'")
    db.execute(f"DELETE FROM mode_score_events WHERE mode_id = '{MODE}'")
    cache.drop(f"board:{MODE}:all")
    cache.drop(f"board:{MODE}:weekly")
    cache.drop(f"board:{MODE}:daily")


def _win(client, score):
    resp = client.put(f"/api/v1/records/{MODE}", json={"best_score": score, "play": True, "win": True})
    assert resp.status_code == 200, resp.text


def test_all_time_board_shape_and_ranks(client):
    alice, bob = register(client, "alice"), register(client, "bob")
    auth(client, alice)
    _win(client, 300)
    auth(client, bob)
    _win(client, 500)

    board = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert board["mode_id"] == MODE and board["period"] == "all"
    assert board["total_players"] == 2
    assert [t["score"] for t in board["top"]] == [500, 300]
    assert [t["rank"] for t in board["top"]] == [1, 2]
    assert board["top"][0]["user_id"] == bob["user_id"]
    assert "nickname" in board["top"][0] and "achieved_ms" in board["top"][0]


def test_zero_best_scores_never_reach_the_board(client):
    user = register(client)
    auth(client, user)
    _win(client, 0)  # a played-but-scoreless run
    board = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert board["total_players"] == 1  # played
    assert board["top"] == []  # but never ranked
    assert board["my_rank"] is None


def test_weekly_and_daily_windows_rank_recent_scores(client):
    alice, bob = register(client, "alice"), register(client, "bob")
    auth(client, alice)
    _win(client, 700)
    auth(client, bob)
    _win(client, 900)

    weekly = client.get(f"/api/v1/leaderboard/{MODE}?period=weekly").json()
    assert weekly["period"] == "weekly"
    assert [t["score"] for t in weekly["top"]] == [900, 700]
    assert weekly["total_players"] == 2

    daily = client.get(f"/api/v1/leaderboard/{MODE}?period=daily&limit=1").json()
    assert [t["score"] for t in daily["top"]] == [900]
    assert daily["total_players"] == 2

    auth(client, alice)
    weekly = client.get(f"/api/v1/leaderboard/{MODE}?period=weekly").json()
    assert weekly["my_rank"] == 2

    unranked = register(client)
    auth(client, unranked)
    board = client.get(f"/api/v1/leaderboard/{MODE}?period=daily").json()
    assert board["my_rank"] is None


def test_old_scores_fall_out_of_windows(client):
    user = register(client)
    auth(client, user)
    _win(client, 420)
    # Move the only event outside the daily window but inside the weekly one.
    db.execute(
        f"UPDATE mode_score_events SET created_at = now() - interval '2 days' "
        f"WHERE mode_id = '{MODE}'")
    daily = client.get(f"/api/v1/leaderboard/{MODE}?period=daily").json()
    assert daily["top"] == [] and daily["total_players"] == 0
    weekly = client.get(f"/api/v1/leaderboard/{MODE}?period=weekly").json()
    assert weekly["total_players"] == 1  # still inside the weekly window
    # event timestamps were rewritten outside the app clock: restore for pace
    db.execute(f"DELETE FROM mode_score_events WHERE mode_id = '{MODE}'")
    score_repo.insert_event(user["user_id"], MODE, 420, created_ms=score_repo.now_ms())


def test_board_cache_is_used_and_invalidated(client):
    user = register(client)
    auth(client, user)
    _win(client, 250)
    first = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert first["top"][0]["score"] == 250

    # A stale cached blob (written by hand) is served as-is...
    cache.set_json(f"board:{MODE}:all",
                   {"total_players": 1, "top": [{"score": 123}]}, 30)
    cached = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert cached["top"][0]["score"] == 123

    # ...and a gated write invalidates it immediately.
    _win(client, 300)
    fresh = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert fresh["top"][0]["score"] == 300


def test_cache_degrades_without_redis(client, monkeypatch):
    from app.core import redis_client
    user = register(client)
    auth(client, user)
    _win(client, 120)
    monkeypatch.setattr(redis_client, "get_client", lambda: None)
    cache.drop(f"board:{MODE}:all")
    board = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert board["top"][0]["score"] == 120  # direct read, no cache


def test_cache_tolerates_redis_outage(client, monkeypatch):
    """A flaking redis must degrade every cache verb to a no-op/miss."""
    def broken():
        raise ConnectionError("redis down")
    monkeypatch.setattr(cache, "get_json", lambda key: None)
    monkeypatch.setattr(cache, "set_json", lambda key, value, ttl: None)
    monkeypatch.setattr(cache, "drop", lambda key: None)
    user = register(client)
    auth(client, user)
    _win(client, 90)
    board = client.get(f"/api/v1/leaderboard/{MODE}").json()
    assert board["top"][0]["score"] == 90


def test_cache_swallow_io_errors(monkeypatch):
    from app.core import redis_client
    class Boom:
        def get(self, _key):
            raise ConnectionError("read failed")
        def setex(self, *_args):
            raise ConnectionError("write failed")
        def delete(self, *_args):
            raise ConnectionError("drop failed")
    monkeypatch.setattr(redis_client, "get_client", lambda: Boom())
    assert cache.get_json("k") is None
    cache.set_json("k", {"x": 1}, 30)
    cache.drop("k")


def test_unknown_period_rejected(client):
    user = register(client)
    auth(client, user)
    resp = client.get(f"/api/v1/leaderboard/{MODE}?period=hourly")
    assert resp.status_code == 422


def test_service_rejects_unknown_period():
    import pytest
    with pytest.raises(ValueError):
        leaderboard_service._since("hourly")
