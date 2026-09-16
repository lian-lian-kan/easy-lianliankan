"""Docs drift guard: the rate-limit matrix in README.md must match the
limits actually wired in the routers. Fails when either side changes alone."""
import re

from tests.conftest import auth, register

ROUTERS = ["progress", "records", "engagement", "auth", "users", "migration"]

# bucket -> README table row prefix (the path cell that mentions it)
README_ROW = {
    "progress_put": "PUT `/progress`",
    "records_put": "PUT `/records/{mode_id}`",
    "achievement": "POST `/achievements/{id}`",
    "missions_put": "PUT `/missions`",
    "wallet": "POST `/wallet/entries`",
    "signin": "POST `/signin`",
    "refresh": "POST `/auth/refresh`",
    "migration_claim": "POST `/migration/claim`",
}


def _collect_limits() -> dict:
    """bucket -> (ip_limit, user_limit or None) straight from the routers."""
    limits = {}
    for name in ROUTERS:
        src = open(f"app/routers/{name}.py", encoding="utf-8").read()
        for m in re.finditer(r'(?<!user_)rate_limit\("(\w+)", limit=(\d+)', src):
            limits.setdefault(m.group(1), {})["ip"] = int(m.group(2))
        for m in re.finditer(r'user_rate_limit\("(\w+)", limit=(\d+)', src):
            limits.setdefault(m.group(1), {})["user"] = int(m.group(2))
    return limits


def test_ratelimit_matrix_matches_readme():
    limits = _collect_limits()
    readme = open("README.md", encoding="utf-8").read()

    assert limits["progress_put"] == {"ip": 3000, "user": 60}
    assert limits["records_put"] == {"ip": 3000, "user": 60}
    assert limits["achievement"] == {"ip": 3000, "user": 60}
    assert limits["missions_put"] == {"ip": 3000, "user": 60}
    assert limits["wallet"] == {"ip": 1500, "user": 30}
    assert limits["signin"] == {"ip": 300, "user": 10}
    assert limits["refresh"] == {"ip": 300}  # IP-only: refresh precedes user resolution
    # Pairing codes: issue is per-account (old device), claim is anonymous
    # and attacker-facing, so it gets the tightest IP ceiling in the API.
    assert limits["migration_code"] == {"user": 2}
    assert limits["migration_claim"] == {"ip": 5}

    for bucket, row in README_ROW.items():
        if bucket not in limits:
            continue
        line = next(ln for ln in readme.splitlines() if ln.startswith("| " + row))
        ip = limits[bucket]["ip"]
        assert f"{ip}/min/IP" in line, f"{bucket}: IP limit missing in docs"
        if "user" in limits[bucket]:
            assert f"{limits[bucket]['user']}/min/user" in line, \
                f"{bucket}: user limit missing in docs"
