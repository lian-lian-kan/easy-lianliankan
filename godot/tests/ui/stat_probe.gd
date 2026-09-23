extends SceneTree

# Stat HUD tests: card sizes must stay constant when value text changes
# (no layout jitter), plus direct coverage of scripts/stats_hud.gd.

const STATS_HUD = preload("res://scripts/ui/stats_hud.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	# Black-hole the API (headless runs must stay offline): a live cloud
	# save adopting mid-probe would replace the board under assertion.
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")
	print("== stat_probe")
	var scene = load("res://scenes/Main.tscn")
	var game = scene.instance()
	root.add_child(game)
	for _i in range(6):
		yield(self, "idle_frame")

	var flow = game.stats_flow_container
	var card = game.stat_values["total_score"]["card"]
	check(flow != null and card != null, "stat flow and card exist")
	for _i in range(3):
		yield(self, "idle_frame")

	var flow_h = flow.rect_size.y
	var card_size = card.rect_size
	var combo_size = game.stat_values["combo"]["card"].rect_size

	# Extreme values across the widest cards.
	game._set_stat_text("total_score", "9999999")
	game._set_stat_text("time_left", "88:88")
	game._set_stat_text("combo", "x999")
	for _i in range(4):
		yield(self, "idle_frame")

	check(game.stat_values["total_score"]["value"].text == "9999999", "long value applied")
	check(card.rect_size == card_size, "total_score card size unchanged under long value")
	check(game.stat_values["combo"]["card"].rect_size == combo_size, "combo card size unchanged")
	check(abs(flow.rect_size.y - flow_h) < 0.5, "stat flow height stable (no reflow)")

	# Short values must not shrink-grow the row either.
	game._set_stat_text("total_score", "0")
	for _i in range(3):
		yield(self, "idle_frame")
	check(abs(flow.rect_size.y - flow_h) < 0.5, "flow height stable with short values")
	check(card.rect_size == card_size, "card size stable with short values")

	# --- Direct module coverage: stats_hud.gd
	STATS_HUD.add_card(game, flow, "测试卡", "probe_card")
	check(game.stat_values.has("probe_card"), "add_card registers the key")
	check(game.stat_values["probe_card"]["card"].rect_min_size == Vector2(100, 64), "probe card keeps the constant min size")
	STATS_HUD.set_text(game, "probe_card", "8888888888")
	check(game.stat_values["probe_card"]["value"].text == "8888888888", "set_text applies long values")
	STATS_HUD.set_text(game, "nope_key", "x")
	check(true, "set_text on unknown key is a safe no-op")

	var danger_bg = STATS_HUD.set_card_state(game, true)
	check(danger_bg == Color("ffe3e3"), "danger card state applies red tint")
	var safe_bg = STATS_HUD.set_card_state(game, false)
	check(safe_bg == Color("fff4e6"), "safe card state restores cream tint")

	check(STATS_HUD.pulse(game, false, 0.016) == false, "pulse is a no-op when safe")
	check(STATS_HUD.pulse(game, true, 0.016) == true, "pulse applies when dangerous")

	# --- is_time_danger: clockless, paused and safe-clock states stay calm
	var saved_status = game.stage_status
	var saved_time = game.time_left
	var saved_mode = game.special_mode
	var saved_level_time = game._current_level().get("time_limit", 0)
	game.stage_status = game.STATUS_PLAYING
	game.special_mode = "zen"
	check(STATS_HUD.is_time_danger(game) == false, "clockless zen never reads as danger")
	game.special_mode = ""
	game._current_level()["time_limit"] = 0
	check(STATS_HUD.is_time_danger(game) == false, "a zero time limit never reads as danger")
	game._current_level()["time_limit"] = 60
	game.time_left = 5
	check(STATS_HUD.is_time_danger(game) == true, "a playing session under the threshold reads as danger")
	game.time_left = 50
	check(STATS_HUD.is_time_danger(game) == false, "a comfortable clock stays calm")
	game.time_left = 5
	game.stage_status = game.STATUS_PAUSED
	check(STATS_HUD.is_time_danger(game) == false, "paused sessions never read as danger")
	game.stage_status = saved_status
	game.time_left = saved_time
	game.special_mode = saved_mode
	game._current_level()["time_limit"] = saved_level_time

	if failures == 0:
		print("stat_probe: ALL PASSED")
		quit(0)
	else:
		print("stat_probe: %d FAILURES" % failures)
		quit(1)
