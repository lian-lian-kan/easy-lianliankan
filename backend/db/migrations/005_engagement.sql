-- Achievements and weekly missions per user.
CREATE TABLE IF NOT EXISTS achievements (
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    achievement_id  TEXT NOT NULL,
    unlocked_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS missions_progress (
    user_id    UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    week_key   BIGINT NOT NULL,
    mission_id TEXT NOT NULL,
    progress   INT NOT NULL DEFAULT 0,
    claimed    BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, week_key, mission_id)
);
