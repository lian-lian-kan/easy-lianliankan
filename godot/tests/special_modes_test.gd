extends SceneTree

const SPECIAL_MODES = preload("res://scripts/special_modes.gd")
const PROGRESSION = preload("res://scripts/progression.gd")

var checks = 0

func _check(condition, message: String) -> bool:
	checks += 1
	if condition:
		return true
	push_error("CHECK FAILED: " + message)
	quit(1)
	return false

func _assert_equal(actual, expected, message: String) -> bool:
	return _check(actual == expected, message + " | actual=" + str(actual) + " expected=" + str(expected))

func _init() -> void:
	# --- config normalization ---
	var configs = SPECIAL_MODES.normalize_configs(null)
	_assert_equal(int(configs["time_attack"]["initial_time"]), 60, "default time attack initial time")
	_assert_equal(int(configs["endless"]["unlock_level"]), 8, "default endless unlock level")
	var merged = SPECIAL_MODES.normalize_configs({"game_modes": {"time_attack": {"initial_time": 45}}})
	_assert_equal(int(merged["time_attack"]["initial_time"]), 45, "json override applied")
	_assert_equal(int(merged["time_attack"]["unlock_level"]), 5, "non-overridden field kept")

	# --- date helpers ---
	_assert_equal(SPECIAL_MODES.date_string({"year": 2026, "month": 9, "day": 6}), "2026-09-06", "date_string format")
	_assert_equal(SPECIAL_MODES.yesterday_string({"year": 2026, "month": 10, "day": 1}), "2026-09-30", "yesterday across month")
	_assert_equal(SPECIAL_MODES.yesterday_string({"year": 2027, "month": 1, "day": 1}), "2026-12-31", "yesterday across year")

	# --- daily streak ---
	_assert_equal(int(SPECIAL_MODES.next_daily_streak("", "2026-09-06", "2026-09-05", 0)), 1, "first ever daily -> streak 1")
	_assert_equal(int(SPECIAL_MODES.next_daily_streak("2026-09-05", "2026-09-06", "2026-09-05", 3)), 4, "consecutive day extends streak")
	_assert_equal(int(SPECIAL_MODES.next_daily_streak("2026-09-01", "2026-09-06", "2026-09-05", 7)), 1, "gap resets streak")
	_assert_equal(int(SPECIAL_MODES.next_daily_streak("2026-09-06", "2026-09-06", "2026-09-05", 5)), 5, "same-day re-record keeps streak")

	# --- daily board determinism ---
	_assert_equal(int(SPECIAL_MODES.seed_for_day("2026-09-06")), int(SPECIAL_MODES.seed_for_day("2026-09-06")), "daily seed stable per day")
	if not _check(int(SPECIAL_MODES.seed_for_day("2026-09-06")) != int(SPECIAL_MODES.seed_for_day("2026-09-07")), "daily seed differs across days"):
		return
	var level_a = SPECIAL_MODES.build_daily_level("2026-09-06")
	var level_b = SPECIAL_MODES.build_daily_level("2026-09-06")
	for field in ["rows", "cols", "kinds", "time_limit", "mode", "name"]:
		if not _assert_equal(level_a[field], level_b[field], "daily level deterministic per day (" + field + ")"):
			return
	_check(int(level_a["rows"]) % 2 == 0, "daily rows even")
	_check(int(level_a["rows"]) * int(level_a["cols"]) % 2 == 0, "daily board tile count even")
	_check(int(level_a["kinds"]) >= 8 and int(level_a["kinds"]) <= 12, "daily kinds in range")
	_check(int(level_a["time_limit"]) >= 150 and int(level_a["time_limit"]) <= 180, "daily time limit in range")
	var specs = {}
	for day_offset in range(30):
		var day = "%04d-%02d-%02d" % [2026, 9, 1 + day_offset]
		var lvl = SPECIAL_MODES.build_daily_level(day)
		specs[str(lvl["rows"]) + "x" + str(lvl["cols"]) + "x" + str(lvl["kinds"])] = true
	_check(specs.size() >= 3, "daily specs vary across a month: " + str(specs.size()))

	# --- time attack / endless level builders ---
	var ta = SPECIAL_MODES.build_time_attack_level(configs["time_attack"])
	_assert_equal(int(ta["time_limit"]), 60, "time attack starts at initial_time")
	_assert_equal(str(ta["mode"]), "time_attack", "time attack mode id")
	var e1 = SPECIAL_MODES.build_endless_level(configs["endless"], 1)
	_assert_equal(int(e1["rows"]), 10, "endless round 1 rows")
	_assert_equal(int(e1["kinds"]), 6, "endless round 1 kinds")
	var e3 = SPECIAL_MODES.build_endless_level(configs["endless"], 3)
	_assert_equal(int(e3["rows"]), 10, "endless round 3 rows not yet expanded")
	_assert_equal(int(e3["kinds"]), 8, "endless round 3 kinds grew")
	var e4 = SPECIAL_MODES.build_endless_level(configs["endless"], 4)
	_assert_equal(int(e4["rows"]), 12, "endless round 4 board expanded")
	_assert_equal(int(e4["cols"]), 10, "endless round 4 cols expanded")
	var e30 = SPECIAL_MODES.build_endless_level(configs["endless"], 30)
	_assert_equal(int(e30["kinds"]), 20, "endless kinds capped")
	_assert_equal(int(e30["rows"]), 16, "endless rows capped")
	_assert_equal(int(e30["cols"]), 14, "endless cols capped")

	# --- unlocks ---
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("daily", configs["daily"], 0), true, "daily always unlocked")
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("time_attack", configs["time_attack"], 3), false, "time attack locked below level 5")
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("time_attack", configs["time_attack"], 4), true, "time attack unlocked at level 5")
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("endless", configs["endless"], 6), false, "endless locked below level 8")
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("endless", configs["endless"], 7), true, "endless unlocked at level 8")
	_check(SPECIAL_MODES.unlock_requirement_text("time_attack", configs["time_attack"]).find("5") >= 0, "unlock text mentions level")

	# --- progression records ---
	var state = PROGRESSION.normalize_progress({}, 15)
	_assert_equal(int(state["daily_challenge"]["streak"]), 0, "default daily streak")
	_assert_equal(int(state["endless_best"]["round"]), 0, "default endless round")
	_assert_equal(int(state["time_attack_best_score"]), 0, "default time attack score")

	var day1 = PROGRESSION.apply_update(state, 15, {
		"daily_result": {"date": "2026-09-06", "yesterday": "2026-09-05", "score": 800}
	})
	_assert_equal(int(day1["daily_challenge"]["streak"]), 1, "daily result sets streak 1")
	_assert_equal(str(day1["daily_challenge"]["last_date"]), "2026-09-06", "daily result sets last date")
	_assert_equal(int(day1["daily_challenge"]["best_score"]), 800, "daily result sets best score")

	var day2 = PROGRESSION.apply_update(day1, 15, {
		"daily_result": {"date": "2026-09-07", "yesterday": "2026-09-06", "score": 500}
	})
	_assert_equal(int(day2["daily_challenge"]["streak"]), 2, "consecutive daily extends streak")
	_assert_equal(int(day2["daily_challenge"]["best_score"]), 800, "lower daily score keeps best")

	var day_gap = PROGRESSION.apply_update(day2, 15, {
		"daily_result": {"date": "2026-09-20", "yesterday": "2026-09-19", "score": 900}
	})
	_assert_equal(int(day_gap["daily_challenge"]["streak"]), 1, "daily gap resets streak")
	_assert_equal(int(day_gap["daily_challenge"]["best_score"]), 900, "higher daily score updates best")
	_assert_equal(int(day_gap["daily_challenge"]["best_streak"]), 2, "best streak remembered")

	var endless_state = PROGRESSION.apply_update(state, 15, {"endless_result": {"round": 4, "score": 1200}})
	endless_state = PROGRESSION.apply_update(endless_state, 15, {"endless_result": {"round": 2, "score": 900}})
	_assert_equal(int(endless_state["endless_best"]["round"]), 4, "endless best round keeps max")
	_assert_equal(int(endless_state["endless_best"]["score"]), 1200, "endless best score keeps max")

	var ta_state = PROGRESSION.apply_update(state, 15, {"time_attack_result": 700})
	ta_state = PROGRESSION.apply_update(ta_state, 15, {"time_attack_result": 1100})
	_assert_equal(int(ta_state["time_attack_best_score"]), 1100, "time attack best score keeps max")

	# Records survive a normalize round-trip (save/load).
	var reloaded = PROGRESSION.normalize_progress(day_gap, 15)
	_assert_equal(int(reloaded["daily_challenge"]["best_streak"]), 2, "daily record survives normalize")
	_assert_equal(PROGRESSION.same_progress(day_gap, reloaded, 15), true, "same_progress true for equal states")
	var different = PROGRESSION.apply_update(reloaded, 15, {"endless_result": {"round": 9, "score": 5}})
	_assert_equal(PROGRESSION.same_progress(different, reloaded, 15), false, "same_progress false when records differ")

	# --- memory mode ---
	var mem_configs = SPECIAL_MODES.normalize_configs({"game_modes": {"memory": {
		"difficulty_tiers": [
			{"level_range": [1, 3], "preview": 5.0, "face_up": 1.0},
			{"level_range": [4, 6], "preview": 4.0, "face_up": 0.8},
			{"level_range": [7, 999], "preview": 3.0, "face_up": 0.5}
		]
	}}})
	var mem_cfg = mem_configs["memory"]
	_assert_equal(float(SPECIAL_MODES.memory_tier(mem_cfg, 2)["preview"]), 5.0, "memory tier 1 preview")
	_assert_equal(float(SPECIAL_MODES.memory_tier(mem_cfg, 5)["face_up"]), 0.8, "memory tier 2 face up")
	_assert_equal(float(SPECIAL_MODES.memory_tier(mem_cfg, 50)["preview"]), 3.0, "memory tier 3 preview")
	_assert_equal(float(SPECIAL_MODES.memory_tier(mem_cfg, 1)["preview"]), 5.0, "memory tier falls back inside range")
	# A config without tiers falls back to the flat defaults.
	_assert_equal(float(SPECIAL_MODES.memory_tier(configs["memory"], 99)["preview"]), 5.0, "memory tier default fallback")
	var mem = SPECIAL_MODES.build_memory_level(mem_cfg, SPECIAL_MODES.memory_tier(mem_cfg, 2))
	_assert_equal(str(mem["mode"]), "memory", "memory level mode id")
	_assert_equal(int(mem["rows"]), 8, "memory rows")
	_assert_equal(int(mem["time_limit"]), 60 + int(8 * 8 * 1.5), "memory time scales with tiles")
	_assert_equal(float(mem["memory_preview"]), 5.0, "memory preview carried into level")
	_assert_equal(float(mem["memory_face_up"]), 1.0, "memory face_up carried into level")
	# Unlock gate uses the standard rule (level 10).
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("memory", mem_cfg, 8), false, "memory locked below level 10")
	_assert_equal(SPECIAL_MODES.is_mode_unlocked("memory", mem_cfg, 9), true, "memory unlocked at level 10")

	var mem_state = PROGRESSION.apply_update(state, 15, {"memory_result": 650})
	mem_state = PROGRESSION.apply_update(mem_state, 15, {"memory_result": 420})
	_assert_equal(int(mem_state["memory_best_score"]), 650, "memory best score keeps max")
	var ach_state = PROGRESSION.unlock_achievement(mem_state, "memory_first")
	_assert_equal(PROGRESSION.has_achievement(ach_state, "memory_first"), true, "memory achievement unlocks")
	_assert_equal(PROGRESSION.get_achievement_info("memory_first")["name"], "盲盒初体验", "memory achievement info resolvable")

	print("special_modes_test: ALL PASSED (", checks, " checks)")
	quit(0)
