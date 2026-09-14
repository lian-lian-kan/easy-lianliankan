"""SQL for leaderboards over mode_records (all-time board)."""
from ..core import db


def top_scores(mode_id: str, limit: int) -> list:
    """Unified board row: user_id, nickname, score, achieved_ms."""
    return db.query_all(
        """
        SELECT r.user_id::text AS user_id, u.nickname,
               r.best_score AS score, r.updated_at AS achieved_ms
        FROM mode_records r JOIN users u ON u.user_id = r.user_id
        WHERE r.mode_id = %s AND r.best_score > 0
        ORDER BY r.best_score DESC, r.updated_at ASC
        LIMIT %s
        """,
        (mode_id, limit),
    )


def player_count(mode_id: str) -> int:
    """Distinct players with any record row on the mode."""
    row = db.query_one(
        "SELECT COUNT(DISTINCT user_id) AS players FROM mode_records WHERE mode_id = %s",
        (mode_id,),
    )
    return int(row["players"]) if row else 0


def user_rank(user_id: str, mode_id: str):
    row = db.query_one(
        """
        SELECT rank FROM (
            SELECT user_id, RANK() OVER (ORDER BY best_score DESC) AS rank
            FROM mode_records WHERE mode_id = %s AND best_score > 0
        ) ranked WHERE user_id = %s
        """,
        (mode_id, user_id),
    )
    return int(row["rank"]) if row else None
