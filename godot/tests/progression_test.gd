extends SceneTree

func _assert_equal(actual: Variant, expected: Variant, message: String) -> bool:
	if actual == expected:
		return true
	push_error(message + " | actual=" + str(actual) + " expected=" + str(expected))
	quit(1)
	return false

func _init() -> void:
	var progression = load("res://scripts/progression.gd")
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

	quit(0)
