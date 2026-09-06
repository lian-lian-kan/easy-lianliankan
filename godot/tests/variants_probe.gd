extends SceneTree

# Headless probe for the four classic-rules variants: 休闲(zen) / 地狱(hell) /
# 步数挑战(moves) / 竞速对战(race).

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== variants_probe")
	var modes = load("res://scripts/special_modes.gd")
	var progression = load("res://scripts/progression.gd")
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("FAIL - cannot load Main.tscn")
		quit(1)
		return
	var game = scene.instance()
	root.add_child(game)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	# --- Pure logic: configs, unlock boundaries, builders.
	var configs = modes.normalize_configs(null)
	check(configs.has("zen") and configs.has("hell") and configs.has("moves") and configs.has("race"), "all four variant configs exist")
	check(modes.is_mode_unlocked("zen", configs["zen"], 0), "zen is open from the start")
	check(not modes.is_mode_unlocked("hell", configs["hell"], 10), "hell locked below level 12")
	check(modes.is_mode_unlocked("hell", configs["hell"], 11), "hell unlocks at level 12")
	check(not modes.is_mode_unlocked("moves", configs["moves"], 12), "moves locked below level 14")
	check(modes.is_mode_unlocked("moves", configs["moves"], 13), "moves unlocks at level 14")
	check(not modes.is_mode_unlocked("race", configs["race"], 13), "race locked below level 15")
	check(modes.is_mode_unlocked("race", configs["race"], 14), "race unlocks at level 15")

	var zen_level = modes.build_classic_style_level(configs["zen"], "zen")
	check(str(zen_level.get("mode", "")) == "zen" and int(zen_level.get("time_limit", -1)) == 0, "zen level has no clock")
	var hell_level = modes.build_classic_style_level(configs["hell"], "hell")
	check(int(hell_level.get("rows", 0)) * int(hell_level.get("cols", 0)) == 96 and int(hell_level.get("time_limit", 0)) == 100, "hell level is 12x8 with 100s")
	var moves_level = modes.build_classic_style_level(configs["moves"], "moves")
	check(int(moves_level.get("move_budget", 0)) == 56, "moves level carries the move budget")
	var race_level = modes.build_classic_style_level(configs["race"], "race")
	check(abs(float(race_level.get("ai_interval", 0.0)) - 8.5) < 0.001, "race level carries the AI interval")

	# --- zen: clockless, tools cannot drain time, no danger pulse.
	game._start_special_mode("zen")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(game.special_mode == "zen", "zen session started")
	check(int(game.time_left) == 0, "zen time is zero")
	for _i in range(3):
		game._on_second_tick()
	check(game.stage_status == game.STATUS_PLAYING, "zen does not fail on clock ticks")
	game._consume_time_cost(30)
	check(game.stage_status == game.STATUS_PLAYING, "tool time cost is a no-op in zen")
	check(not game._is_time_danger(), "zen time card never pulses danger")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- hell: stripped loadout, tight clock.
	game.progression_state["highest_unlocked_level_index"] = 14
	game._start_special_mode("hell")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(game.special_mode == "hell", "hell session started")
	check(int(game.power_ups.get("bomb", -1)) == 0 and int(game.power_ups.get("magnifier", -1)) == 0 \
			and int(game.power_ups.get("time_sand", -1)) == 0 and int(game.power_ups.get("rainbow", -1)) == 0, "hell strips the strong tools")
	check(int(game.power_ups.get("time_freeze", -1)) == 1 and int(game.power_ups.get("reshuffle", -1)) == 1, "hell keeps freeze+shuffle")
	check(int(game.time_left) == 100, "hell clock is 100s")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- moves: budget decrements, dry budget loses.
	game._start_special_mode("moves")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(game.special_mode == "moves", "moves session started")
	check(int(game.moves_left) == 56, "move budget initialized")
	var before_remaining = game._remaining_tiles_count()
	check(before_remaining > 0, "moves board has tiles")
	game._consume_move()
	game._consume_move()
	game._consume_move()
	check(int(game.moves_left) == 53, "three moves consumed")
	check(game.stage_status == game.STATUS_PLAYING, "still playing with moves left")
	game.moves_left = 1
	game._consume_move()
	check(game.stage_status == game.STATUS_FAILED, "dry budget fails the run")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- race: AI progress ticks and can win.
	game._start_special_mode("race")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(game.special_mode == "race", "race session started")
	check(game.race_total_pairs > 0, "race pair total computed")
	check(int(game.race_ai_pairs) == 0, "AI starts at zero")
	game.race_elapsed = 7
	game._on_race_tick()
	check(int(game.race_ai_pairs) == 1, "AI clears its first pair after the interval")
	game.race_elapsed = 3
	game._on_race_tick()
	check(int(game.race_ai_pairs) == 1, "AI does not fire before the interval")
	game.race_ai_pairs = game.race_total_pairs - 1
	game.race_elapsed = 7
	game._on_race_tick()
	check(game.stage_status == game.STATUS_FAILED, "AI finishing first fails the run")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- progression records + achievements.
	var st = progression.apply_update({}, 15, {"moves_result": 500, "race_result": 700, "zen_result": 300, "hell_result": 900})
	check(int(st["moves_best_score"]) == 500 and int(st["race_best_score"]) == 700 \
			and int(st["zen_best_score"]) == 300 and int(st["hell_best_score"]) == 900, "four new records persist via apply_update")
	var ids = []
	for a in progression.ACHIEVEMENTS:
		ids.append(a["id"])
	check("zen_first" in ids and "hell_first" in ids and "moves_first" in ids \
			and "moves_saver" in ids and "race_first" in ids, "five new achievements defined")

	if failures == 0:
		print("variants_probe: ALL PASSED")
		quit(0)
	else:
		print("variants_probe: %d FAILURES" % failures)
		quit(1)
