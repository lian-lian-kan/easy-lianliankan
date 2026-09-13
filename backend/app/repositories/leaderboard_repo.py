"""SQL for leaderboards over mode_records."""
from ..core import db


def top_scores(mode_id: str, limit: int) -> list:
    return db.query_all(
        """
        SELECT u.nickname, r.best_score, r.updated_at
        FROM mode_records r JOIN users u ON u.user_id = r.user_id
        WHERE r.mode_id = %s
        ORDER BY r.best_score DESC, r.updated_at ASC
        LIMIT %s
        """,
        (mode_id, limit),
    )


def user_rank(user_id: str, mode_id: str):
    row = db.query_one(
        """
        SELECT rank FROM (
            SELECT user_id, RANK() OVER (ORDER BY best_score DESC) AS rank
            FROM mode_records WHERE mode_id = %s
        ) ranked WHERE user_id = %s
        """,
        (mode_id, user_id),
    )
    return int(row["rank"]) if row else None
