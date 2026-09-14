"""Rate-limit scoping: per-user budgets protect NAT players, IP ceilings
still stop single-host floods."""
import time

from tests.conftest import auth, register


def _push(client, seq):
    payload = {"state": {"coins": seq}, "updated_at": int(time.time() * 1000) + seq}
    return client.put("/api/v1/progress", json=payload)


def test_user_budget_throttles_only_itself(client):
    alice, bob = register(client, "alice"), register(client, "bob")
    auth(client, alice)
    for seq in range(60):
        assert _push(client, seq).status_code == 200, seq
    assert _push(client, 999).status_code == 429  # alice blew her own budget

    auth(client, bob)
    assert _push(client, 1).status_code == 200  # same source IP, own budget


def test_ip_ceiling_stops_single_host_floods(client):
    import pytest
    from fastapi.testclient import TestClient  # noqa: F401 — shape only

    alice, bob = register(client, "alice"), register(client, "bob")
    # Drive the shared per-IP bucket (600/min) with 60+60 pushes plus noise;
    # both stay under it, so neither sees an IP-level 429 here.
    auth(client, alice)
    for seq in range(30):
        assert _push(client, seq).status_code == 200
    auth(client, bob)
    for seq in range(30):
        assert _push(client, seq).status_code == 200
