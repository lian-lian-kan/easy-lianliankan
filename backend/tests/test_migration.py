"""Pairing-code migration: issue, claim, single-use burn, session
revocation, expiry/consumed error shapes and rate limits."""

from tests.conftest import auth, register


def _push_save(client, stamp, coins=50):
    body = {"state": {"coins": coins, "current_level_index": 3}, "updated_at": stamp}
    assert client.put("/api/v1/progress", json=body).status_code == 200


def test_issue_code_requires_auth(client):
    # Session-scoped client: earlier test files may have left a bearer on it.
    client.headers.pop("Authorization", None)
    assert client.post("/api/v1/migration/code").status_code in (401, 403)


def test_generate_code_shape(client):
    user = register(client)
    auth(client, user)
    resp = client.post("/api/v1/migration/code")
    assert resp.status_code == 200
    payload = resp.json()
    assert payload["expires_in"] == 600
    bare = payload["code"].replace("-", "")
    assert len(bare) == 8
    assert all(ch in "23456789ABCDEFGHJKMNPQRSTUVWXYZ" for ch in bare)


def test_claim_moves_account_and_revokes_old_device(client):
    old = register(client, "old")
    auth(client, old)
    _push_save(client, 1000)
    code = client.post("/api/v1/migration/code").json()["code"]

    client.headers.pop("Authorization", None)
    # Typed with different case + stray separators: normalization forgives.
    claimed = client.post("/api/v1/migration/claim",
                          json={"code": " " + code.lower() + " "}).json()
    assert claimed["user_id"] == old["user_id"]
    assert claimed["token"] != old["token"]

    # The migrated save follows the account onto the new device.
    client.headers.update({"Authorization": f"Bearer {claimed['token']}"})
    save = client.get("/api/v1/progress").json()
    assert save["state"]["coins"] == 50

    # The old device's session is revoked: it can never push a stale save.
    client.headers.update({"Authorization": f"Bearer {old['token']}"})
    assert client.get("/api/v1/progress").status_code == 401
    assert client.get("/api/v1/users/me").status_code == 401


def test_regeneration_invalidates_previous_code(client):
    user = register(client)
    auth(client, user)
    first = client.post("/api/v1/migration/code").json()["code"]
    second = client.post("/api/v1/migration/code").json()["code"]
    assert first != second
    client.headers.pop("Authorization", None)
    assert client.post("/api/v1/migration/claim", json={"code": first}).status_code == 404
    assert client.post("/api/v1/migration/claim", json={"code": second}).status_code == 200


def test_unknown_and_malformed_codes_rejected(client):
    register(client)
    assert client.post("/api/v1/migration/claim", json={"code": "ZZZZ-ZZZZ"}).status_code == 404
    assert client.post("/api/v1/migration/claim", json={"code": "AB"}).status_code == 404
    assert client.post("/api/v1/migration/claim", json={"code": ""}).status_code == 422


def test_consumed_code_reports_409(client):
    user = register(client)
    auth(client, user)
    code = client.post("/api/v1/migration/code").json()["code"]
    client.headers.pop("Authorization", None)
    assert client.post("/api/v1/migration/claim", json={"code": code}).status_code == 200
    resp = client.post("/api/v1/migration/claim", json={"code": code})
    assert resp.status_code == 409


def test_expired_code_reports_410(client):
    from app.core import db
    user = register(client)
    auth(client, user)
    code = client.post("/api/v1/migration/code").json()["code"]
    db.execute("UPDATE migration_codes SET expires_at = now() - interval '1 minute' "
               "WHERE user_id = %s", (user["user_id"],))
    client.headers.pop("Authorization", None)
    # Expired codes never burn, so the row is still found but unusable.
    resp = client.post("/api/v1/migration/claim", json={"code": code})
    assert resp.status_code == 410


def test_claim_rate_limited(client):
    register(client)
    for _ in range(5):
        client.post("/api/v1/migration/claim", json={"code": "AAAA-BBBB"})
    assert client.post("/api/v1/migration/claim", json={"code": "AAAA-BBBB"}).status_code == 429


def test_generate_rate_limited(client):
    user = register(client)
    auth(client, user)
    assert client.post("/api/v1/migration/code").status_code == 200
    assert client.post("/api/v1/migration/code").status_code == 200
    assert client.post("/api/v1/migration/code").status_code == 429


def test_token_cache_entries_are_epoch_stamped(client):
    """A cached session whose account epoch moved (migration revocation)
    must read as a miss, never as trusted identity."""
    from app.core import cache, token_cache
    token_cache.store("t1", "user-e1")
    assert token_cache.lookup("t1") == "user-e1"

    cache.set_json(token_cache._key("t1"), "garbage", 60)
    assert token_cache.lookup("t1") is None
    cache.set_json(token_cache._key("t1"), [0], 60)
    assert token_cache.lookup("t1") is None

    token_cache.revoke_sessions("user-e1")
    cache.set_json(token_cache._key("t1"), [0, "user-e1"], 60)
    assert token_cache.lookup("t1") is None
