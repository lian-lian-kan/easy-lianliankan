"""Leaderboards: all-time and periodic, cached as one JSON blob per board.

The cache holds the shared part (top-100 + player count); per-viewer data
(my_rank) is always computed live. Cache misses and Redis outages degrade
to direct SQL reads.
"""
from ..core import cache
from ..repositories import leaderboard_repo, score_repo

BOARD_LIMIT = 100
PERIODS = {"all": None, "weekly": 7 * 86_400_000, "daily": 86_400_000}
CACHE_TTL_SECONDS = {"all": 30, "weekly": 15, "daily": 15}


def board(mode_id: str, period: str, limit: int, viewer_id: str) -> dict:
    since_ms = _since(period)
    key = f"board:{mode_id}:{period}"
    payload = cache.get_json(key)
    if payload is None:
        payload = _build(mode_id, since_ms)
        cache.set_json(key, payload, CACHE_TTL_SECONDS[period])
    return {
        "mode_id": mode_id,
        "period": period,
        "total_players": payload["total_players"],
        "top": [dict(row, rank=i + 1) for i, row in enumerate(payload["top"][:limit])],
        "my_rank": _rank(viewer_id, mode_id, since_ms),
    }


def invalidate(mode_id: str) -> None:
    """Call after a gated score lands; periodic boards expire on their own."""
    cache.drop(f"board:{mode_id}:all")


def _build(mode_id: str, since_ms) -> dict:
    if since_ms is None:
        rows = leaderboard_repo.top_scores(mode_id, BOARD_LIMIT)
        total = leaderboard_repo.player_count(mode_id)
    else:
        rows = score_repo.window_top(mode_id, since_ms, BOARD_LIMIT)
        total = score_repo.window_player_count(mode_id, since_ms)
    return {"total_players": total, "top": [dict(r) for r in rows]}


def _rank(viewer_id: str, mode_id: str, since_ms):
    if since_ms is None:
        return leaderboard_repo.user_rank(viewer_id, mode_id)
    return score_repo.user_window_rank(viewer_id, mode_id, since_ms)


def _since(period: str):
    if period not in PERIODS:
        raise ValueError(f"unknown period: {period}")
    window_ms = PERIODS[period]
    return None if window_ms is None else score_repo.now_ms() - window_ms
