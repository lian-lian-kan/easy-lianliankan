-- Device-to-device migration pairing codes (server-minted, single-use).
-- One active code per account: generating a new code deletes the previous
-- rows for that user (see migration_repo.replace_user_code).
CREATE TABLE IF NOT EXISTS migration_codes (
    code_hash   TEXT PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_migration_codes_user ON migration_codes(user_id);
