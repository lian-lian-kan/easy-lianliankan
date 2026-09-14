"""Server-side score gates.

The client ships as reversible JS, so nothing client-side can be a defense.
These gates are the only thing between an automated submitter and the
leaderboards: a physical ceiling per score and a pace floor between two
gated scores. Rejected scores never reach a board, but the player's own
save stays untouched — silent isolation instead of confrontation.
"""
import os
import logging

from ..repositories import score_repo

logger = logging.getLogger("lianliankan")

# Physically unreachable: scores in the wild peak in the low tens of
# thousands (pairs x combo), so half a million is a generous ceiling.
DEFAULT_MAX_SCORE = 500_000
# Minimum wall-clock between two gated scores of the same mode: no real
# mode finishes (let alone improves a best) faster than this.
DEFAULT_MIN_RUN_MS = 15_000
# Long-session modes get a stricter floor.
MIN_RUN_OVERRIDES_MS = {"endless": 60_000, "daily": 60_000, "hell": 60_000}


def enabled() -> bool:
    """Kill switch for firefights: ANTICHEAT_OFF=1 bypasses every gate."""
    return os.environ.get("ANTICHEAT_OFF") != "1"


def max_score() -> int:
    return DEFAULT_MAX_SCORE


def min_run_ms(mode_id: str) -> int:
    return MIN_RUN_OVERRIDES_MS.get(mode_id, DEFAULT_MIN_RUN_MS)


def check_score(score: int) -> bool:
    """Ceiling gate."""
    return 0 <= int(score) <= max_score()


def check_pace(user_id: str, mode_id: str, now_ms=None) -> bool:
    """Pace gate: a fresh gated score must be at least one run apart."""
    if now_ms is None:
        now_ms = score_repo.now_ms()
    last = score_repo.last_event_ms(user_id, mode_id)
    if last is None:
        return True
    return (int(now_ms) - int(last)) >= min_run_ms(mode_id)


def audit(user_id: str, mode_id: str, score: int, verdict: str) -> None:
    """Structured rejection line — grep-able evidence, invisible to clients."""
    logger.info('{"event":"anticheat","user":"%s","mode":"%s","score":%d,"verdict":"%s"}',
                user_id, mode_id, int(score), verdict)
