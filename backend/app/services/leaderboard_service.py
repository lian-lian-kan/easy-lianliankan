"""Leaderboards over mode_records (all-time best per mode)."""
from ..repositories import leaderboard_repo


def top_scores(mode_id: str, limit: int) -> list:
    return [dict(r) for r in leaderboard_repo.top_scores(mode_id, limit)]


def user_rank(user_id: str, mode_id: str):
    return leaderboard_repo.user_rank(user_id, mode_id)
