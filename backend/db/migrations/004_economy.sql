-- Append-only blossom ledger; balance = SUM(delta).
CREATE TABLE IF NOT EXISTS economy_ledger (
    entry_id   BIGSERIAL PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    delta      INT  NOT NULL,
    reason     TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ledger_user ON economy_ledger(user_id, entry_id DESC);

-- Daily sign-in log (one row per user per calendar day).
CREATE TABLE IF NOT EXISTS signin_log (
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    signin_date DATE NOT NULL,
    streak      INT  NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, signin_date)
);
