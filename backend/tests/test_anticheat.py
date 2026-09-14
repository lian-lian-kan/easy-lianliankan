"""Anticheat gates: ceiling, pace, intake extraction and silent isolation."""
import pytest

from app.services import anticheat, records_service, score_intake
from app.repositories import score_repo

from tests.conftest import auth, register


@pytest.fixture
def fast_pace(monkeypatch):
    """Treat any spacing as a legal run gap (time-flight for pace tests)."""
    monkeypatch.setattr(anticheat, "DEFAULT_MIN_RUN_MS", 0)


@pytest.fixture
def anticheat_off(monkeypatch):
    monkeypatch.setenv("ANTICHEAT_OFF", "1")


def _blob(**scores):
    daily = scores.pop("daily", 0)
    state = {f"{mode}_best_score": value for mode, value in scores.items()}
    state["daily_challenge"] = {"best_score": daily}
    return state


def test_gates_constants():
    assert anticheat.max_score() == 500_000
    assert anticheat.min_run_ms("hell") == 60_000
    assert anticheat.min_run_ms("zen") == 15_000
    assert anticheat.check_score(0) and anticheat.check_score(500_000)
    assert not anticheat.check_score(500_001) and not anticheat.check_score(-1)


def test_enabled_kill_switch(anticheat_off):
    assert anticheat.enabled() is False


def test_enabled_by_default(monkeypatch):
    monkeypatch.delenv("ANTICHEAT_OFF", raising=False)
    assert anticheat.enabled() is True


def test_extract_known_keys_and_clamps():
    full = {
        "time_attack_best_score": 120,
        "endless_best": {"round": 3, "score": 45},
        "daily_challenge": {"best_score": 77, "streak": 1},
        "zen_best_score": -5,
        "hell_best_score": 9,
    }
    scores = score_intake.extract(full)
    assert scores["time_attack"] == 120
    assert scores["endless"] == 45
    assert scores["daily"] == 77
    assert scores["zen"] == 0  # negatives clamp to zero
    assert scores["hell"] == 9
    assert len(scores) == 5


def test_extract_ignores_missing_and_malformed():
    assert score_intake.extract({}) == {}
    assert score_intake.extract({"endless_best": "not-a-dict"}) == {}
    assert score_intake.extract({"daily_challenge": [1, 2]}) == {}
    assert score_intake.extract({"zen_best_score": "42"}) == {"zen": 42}


def test_extract_tolerates_non_dict_state():
    assert score_intake.extract(None) == {}
    assert score_intake.extract("junk") == {}


def test_intake_records_first_and_better_scores(client):
    user = register(client)
    now = score_repo.now_ms()
    prev = _blob(zen=100)
    new = _blob(zen=250, hell=4000)
    accepted = score_intake.process(user["user_id"], prev, new, now_ms=now)
    assert {"mode_id": "zen", "score": 250} in accepted
    assert {"mode_id": "hell", "score": 4000} in accepted
    assert score_repo.last_event_ms(user["user_id"], "zen") is not None
    assert score_repo.last_event_ms(user["user_id"], "fog") is None


def test_intake_skips_unchanged_and_lowered_scores(client):
    user = register(client)
    now = score_repo.now_ms()
    assert score_intake.process(user["user_id"], _blob(zen=100), _blob(zen=100), now_ms=now) == []
    assert score_intake.process(user["user_id"], _blob(zen=300), _blob(zen=100), now_ms=now) == []


def test_intake_ceiling_rejects_without_events(client):
    user = register(client)
    accepted = score_intake.process(
        user["user_id"], None, _blob(zen=999_999), now_ms=score_repo.now_ms())
    assert accepted == []
    assert score_repo.last_event_ms(user["user_id"], "zen") is None


def test_intake_pace_gate_blocks_rapid_second_score(client):
    user = register(client)
    now = score_repo.now_ms()
    assert score_intake.process(user["user_id"], None, _blob(zen=100), now_ms=now)
    # A second improve inside the 15s floor stays off the boards.
    assert score_intake.process(user["user_id"], _blob(zen=100), _blob(zen=200),
                                now_ms=now + 1_000) == []
    # After the floor has elapsed the score is accepted again.
    later = score_repo.last_event_ms(user["user_id"], "zen") + 16_000
    accepted = score_intake.process(user["user_id"], _blob(zen=100), _blob(zen=300),
                                    now_ms=later)
    assert accepted == [{"mode_id": "zen", "score": 300}]


def test_intake_bypass_writes_even_absurd_scores(client, anticheat_off):
    user = register(client)
    accepted = score_intake.process(
        user["user_id"], None, _blob(zen=999_999), now_ms=score_repo.now_ms())
    assert accepted == [{"mode_id": "zen", "score": 999_999}]


def test_rest_record_ceiling_rejected(client):
    user = register(client)
    auth(client, user)
    resp = client.put("/api/v1/records/zen", json={"best_score": 10_000_000, "win": True})
    assert resp.status_code == 422
    assert "ceiling" in resp.json()["error"]["detail"]


def test_rest_record_pace_rejected(client):
    user = register(client)
    auth(client, user)
    assert client.put("/api/v1/records/zen", json={"best_score": 10, "win": True}).status_code == 200
    fast = client.put("/api/v1/records/zen", json={"best_score": 20, "win": True})
    assert fast.status_code == 422
    assert "fast" in fast.json()["error"]["detail"]


def test_rest_record_bypass_accepts_anything(client, anticheat_off):
    user = register(client)
    auth(client, user)
    resp = client.put("/api/v1/records/zen", json={"best_score": 10_000_000, "win": True})
    assert resp.status_code == 200


def test_rest_play_only_stays_off_events(client, fast_pace):
    user = register(client)
    auth(client, user)
    resp = client.put("/api/v1/records/zen", json={"best_score": 0, "play": True, "win": False})
    assert resp.status_code == 200
    assert score_repo.last_event_ms(user["user_id"], "zen") is None
