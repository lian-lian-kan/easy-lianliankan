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
		"tray": "叠叠消",
	}
	var all_ok = true
	for mode in labels:
		if SM.mode_label(mode) != labels[mode]:
			all_ok = false
			push_error("label mismatch: %s -> %s (want %s)" % [mode, SM.mode_label(mode), labels[mode]])
	check(all_ok, "mode_label covers all 17 modes")
	check(SM.mode_label("nope") == "未知", "unknown mode falls back to 未知")
	check(SM.mode_label("tray") == "叠叠消", "tray label registered")

	var intros = ["daily", "time_attack", "endless", "frost", "zen", "hell", "moves", "race", "tray"]
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
	check(SM.RECORD_MODES.size() == 11, "record table covers 11 modes")
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

	# --- modes_panel_rows: 13 ordered rows, best-score formatting, daily done branch.
	var want_ids = ["daily", "time_attack", "memory", "frost", "zen", "hell", "moves", "race", "stack", "gravity", "fog", "chain", "tray", "endless"]
	var state := {
		"daily_challenge": {"streak": 2, "best_score": 88},
		"time_attack_best_score": 120, "memory_best_score": 34, "frost_best_score": 56,
		"zen_best_score": 7, "hell_best_score": 90, "moves_best_score": 11, "race_best_score": 22,
		"stack_best_score": 33, "gravity_best_score": 44, "fog_best_score": 55, "chain_best_score": 66,
		"tray_best_score": 77,
		"endless_best": {"round": 3, "score": 456},
	}
	var rows = SM.modes_panel_rows(state)
	var got_ids := []
	for r in rows:
		got_ids.append(r["id"])
	check(got_ids == want_ids, "modes_panel_rows returns 14 rows in panel order")
	var titles_ok := true
	for r in rows:
		if r["title"] == "" or r["detail"] == "":
			titles_ok = false
	check(titles_ok, "every row has title and detail")
	var details_ok := true
	for r in rows:
		if r["id"] == "daily" or r["id"] == "endless":
			continue
		var want := "最佳%d分" % int(state[r["id"] + "_best_score"])
		if not r["detail"].ends_with(want):
			details_ok = false
			push_error("detail mismatch for %s: %s" % [r["id"], r["detail"]])
	check(details_ok, "special-mode details end with their best score")
	var endless_row = rows[13]
	check(endless_row["detail"].find("最佳第3轮") != -1 and endless_row["detail"].find("最高456分") != -1, "endless detail shows round and score")
	var daily_row = rows[0]
	check(daily_row["detail"].find("今日已完成") == -1, "daily shows not-done without today's date")
	var done_state = {"daily_challenge": {"last_date": SM.date_string(OS.get_date())}}
	check(SM.modes_panel_rows(done_state)[0]["detail"].find("今日已完成") != -1, "daily shows done when last_date is today")

	# --- stage_callout: banner title/color per mode, campaign fallback format
	var campaign_level = {"id": 3, "name": "连击"}
	var campaign_callout = SM.stage_callout("", campaign_level, 2, 1)
	check(campaign_callout[0] == "第3关 · 连击" && campaign_callout[1] == Color("e64980"), "campaign callout uses 第N关 · name with rose color")
	var fallback_level = {"name": "无名"}
	check(SM.stage_callout("", fallback_level, 4, 1)[0] == "第5关 · 无名", "campaign callout falls back to level_index+1 for the id")
	var daily_callout = SM.stage_callout("daily", campaign_level, 2, 1)
	var today = OS.get_date()
	check(daily_callout[0] == "每日挑战 · %d月%d日" % [int(today.month), int(today.day)], "daily callout embeds today's date")
	check(SM.stage_callout("endless", campaign_level, 2, 7)[0] == "无尽模式 · 第7轮", "endless callout embeds the round")
	check(SM.stage_callout("time_attack", campaign_level, 2, 1)[0] == "限时挑战", "time_attack callout is static text")
	check(SM.stage_callout("memory", campaign_level, 2, 1)[1] == Color("3bc9db"), "memory callout carries its color")
	var frost_callout = SM.stage_callout("frost", {"frost_ratio": 0.38}, 2, 1)
	check(frost_callout[0].find("38%") != -1, "frost callout embeds the frozen percentage")

	if failures == 0:
		print("mode_meta_test: ALL PASSED")
		quit(0)
	else:
		print("mode_meta_test: %d FAILURES" % failures)
		quit(1)
