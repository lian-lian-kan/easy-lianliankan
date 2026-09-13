"""Registration, profile, rename, token refresh and auth failures."""


def test_register_and_profile(client):
    user = register(client, "sophia")
    assert len(user["user_id"]) == 36 and len(user["token"]) == 64
    auth(client, user)
    me = client.get("/api/v1/users/me").json()
    assert me["nickname"] == "sophia" and me["user_id"] == user["user_id"]


def test_rename(client):
    user = register(client)
    auth(client, user)
    assert client.post("/api/v1/users/rename", json={"nickname": "老公"}).json() == {"ok": True}
    assert client.get("/api/v1/users/me").json()["nickname"] == "老公"


def test_token_refresh_rotates(client):
    user = register(client)
    auth(client, user)
    new_token = client.post("/api/v1/auth/refresh").json()["token"]
    assert new_token != user["token"]
    # Old token is revoked, new one works.
    client.headers.update({"Authorization": f"Bearer {user['token']}"})
    assert client.get("/api/v1/users/me").status_code == 401
    client.headers.update({"Authorization": f"Bearer {new_token}"})
    assert client.get("/api/v1/users/me").status_code == 200


def test_missing_or_bad_token_rejected(client):
    client.headers.pop("Authorization", None)
    assert client.get("/api/v1/progress").status_code in (401, 403)
    client.headers.update({"Authorization": "Bearer " + "0" * 128})
    assert client.get("/api/v1/progress").status_code == 401
