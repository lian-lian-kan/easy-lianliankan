"""SQL for the append-only score stream (periodic boards + pace gate)."""
import time

from ..core import db


def insert_event(user_id: str, mode_id: str, score: int, created_ms=None) -> None:
    """Stamp events from the application clock, never DB now(): the pace gate
    compares them against time.time() — mixing clock domains (the DB host can
    drift hundreds of ms from the app host) would misjudge real players."""
    if created_ms is None:
        created_ms = now_ms()
    db.execute(
        """
        INSERT INTO mode_score_events (user_id, mode_id, score, created_at)
        VALUES (%s, %s, %s, to_timestamp(%s / 1000.0))
        """,
        (user_id, mode_id, int(score), int(created_ms)),
    )


def last_event_ms(user_id: str, mode_id: str):
    """Unix-ms timestamp of the user's last gated score for the mode."""
    row = db.query_one(
        """
        SELECT EXTRACT(EPOCH FROM MAX(created_at)) * 1000 AS last_ms
        FROM mode_score_events WHERE user_id = %s AND mode_id = %s
        """,
        (user_id, mode_id),
    )
    return int(row["last_ms"]) if row and row["last_ms"] is not None else None


def window_top(mode_id: str, since_ms: int, limit: int) -> list:
    """Best score per user inside a window, ranked; ties break by earlier."""
    return db.query_all(
        """
        SELECT r.user_id::text AS user_id, u.nickname, r.score,
               EXTRACT(EPOCH FROM r.achieved_at) * 1000 AS achieved_ms
        FROM (
            SELECT user_id, MAX(score) AS score, MIN(created_at) AS achieved_at
            FROM mode_score_events
            WHERE mode_id = %s
              AND created_at >= to_timestamp(%s / 1000.0)
            GROUP BY user_id
        ) r JOIN users u ON u.user_id = r.user_id
        ORDER BY r.score DESC, r.achieved_at ASC
        LIMIT %s
        """,
        (mode_id, since_ms, limit),
    )


def window_player_count(mode_id: str, since_ms: int) -> int:
    row = db.query_one(
        """
        SELECT COUNT(DISTINCT user_id) AS players FROM mode_score_events
        WHERE mode_id = %s AND created_at >= to_timestamp(%s / 1000.0)
        """,
        (mode_id, since_ms),
    )
    return int(row["players"]) if row else 0


def user_window_rank(user_id: str, mode_id: str, since_ms: int):
    """1-based rank of the user's window best, or None when unranked."""
    row = db.query_one(
        """
        WITH best AS (
            SELECT user_id, MAX(score) AS score FROM mode_score_events
            WHERE mode_id = %s AND created_at >= to_timestamp(%s / 1000.0)
            GROUP BY user_id
        ), ranked AS (
            SELECT user_id, RANK() OVER (ORDER BY score DESC) AS rank FROM best
        )
        SELECT rank FROM ranked WHERE user_id = %s
        """,
        (mode_id, since_ms, user_id),
    )
    return int(row["rank"]) if row else None


def prune_expired(retention_days: int) -> int:
    """Delete events past the retention window; periodic boards only ever
    look back days, so 90 days is generous. Idempotent, safe to run from
    both replicas on startup."""
    row = db.query_one(
        """
        WITH gone AS (
            DELETE FROM mode_score_events
            WHERE created_at < now() - (%s * INTERVAL '1 day')
            RETURNING 1
        )
        SELECT COUNT(*) AS removed FROM gone
        """,
        (retention_days,),
    )
    return int(row["removed"]) if row else 0


def now_ms() -> int:
    return int(time.time() * 1000)
