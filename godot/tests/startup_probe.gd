extends SceneTree

# Startup smoke for every playable mode: each special mode must enter, build
# its own board/pile/card state, land in PLAYING with the right clock, and
# exit cleanly back to the campaign. This guards the wiring that pure-logic
# probes cannot see (the class of bug where tray started an empty board).

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _board_cells(game) -> int:
	var n = 0
	for row in game.board:
		for v in row:
			if int(v) > 0:
				n += 1
	return n

func _nonzero_grid(grid) -> bool:
	for row in grid:
		for v in row:
			if int(v) > 0:
				return true
	return false

func _init() -> void:
	print("== startup_probe")
	var scene = load("res://scenes/Main.tscn").instance()
	root.add_child(scene)
	for _i in range(8):
		yield(self, "idle_frame")
	var game = scene
	game.progression_state["highest_unlocked_level_index"] = 17

	# mode_id -> [expect_timed(bool), extra check lambda replaced by inline ifs]
	var modes = ["daily", "time_attack", "endless", "memory", "frost", "zen", "hell",
		"moves", "race", "stack", "gravity", "fog", "chain", "tray", "collect", "flip"]

	for mode_id in modes:
		game.SPECIAL_SESSION._start_special_mode(game, mode_id)
		check(game.special_mode == mode_id, "%s enters its session" % mode_id)
		check(game.stage_status == game.STATUS_PLAYING, "%s lands in PLAYING" % mode_id)

		var timed = int(game.special_level.get("time_limit", 0)) > 0
		if timed:
			check(int(game.time_left) > 0, "%s starts with clock time" % mode_id)

		match mode_id:
			"tray":
				check(game.tray_state.has("tiles") && game.tray_state["tiles"].size() == 120,
					"tray deals 120 tiles")
				check(game.tray_layer != null && game.tray_layer.visible, "tray layer visible")
				check(!game.board_grid.visible, "tray hides the connect board")
			"flip":
				check(game.flip_state.has("cards") && game.flip_state["cards"].size() == 24,
					"flip deals 24 cards")
				check(game.flip_layer != null && game.flip_layer.visible, "flip layer visible")
			"collect":
				check(game.collect_targets.size() == 3, "collect rolls 3 target patterns")
				check(game.collect_row != null && game.collect_row.visible, "collect progress row visible")
				check(_board_cells(game) > 0, "collect deals a real board")
			"memory":
				check(bool(game.memory_previewing), "memory starts with its preview")
			"frost":
				check(_nonzero_grid(game.board_armor), "frost deals armor")
			"stack":
				check(_nonzero_grid(game.board_lower), "stack buries a lower layer")
			"chain":
				check(_nonzero_grid(game.board_chain), "chain locks tiles")
			"fog":
				check(int(game._fog_layers) >= 1, "fog starts with an outer ring")
			"race":
				check(int(game.race_total_pairs) > 0, "race counts its pairs")
			"moves":
				check(int(game.moves_left) > 0, "moves mode has its budget")
			_:
				check(_board_cells(game) > 0, "%s deals a real board" % mode_id)

		# exit must return to a clean campaign session
		game.SPECIAL_SESSION._exit_special_mode(game)
		check(game.special_mode == "" && game.stage_status == game.STATUS_PLAYING,
			"%s exits back to the campaign" % mode_id)

	# the campaign board itself
	game._start_level(0, true)
	check(_board_cells(game) > 0, "campaign board deals tiles")

	if failures == 0:
		print("startup_probe: ALL PASSED")
		quit(0)
	else:
		print("startup_probe: %d FAILURES" % failures)
		quit(1)
