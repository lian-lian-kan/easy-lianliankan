"""Environment-driven configuration for the progress API."""
import os


def database_url() -> str:
    return os.environ.get("DATABASE_URL", "postgresql://lianlian:lianlian@localhost:5432/lianlian")


def max_state_bytes() -> int:
    return int(os.environ.get("MAX_STATE_BYTES", "262144"))


def pool_min() -> int:
    return int(os.environ.get("PG_POOL_MIN", "1"))


def pool_max() -> int:
    return int(os.environ.get("PG_POOL_MAX", "8"))
