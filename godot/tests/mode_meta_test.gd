extends SceneTree

# Mode display metadata tests: labels, intro texts, and the record table.

const SM = preload("res://scripts/special_modes.gd")
const PROGRESSION = preload("res://scripts/progression.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== mode_meta_test")

	var labels = {
		"classic": "经典", "rush": "冲刺", "combo": "连击", "endurance": "耐力",
		"daily": "每日挑战", "time_attack": "限时挑战", "endless": "无尽模式",
		"memory": "盲盒模式", "frost": "冰雪挑战", "zen": "休闲模式",
		"hell": "地狱模式", "moves": "步数挑战", "race": "竞速对战",
		"stack": "叠层模式", "gravity": "重力模式", "fog": "迷雾模式", "chain": "锁链模式",
	}
	var all_ok = true
	for mode in labels:
		if SM.mode_label(mode) != labels[mode]:
			all_ok = false
			push_error("label mismatch: %s -> %s (want %s)" % [mode, SM.mode_label(mode), labels[mode]])
	check(all_ok, "mode_label covers all 17 modes")
	check(SM.mode_label("nope") == "未知", "unknown mode falls back to 未知")

	var intros = ["daily", "time_attack", "endless", "frost", "zen", "hell", "moves", "race"]
	var intros_ok = true
	for mode in intros:
		var txt = SM.intro_text(mode)
		if txt == "" or txt == "特殊模式开始":
			intros_ok = false
			push_error("intro missing for " + mode)
	check(intros_ok, "intro_text covers all 8 special modes")
	check(SM.intro_text("nope") == "特殊模式开始", "unknown mode falls back to the default intro")

	# --- RECORD_MODES: keys consistent with progression, achievements defined.
	var defined_ids = {}
	for a in PROGRESSION.ACHIEVEMENTS:
		defined_ids[a["id"]] = true
	check(SM.RECORD_MODES.size() == 10, "record table covers 10 modes")
	var table_ok = true
	var ach_ok = true
	for mode in SM.RECORD_MODES:
		var rec = SM.RECORD_MODES[mode]
		if rec["patch_key"] != mode + "_result" or rec["best_key"] != mode + "_best_score":
			table_ok = false
		for a in rec["achievements"]:
			if not defined_ids.has(a):
				ach_ok = false
	check(table_ok, "record table patch/best keys follow <mode>_result/<mode>_best_score")
	check(ach_ok, "all table achievements are defined in progression")

	# --- bonus_achievements
	check(SM.bonus_achievements("frost", {"frost_uses": 0}) == ["frost_no_power"], "frost with no warm patches earns the bonus achievement")
	check(SM.bonus_achievements("frost", {"frost_uses": 2}) == [], "frost with warm patches earns none")
	check(SM.bonus_achievements("moves", {"moves_left": 20, "move_budget": 56}) == ["moves_saver"], "moves with 20+ left earns moves_saver")
	check(SM.bonus_achievements("moves", {"moves_left": 5, "move_budget": 56}) == [], "moves below threshold earns none")
	check(SM.bonus_achievements("race", {}) == [], "race has no conditional bonus")

	if failures == 0:
		print("mode_meta_test: ALL PASSED")
		quit(0)
	else:
		print("mode_meta_test: %d FAILURES" % failures)
		quit(1)
