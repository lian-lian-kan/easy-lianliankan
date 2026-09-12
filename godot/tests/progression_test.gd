extends SceneTree

func _assert_equal(actual, expected, message: String) -> bool:
	if actual == expected:
		return true
	push_error(message + " | actual=" + str(actual) + " expected=" + str(expected))
	quit(1)
	return false

func _init() -> void:
	var progression = load("res://scripts/session/progression.gd")
	if progression == null:
		push_error("missing progression.gd")
		quit(1)
		return

	var normalized = progression.normalize_progress({}, 10)
	if not _assert_equal(int(normalized.get("current_level_index", -1)), 0, "default current_level_index"):
		return
	if not _assert_equal(int(normalized.get("highest_unlocked_level_index", -1)), 0, "default highest_unlocked_level_index"):
		return
	if not _assert_equal(int(normalized.get("best_total_score", -1)), 0, "default best_total_score"):
		return
	if not _assert_equal(int(normalized.get("best_combo", -1)), 0, "default best_combo"):
		return

	var clamped = progression.normalize_progress({
		"current_level_index": 99,
		"highest_unlocked_level_index": -8,
		"best_total_score": -11,
		"best_combo": -2
	}, 5)
	if not _assert_equal(int(clamped.get("current_level_index", -1)), 4, "current level should clamp to last level"):
		return
	if not _assert_equal(int(clamped.get("highest_unlocked_level_index", -1)), 4, "unlocked level should not be below current level"):
		return
	if not _assert_equal(int(clamped.get("best_total_score", -1)), 0, "best score should clamp to non-negative"):
		return
	if not _assert_equal(int(clamped.get("best_combo", -1)), 0, "best combo should clamp to non-negative"):
		return

	var updated = progression.apply_update(normalized, 10, {
		"current_level_index": 3,
		"highest_unlocked_level_index": 3,
		"score_candidate": 420,
		"combo_candidate": 7
	})
	if not _assert_equal(int(updated.get("current_level_index", -1)), 3, "updated current level"):
		return
	if not _assert_equal(int(updated.get("highest_unlocked_level_index", -1)), 3, "updated unlocked level"):
		return
	if not _assert_equal(int(updated.get("best_total_score", -1)), 420, "updated best score"):
		return
	if not _assert_equal(int(updated.get("best_combo", -1)), 7, "updated best combo"):
		return

	var no_regress = progression.apply_update(updated, 10, {
		"score_candidate": 120,
		"combo_candidate": 3
	})
	if not _assert_equal(int(no_regress.get("best_total_score", -1)), 420, "best score should not regress"):
		return
	if not _assert_equal(int(no_regress.get("best_combo", -1)), 7, "best combo should not regress"):
		return
	if not _assert_equal(progression.is_level_unlocked(no_regress, 3, 10), true, "level 4 should be unlocked"):
		return
	if not _assert_equal(progression.is_level_unlocked(no_regress, 7, 10), false, "level 8 should still be locked"):
		return
	if not _assert_equal(progression.find_next_unlocked(no_regress, 1, 1, 10), 2, "next unlocked +1"):
		return
	if not _assert_equal(progression.find_next_unlocked(no_regress, 3, 1, 10), 0, "next unlocked wraps forward"):
		return
	if not _assert_equal(progression.find_next_unlocked(no_regress, 0, -1, 10), 3, "next unlocked wraps backward"):
		return

	# --- clear_unlocked_ids: campaign-clear achievement rules (pure)
	var fresh = progression.normalize_progress({}, 10)
	if not _assert_equal(progression.clear_unlocked_ids(fresh, {"level_index": 0, "combo": 0, "clear_time": 999.0, "hints_used": 3, "auto_used": 2, "level_count": 10}), ["first_clear"], "level 1 clear unlocks first_clear"):
		return
	if not _assert_equal(progression.clear_unlocked_ids(fresh, {"level_index": 1, "combo": 3, "clear_time": 60.0, "hints_used": 1, "auto_used": 1, "level_count": 10}), ["combo_novice"], "combo 3 unlocks novice only"):
		return
	if not _assert_equal(progression.clear_unlocked_ids(fresh, {"level_index": 2, "combo": 10, "clear_time": 12.0, "hints_used": 0, "auto_used": 0, "level_count": 10}), ["combo_novice", "combo_master", "speed_star", "perfect_clear"], "strong clear unlocks combo/speed/perfect"):
		return
	if not _assert_equal(progression.clear_unlocked_ids(fresh, {"level_index": 9, "combo": 0, "clear_time": 999.0, "hints_used": 1, "auto_used": 1, "level_count": 10}), ["completionist"], "last level clear unlocks completionist"):
		return
	if not _assert_equal(progression.clear_unlocked_ids(fresh, {"level_index": 5, "combo": 2, "clear_time": 30.0, "hints_used": 1, "auto_used": 1, "level_count": 10}), ["speed_star"], "exactly 30s counts as speed_star"):
		return
	var with_all = progression.unlock_achievement(progression.unlock_achievement(fresh, "first_clear"), "combo_novice")
	if not _assert_equal(progression.clear_unlocked_ids(with_all, {"level_index": 0, "combo": 4, "clear_time": 999.0, "hints_used": 1, "auto_used": 1, "level_count": 10}), [], "already unlocked ids are not returned twice"):
		return

	# --- onboarding_seen: patch is applied and detected as a change
	if not _assert_equal(bool(normalized.get("onboarding_seen", true)), false, "fresh state has onboarding_seen=false"):
		return
	var seen = progression.apply_update(normalized, 10, {"onboarding_seen": true})
	if not _assert_equal(bool(seen.get("onboarding_seen", false)), true, "onboarding_seen patch is applied"):
		return
	if not _assert_equal(int(seen.get("current_level_index", -1)), 0, "onboarding_seen patch leaves other fields alone"):
		return
	if not _assert_equal(progression.same_progress(seen, normalized, 10), false, "onboarding_seen flip counts as a change (must persist)"):
		return
	if not _assert_equal(progression.same_progress(seen, seen, 10), true, "same onboarding_seen states compare equal"):
		return
	var unseen_again = progression.apply_update(seen, 10, {"onboarding_seen": false})
	if not _assert_equal(bool(unseen_again.get("onboarding_seen", true)), false, "onboarding_seen can be cleared"):
		return

	quit(0)
