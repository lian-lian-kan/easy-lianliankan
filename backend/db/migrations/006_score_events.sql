-- Append-only score stream: feeds periodic leaderboards and the anticheat
-- pace gate. Rows only arrive through the server-side intake gate.
CREATE TABLE IF NOT EXISTS mode_score_events (
    id         BIGSERIAL PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    mode_id    TEXT NOT NULL REFERENCES modes(mode_id),
    score      INT  NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_score_events_board
    ON mode_score_events(mode_id, created_at, score DESC);
CREATE INDEX IF NOT EXISTS idx_score_events_user
    ON mode_score_events(user_id, mode_id, created_at DESC);
