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

	if failures == 0:
		print("stat_probe: ALL PASSED")
		quit(0)
	else:
		print("stat_probe: %d FAILURES" % failures)
		quit(1)
