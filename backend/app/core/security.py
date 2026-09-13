"""Token primitives: minting and hashing only.

No DB here — token SQL lives in repositories/users_repo (single home for
SQL); HTTP concerns (header parsing, 401s) live in app/dependencies.
"""
import hashlib
import secrets


def mint_token() -> str:
    return secrets.token_hex(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
