"""Extract per-mode best scores from progress blobs and gate them onto boards.

The game never calls a score API — best scores live inside the cloud-save
blob. Intake diffs the previous snapshot against each save, so existing
clients start producing leaderboard data with zero client changes. Scores
that pass the gates land in mode_score_events (periodic boards, audit
stream) and mode_records (all-time board).
"""
import logging

from . import anticheat
from ..repositories import records_repo, score_repo

logger = logging.getLogger("lianliankan")

# mode_id -> path of the best-score field in the progression blob
# (dot = nested). Mirror of the game's progression.gd; keep in sync.
SCORE_KEYS = {
    "daily": "daily_challenge.best_score",
    "endless": "endless_best.score",
    "time_attack": "time_attack_best_score",
    "memory": "memory_best_score",
    "frost": "frost_best_score",
    "zen": "zen_best_score",
    "hell": "hell_best_score",
    "moves": "moves_best_score",
    "race": "race_best_score",
    "stack": "stack_best_score",
    "gravity": "gravity_best_score",
    "fog": "fog_best_score",
    "chain": "chain_best_score",
    "tray": "tray_best_score",
    "collect": "collect_best_score",
    "flip": "flip_best_score",
    "fever": "fever_best_score",
    "perfect": "perfect_best_score",
    "rock": "rock_best_score",
    "defuse": "defuse_best_score",
    "target": "target_best_score",
    "shift": "shift_best_score",
    "slide": "slide_best_score",
    "defense": "defense_best_score",
    "sum10": "sum10_best_score",
    "duel": "duel_best_score",
}


def extract(state) -> dict:
    """mode_id -> non-negative int best score for every known key present."""
    scores = {}
    for mode_id, path in SCORE_KEYS.items():
        value = _dig(state, path)
        if value is not None:
            scores[mode_id] = max(0, int(value))
    return scores


def _dig(state, path):
    value = state
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value


def process(user_id: str, prev_state, new_state, now_ms=None) -> list:
    """Gate every score increase between the two blobs. Returns the accepted
    entries; rejected ones are only visible in the anticheat audit log."""
    prev_scores = extract(prev_state) if prev_state else {}
    accepted = []
    for mode_id, score in sorted(extract(new_state).items()):
        if score <= prev_scores.get(mode_id, 0):
            continue
        if not _gate(user_id, mode_id, score, now_ms):
            continue
        score_repo.insert_event(user_id, mode_id, score)
        # plays/wins counters belong to explicit result reports, not intake.
        records_repo.upsert_record(user_id, mode_id, score, 0, 0, score_repo.now_ms())
        accepted.append({"mode_id": mode_id, "score": score})
    return accepted


def _gate(user_id: str, mode_id: str, score: int, now_ms) -> bool:
    if not anticheat.enabled():
        return True
    if not anticheat.check_score(score):
        anticheat.audit(user_id, mode_id, score, "ceiling")
        return False
    if not anticheat.check_pace(user_id, mode_id, now_ms):
        anticheat.audit(user_id, mode_id, score, "pace")
        return False
    return True
