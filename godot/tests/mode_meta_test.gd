extends SceneTree

# Mode display metadata tests: labels and intro texts for every mode.

const SM = preload("res://scripts/special_modes.gd")

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

	if failures == 0:
		print("mode_meta_test: ALL PASSED")
		quit(0)
	else:
		print("mode_meta_test: %d FAILURES" % failures)
		quit(1)
