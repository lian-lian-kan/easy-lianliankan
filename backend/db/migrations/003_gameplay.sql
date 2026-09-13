-- Mode registry (seeded from the game's 27-mode table) and per-user records.
CREATE TABLE IF NOT EXISTS modes (
    mode_id      TEXT PRIMARY KEY,
    label        TEXT NOT NULL,
    unlock_level INT  NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS mode_records (
    user_id    UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    mode_id    TEXT NOT NULL REFERENCES modes(mode_id),
    best_score INT  NOT NULL DEFAULT 0,
    plays      INT  NOT NULL DEFAULT 0,
    wins       INT  NOT NULL DEFAULT 0,
    updated_at BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, mode_id)
);
CREATE INDEX IF NOT EXISTS idx_mode_records_board ON mode_records(mode_id, best_score DESC);
