"""Environment-driven configuration.

Defaults point at the K8S cluster's in-cluster service hostnames (never IPs):
postgres/redis live in the `database` namespace — see local-server-001:~/k8s-service.txt.
Outside the cluster, override via env with the node hostname + NodePort, e.g.
DATABASE_URL=postgresql://root:nopasswd@local-server-002:30432/lianlian
REDIS_URL=redis://local-server-002:30379/0
"""
import os

# In-cluster service hostnames (cluster DNS), namespace: database
PG_HOST = "postgres.database.svc.cluster.local"
PG_PORT = 5432
REDIS_HOST = "redis.database.svc.cluster.local"
REDIS_PORT = 6379


def database_url() -> str:
    return os.environ.get(
        "DATABASE_URL",
        f"postgresql://root:nopasswd@{PG_HOST}:{PG_PORT}/lianlian",
    )


def redis_url() -> str:
    return os.environ.get("REDIS_URL", f"redis://{REDIS_HOST}:{REDIS_PORT}/0")


def redis_enabled() -> bool:
    return os.environ.get("REDIS_ENABLED", "1") == "1"


def max_state_bytes() -> int:
    return int(os.environ.get("MAX_STATE_BYTES", "262144"))


def max_wallet_delta() -> int:
    return int(os.environ.get("MAX_WALLET_DELTA", "1000000"))


def pool_min() -> int:
    return int(os.environ.get("PG_POOL_MIN", "1"))


def pool_max() -> int:
    # 16/replica: with 2 replicas this stays well under the PG default
    # max_connections=100 while covering sync bursts (see docs/backend-scale.md).
    return int(os.environ.get("PG_POOL_MAX", "16"))


def token_ttl_days() -> int:
    return int(os.environ.get("TOKEN_TTL_DAYS", "90"))


def register_limit_per_minute() -> int:
    """Per-IP register ceiling. Production keeps the default; load tests
    raise it so virtual users from one IP don't spend 20 minutes in backoff."""
    return int(os.environ.get("REGISTER_RATE_LIMIT", "10"))


def thread_capacity() -> int:
    """Worker threads for the sync DB layer. Must exceed pool_max() so
    requests queue on threads briefly instead of erroring on the pool."""
    return int(os.environ.get("THREAD_CAPACITY", "100"))


def migration_code_ttl_seconds() -> int:
    """Pairing codes are a live hand-off: both devices sit on the migration
    page, so ten minutes is generous. Short TTL + single use + IP rate limit
    is what makes brute force hopeless (see migration_service)."""
    return int(os.environ.get("MIGRATION_CODE_TTL_SECONDS", "600"))


def migration_pepper() -> str:
    """Server-side secret mixed into pairing-code hashes: a ~2^40 code space
    is brute-forceable offline from a leaked DB without it. Set via K8S
    secret in production; empty in dev (hashes degrade to plain SHA-256)."""
    return os.environ.get("MIGRATION_PEPPER", "")


# The game page runs on GitHub Pages; browsers enforce CORS there. Add more
# origins (comma separated) via env when the page moves to its own domain.
_DEFAULT_ALLOWED_ORIGINS = "https://lian-lian-kan.github.io"


def allowed_origins() -> list:
    raw = os.environ.get("ALLOWED_ORIGINS", _DEFAULT_ALLOWED_ORIGINS)
    return [origin.strip() for origin in raw.split(",") if origin.strip()]
