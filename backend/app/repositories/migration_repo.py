"""SQL for device-to-device migration pairing codes."""
from ..core import config, db, security


def hash_code(code: str) -> str:
    """Peppered hash: the ~2^40 code space stays uncrackable offline even if
    the database leaks (the pepper lives in the environment, not the DB)."""
    return security.hash_token(config.migration_pepper() + code)


def replace_user_code(code: str, user_id: str, expires_at) -> None:
    """One active code per account: mint the new one, drop every old row so
    a photographed stale code can never be claimed later."""
    with db.transaction():
        db.execute("DELETE FROM migration_codes WHERE user_id = %s", (user_id,))
        db.execute(
            "INSERT INTO migration_codes (code_hash, user_id, expires_at) VALUES (%s, %s, %s)",
            (hash_code(code), user_id, expires_at),
        )


def consume(code: str):
    """Atomically burn the code and return the bound user_id, or None.

    The conditional UPDATE is the single-use guarantee: two concurrent
    claims race on consumed_at IS NULL and exactly one row comes back.
    Expired codes never match, so expiry and unknown share the miss path.
    """
    return db.query_one(
        "UPDATE migration_codes SET consumed_at = now() "
        "WHERE code_hash = %s AND consumed_at IS NULL AND expires_at > now() "
        "RETURNING user_id::text",
        (hash_code(code),),
    )


def find_by_hash(code: str):
    """Post-mortem lookup for precise claim errors (used vs expired)."""
    return db.query_one(
        "SELECT consumed_at, expires_at FROM migration_codes WHERE code_hash = %s",
        (hash_code(code),),
    )


def delete_expired() -> int:
    """Codes die by TTL anyway; drop expired rows so the table stays tiny."""
    row = db.query_one(
        "WITH gone AS (DELETE FROM migration_codes WHERE expires_at < now() RETURNING 1) "
        "SELECT COUNT(*) AS removed FROM gone"
    )
    return int(row["removed"]) if row else 0
