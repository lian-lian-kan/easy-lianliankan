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
	# Black-hole the API (headless runs must stay offline): a live cloud
	# save adopting mid-probe would replace the board under assertion.
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")
	print("== startup_probe")
	var scene = load("res://scenes/Main.tscn").instance()
	root.add_child(scene)
	for _i in range(8):
		yield(self, "idle_frame")
	var game = scene
	game.progression_state["highest_unlocked_level_index"] = 17

	# Mode ids come from the MODES registry (the single source in
	# special_modes_data.gd), so a newly registered mode is probed the moment
	# it exists — and its dedicated witness branch below is mandatory: the
	# fallback match arm fails the run, so a mode without a witness turns CI
	# red instead of silently passing on generic checks only.
	var modes = game.SPECIAL_MODES_SCRIPT.MODES.keys()

	for mode_id in modes:
		# Daily settlement rewrites progression from the stored save, so the
		# unlock index must be re-raised before every entry attempt.
		game.progression_state["highest_unlocked_level_index"] = 17
		game.SPECIAL_SESSION._start_special_mode(game, mode_id)
		check(game.special_mode == mode_id, "%s enters its session" % mode_id)
		check(game.stage_status == game.STATUS_PLAYING, "%s lands in PLAYING" % mode_id)

		var timed = int(game.special_level.get("time_limit", 0)) > 0
		if timed:
			check(int(game.time_left) > 0, "%s starts with clock time" % mode_id)

		match mode_id:
			"tree":
				check(int(game.special_level.get("tree_height", 0)) >= 1,
					"tree enters above layer 0")
				check(int(game.special_level.get("rows", 0)) >= 2,
					"tree deals a real board")
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
			"fever":
				check(_board_cells(game) > 0, "fever deals a real board")
				check(int(game.game_mode_configs["fever"]["fever_mode_threshold"]) == 2,
					"fever ignites from combo 2")
			"perfect":
				check(_board_cells(game) > 0, "perfect deals a real board")
				check(int(game.perfect_misses) == 0, "perfect starts with zero misses")
				check(int(game.special_level.get("miss_limit", 0)) == 3, "perfect allows 3 misses")
			"rock":
				check(_board_cells(game) > 0, "rock deals a real board")
				check(int(game.BOARD_ENGINE.count_tiles(game.board)) < _board_cells(game),
					"rocks are excluded from the win count")
				# Regression: the deal-solvability pass must judge the candidate
				# grid, not the previous session's board. A stale all-rock board
				# used to shadow the new deal through the playable filter.
				# Dims follow cell_buttons so the mounted grid stays consistent
				# with the rendered view while the scenario runs.
				var fit_rows = game.cell_buttons.size()
				var fit_cols = game.cell_buttons[0].size()
				var stale := []
				for sr in range(fit_rows):
					var srow := []
					for sc in range(fit_cols):
						srow.append(game.BOARD_ENGINE.ROCK_VALUE)
					stale.append(srow)
				var previous_board = game.board
				game.board = stale
				game._create_playable_board({"id": 1, "rows": fit_rows, "cols": fit_cols,
					"kinds": 6, "time_limit": 0, "lock_shape": true})
				check(not game.BOARD_ENGINE.find_any_hint(game.board, game, "_is_coord_playable", "rock").empty(),
					"fresh deal stays playable despite stale rocks in the old board")
				check(game.board.size() == fit_rows and game.board[0].size() == fit_cols,
					"locked-shape deal keeps its dims")
				game.board = previous_board
			"defuse":
				check(_board_cells(game) > 0, "defuse deals a real board")
				check(game.board_bomb.size() > 0, "defuse seeds cursed tiles")
			"target":
				check(_board_cells(game) > 0, "target deals a real board")
				check(game.target_pair[0].x >= 0, "target picks a golden pair")
			"shift":
				check(_board_cells(game) > 0, "shift deals a real board")
				check(int(game.shift_countdown) > 0, "shift arms its interval")
			"slide":
				check(_board_cells(game) > 0, "slide deals a real board")
			"defense":
				check(_board_cells(game) > 0, "defense deals a real board")
				check(int(game.defense_distance) > 0, "defense arms the monster distance")
				check(int(game.defense_countdown) > 0, "defense arms its advance interval")
			"boss":
				check(_board_cells(game) > 0, "boss deals a real board")
				check(int(game.boss_hp) == int(game.special_level.get("boss_hp", 0)), "boss starts at full health")
				check(int(game.boss_phase) == 1, "boss starts in phase 1")
				check(int(game.defense_distance) > 0 && int(game.defense_countdown) > 0, "boss arms its creep clock")
			"sum10":
				check(_board_cells(game) > 0, "sum10 deals a real board")
				check(game.BOARD_ENGINE.values_match("sum10", 3, 7), "sum10 pairs digits summing to 10")
				check(not game.BOARD_ENGINE.values_match("sum10", 3, 6), "sum10 rejects non-ten sums")
			"diff1":
				check(_board_cells(game) > 0, "diff1 deals a real board")
				check(not game.BOARD_ENGINE.find_any_hint(game.board, game, "_is_coord_playable", "diff1").empty(),
					"diff1 deals a rule-matchable pair")
			"mult":
				check(_board_cells(game) > 0, "mult deals a real board")
				check(not game.BOARD_ENGINE.find_any_hint(game.board, game, "_is_coord_playable", "mult").empty(),
					"mult deals a rule-matchable pair")
			"duel":
				check(_board_cells(game) > 0, "duel deals a real board")
				check(int(game.duel_scores[0]) == 0 && int(game.duel_scores[1]) == 0, "duel starts with zero scores")
				check(int(game.duel_current) == 0, "duel starts with player 1")
			"daily":
				check(int(game.special_level.get("time_limit", 0)) >= 150
					&& int(game.special_level.get("time_limit", 0)) <= 180, "daily runs its 150-180s clock")
				check(int(game.special_level.get("rows", 0)) % 2 == 0, "daily board rows are even")
			"time_attack":
				check(int(game.special_level.get("time_limit", -1)) == int(game.game_mode_configs["time_attack"]["initial_time"]),
					"time_attack starts at its configured clock")
			"endless":
				check(int(game.special_level.get("time_limit", -1)) == 0, "endless has no clock")
				check(int(game.special_level.get("round_index", 0)) == 1, "endless starts at round 1")
			"zen":
				check(int(game.special_level.get("time_limit", -1)) == 0, "zen has no clock")
				check(_board_cells(game) > 0, "zen deals a real board")
			"hell":
				check(int(game.special_level.get("time_limit", 0)) > 0, "hell runs a tight clock")
				check(_board_cells(game) > 0, "hell deals a real board")
			"gravity":
				check(_board_cells(game) > 0, "gravity deals a real board")
				check(int(game.special_level.get("rows", 0)) % 2 == 0, "gravity board rows are even")
			"drag":
				check(int(game.special_level.get("rows", 0)) == 8 && int(game.special_level.get("cols", 0)) == 8,
					"drag keeps its 8x8 lock-shape board")
				check(_board_cells(game) > 0, "drag deals a real board")
			"edu":
				check(game.edu_faces.size() > 0, "edu loads its concept faces")
				check(_board_cells(game) > 0, "edu deals a real board")
			_:
				check(false, "%s has no startup witness (add a match branch)" % mode_id)

		# exit must return to a clean campaign session
		game.SPECIAL_SESSION._exit_special_mode(game)
		check(game.special_mode == "" && game.stage_status == game.STATUS_PLAYING,
			"%s exits back to the campaign" % mode_id)

	# perfect mode must fail on the third miss: two misses warn, the third
	# one fails the stage and bumps the miss counter each time.
	game.SPECIAL_SESSION._start_special_mode(game, "perfect")
	check(game.special_mode == "perfect" && game.stage_status == game.STATUS_PLAYING,
		"perfect re-enters for the miss-out probe")
	for i in range(3):
		game.SESSION._register_perfect_miss(game)
		check(int(game.perfect_misses) == i + 1, "perfect counts miss %d" % (i + 1))
	check(game.stage_status == game.STATUS_FAILED, "perfect fails on the third miss")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# the campaign board itself
	game._start_level(0, true)
	check(_board_cells(game) > 0, "campaign board deals tiles")

	# meta pages render non-empty content from an empty account (first run:
	# no wallet entries, no sign-ins, default collection state)
	for page in ["signin", "shop"]:
		game._on_nav_pressed(page)
		check(game.pages_root != null && game.pages_root.visible,
			"%s page opens the page surface" % page)
		var boxes = 0
		var stack = [game.page_content]
		while not stack.empty():
			var node = stack.pop_back()
			for child in node.get_children():
				stack.push_back(child)
			boxes += 1
		check(boxes > 3, "%s page renders a real layout (%d nodes)" % [page, boxes])
		game._on_nav_home_pressed()
		check(game.pages_root.visible == false, "%s page closes back to the board" % page)

	if failures == 0:
		print("startup_probe: ALL PASSED")
		quit(0)
	else:
		print("startup_probe: %d FAILURES" % failures)
		quit(1)
