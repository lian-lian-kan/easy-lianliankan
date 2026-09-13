-- Player progress storage. Applied automatically at app startup
-- (store.ensure_schema); kept here for manual/ops use.
CREATE TABLE IF NOT EXISTS player_progress (
    player_id  TEXT PRIMARY KEY,
    state      JSONB NOT NULL,
    updated_at BIGINT NOT NULL
);
