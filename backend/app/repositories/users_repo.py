"""SQL for accounts and tokens."""
from ..core import db, security


def insert_user(user_id: str, nickname: str) -> None:
    db.execute(
        "INSERT INTO users (user_id, nickname) VALUES (%s, %s)",
        (user_id, nickname),
    )


def get_user(user_id: str):
    return db.query_one(
        "SELECT user_id::text, nickname, created_at, last_seen_at FROM users WHERE user_id = %s",
        (user_id,),
    )


def touch(user_id: str) -> None:
    db.execute("UPDATE users SET last_seen_at = now() WHERE user_id = %s", (user_id,))


def rename(user_id: str, nickname: str) -> None:
    db.execute(
        "UPDATE users SET nickname = %s WHERE user_id = %s",
        (nickname, user_id),
    )


def insert_token(token: str, user_id: str, expires_at) -> None:
    db.execute(
        "INSERT INTO auth_tokens (token_hash, user_id, expires_at) VALUES (%s, %s, %s)",
        (security.hash_token(token), user_id, expires_at),
    )


def find_active_user_by_token(token: str):
    return db.query_one(
        "SELECT user_id FROM auth_tokens WHERE token_hash = %s AND expires_at > now()",
        (security.hash_token(token),),
    )



def delete_token(token: str) -> None:
    db.execute("DELETE FROM auth_tokens WHERE token_hash = %s", (security.hash_token(token),))


def revoke_other_tokens(user_id: str, keep_token_hash: str) -> None:
    """Migration safety: after a pairing-code claim, every other device's
    session dies — a forgotten old device can never push a stale save over
    the one the player just migrated to. The fresh token's own cache entry
    is unaffected; revoked ones age out of the cache within its short TTL."""
    db.execute(
        "DELETE FROM auth_tokens WHERE user_id = %s AND token_hash <> %s",
        (user_id, keep_token_hash),
    )


def delete_expired_tokens() -> int:
    """Rows past expiry can never authenticate again; drop them so abandoned
    accounts don't leave the token table growing forever."""
    row = db.query_one(
        """
        WITH gone AS (
            DELETE FROM auth_tokens WHERE expires_at < now() RETURNING 1
        )
        SELECT COUNT(*) AS removed FROM gone
        """
    )
    return int(row["removed"]) if row else 0
