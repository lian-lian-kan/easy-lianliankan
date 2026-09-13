-- Full progression_state blob per user (the coarse cloud save).
CREATE TABLE IF NOT EXISTS progress_snapshots (
    user_id    UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    state      JSONB NOT NULL,
    updated_at BIGINT NOT NULL
);
