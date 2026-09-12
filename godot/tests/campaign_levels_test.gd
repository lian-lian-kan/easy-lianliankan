extends SceneTree

# Campaign level data invariants: ids, board dims, texture kinds, modes, curves.

const CL = preload("res://scripts/modes/campaign_levels.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== campaign_levels_test")
	var levels = CL.default_campaign_levels()
	check(levels.size() == 10, "campaign has 10 levels")

	var ids_ok := true
	var dims_ok := true
	var kinds_ok := true
	var time_ok := true
	var mode_ok := true
	var text_ok := true
	var mult_ok := true
	var prev_score_mult := 0.0
	var prev_effect := 0.0
	var valid_modes := {"classic": true, "rush": true, "combo": true, "endurance": true}
	for i in range(levels.size()):
		var lv = levels[i]
		if int(lv.get("id", -1)) != i + 1:
			ids_ok = false
		var rows := int(lv.get("rows", 0))
		var cols := int(lv.get("cols", 0))
		if rows < 4 or cols < 4 or (rows * cols) % 2 != 0:
			dims_ok = false
		var kinds := int(lv.get("kinds", 0))
		if kinds < 4 or kinds > 12 or kinds * 2 > rows * cols:
			kinds_ok = false
		if float(lv.get("time_limit", 0)) <= 0.0:
			time_ok = false
		if not valid_modes.has(str(lv.get("mode", ""))):
			mode_ok = false
		if str(lv.get("name", "")) == "" or str(lv.get("description", "")) == "":
			text_ok = false
		if float(lv.get("score_multiplier", 0)) < prev_score_mult or float(lv.get("effect_intensity", 0)) < prev_effect:
			mult_ok = false
		prev_score_mult = float(lv.get("score_multiplier", 0))
		prev_effect = float(lv.get("effect_intensity", 0))
	check(ids_ok, "level ids are 1..10 in order")
	check(dims_ok, "every board has sane dimensions and an even tile count")
	check(kinds_ok, "kinds stay within the 12-texture range with enough tiles")
	check(time_ok, "every level has a positive time limit")
	check(mode_ok, "every level uses a known mode")
	check(text_ok, "every level has a name and description")
	check(mult_ok, "score/effect multipliers are non-decreasing")

	var again = CL.default_campaign_levels()
	again[0]["rows"] = 99
	check(levels[0]["rows"] == 8, "each call returns a fresh deep copy (no shared-state mutation)")

	if failures == 0:
		print("campaign_levels_test: ALL PASSED")
		quit(0)
	else:
		print("campaign_levels_test: %d FAILURES" % failures)
		quit(1)
