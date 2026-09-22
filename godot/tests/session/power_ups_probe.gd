extends SceneTree

# Headless probe for the bomb/rainbow click-targeted power-ups and the
# petal/confetti effect layers. Instantiates the real game scene, starts a
# campaign level that grants the power-ups, and drives the same entry points
# the tile buttons and keyboard shortcuts use.

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _find_same_kind_pair(game) -> Array:
	var board = game.board
	for r in range(board.size()):
		for c in range(board[r].size()):
			var a = Vector2(r, c)
			if int(board[r][c]) == 0:
				continue
			for r2 in range(board.size()):
				for c2 in range(board[r2].size()):
					var b = Vector2(r2, c2)
					if not (a.x == b.x and a.y == b.y) and int(board[r2][c2]) == int(board[r][c]):
						return [a, b]
	return []

func _find_different_kind_pair(game) -> Array:
	var first_kind := -1
	var first_coord := Vector2(-1, -1)
	var board = game.board
	for r in range(board.size()):
		for c in range(board[r].size()):
			var v = int(board[r][c])
			if v == 0:
				continue
			if first_kind == -1:
				first_kind = v
				first_coord = Vector2(r, c)
			elif v != first_kind:
				return [first_coord, Vector2(r, c)]
	return []

func _dicts_equal(a, b) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or a[k] != b[k]:
			return false
	return true

func _init() -> void:
	print("== power_ups_probe")
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("FAIL - cannot load Main.tscn")
		quit(1)
		return
	var game = scene.instance()
	root.add_child(game)

	yield(self, "idle_frame")
	yield(self, "idle_frame")

	# Start level index 9 (campaign id 10): bomb granted by difficulty rules.
	game._start_level(9, true)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	check(game.stage_status == game.STATUS_PLAYING, "level 10 starts in playing state")
	check(int(game.power_ups.get("bomb", 0)) >= 1, "level 10 grants a bomb")
	var want_loadout = {"time_freeze": 2, "reshuffle": 2, "auto_match": 1, "magnifier": 1, "time_sand": 1, "bomb": 1, "rainbow": 0, "warm_patch": 0}
	check(_dicts_equal(game.power_ups, want_loadout), "level 10 loadout follows difficulty rules (got %s)" % str(game.power_ups))
	check(game.power_up_labels.has("bomb"), "bomb label registered")
	check(game.power_up_labels.has("rainbow"), "rainbow label registered")
	check(game._petal_layer != null, "petal layer built")
	check(game._petal_timer != null, "petal timer built")

	# Petal spawner actually populates the layer.
	for _i in range(3):
		yield(self, "idle_frame")
	check(game._petal_layer.get_child_count() > 0, "petals spawn into the layer")

	# --- Bomb: arm, then execute on one tile of a same-kind pair.
	var pair = _find_same_kind_pair(game)
	check(pair.size() == 2, "found a same-kind pair on the board")
	var bomb_charges = int(game.power_ups.get("bomb", 0))
	game._use_power_up("bomb")
	check(game.bomb_pending, "bomb arms into pending mode")
	# Re-press cancels without consuming the charge.
	game._use_power_up("bomb")
	check(not game.bomb_pending, "re-press cancels armed bomb")
	check(int(game.power_ups.get("bomb", 0)) == bomb_charges, "cancel does not consume the charge")

	game._use_power_up("bomb")
	var a = pair[0]
	var b = pair[1]
	var kind_a = int(game.board[a.x][a.y])
	game._execute_bomb(a)
	yield(self, "idle_frame")
	check(not game.bomb_pending, "bomb disarms after executing")
	check(int(game.board[a.x][a.y]) == 0, "bombed tile removed")
	check(int(game.board[b.x][b.y]) == 0, "bomb partner removed")
	check(int(game.power_ups.get("bomb", 0)) == bomb_charges - 1, "executing bomb consumes exactly one charge")

	# --- Rainbow: arm, pick two tiles with DIFFERENT kinds.
	var rainbow_charges = int(game.power_ups.get("rainbow", 0))
	game.power_ups["rainbow"] = max(1, rainbow_charges)
	game._use_power_up("rainbow")
	check(game.rainbow_pending, "rainbow arms into pending mode")
	var diff = _find_different_kind_pair(game)
	check(diff.size() == 2, "found two tiles with different kinds")
	var ra = diff[0]
	var rb = diff[1]
	var kind_ra = int(game.board[ra.x][ra.y])
	var kind_rb = int(game.board[rb.x][rb.y])
	check(kind_ra != kind_rb, "rainbow pair kinds actually differ")

	game._execute_rainbow_click(ra)
	check(game.rainbow_pending, "first rainbow click keeps pending state")
	check(game.selected == ra, "first rainbow click selects the tile")
	game._execute_rainbow_click(rb)
	yield(self, "idle_frame")
	check(not game.rainbow_pending, "rainbow disarms after second click")
	check(int(game.board[ra.x][ra.y]) == 0, "rainbow first tile removed")
	check(int(game.board[rb.x][rb.y]) == 0, "rainbow second tile removed")
	check(int(game.power_ups.get("rainbow", 0)) == max(1, rainbow_charges) - 1, "executing rainbow consumes exactly one charge")

	# --- Level 12 (index 11) grants a rainbow via difficulty rules.
	game._start_level(11, true)
	yield(self, "idle_frame")
	check(int(game.power_ups.get("rainbow", 0)) >= 1, "level 12 grants a rainbow")
	check(not game.bomb_pending and not game.rainbow_pending, "starting a level clears armed states")


	# --- Loadout rules: campaign difficulty, special sessions, hell strip-back.
	game._init_power_ups({"id": 2, "mode": "rush"})
	check(int(game.power_ups.get("time_freeze", 0)) == 2 and int(game.power_ups.get("reshuffle", 0)) == 1 and int(game.power_ups.get("auto_match", 0)) == 0, "rush level 2 grants double freeze and base reshuffle")

	game.special_mode = "hell"
	game._init_power_ups({"id": 15, "mode": "classic"})
	check(_dicts_equal(game.power_ups, {"time_freeze": 1, "auto_match": 0, "reshuffle": 1, "magnifier": 0, "time_sand": 0, "bomb": 0, "rainbow": 0, "warm_patch": 0}), "hell strips back to freeze and reshuffle")

	game.special_mode = "frost"
	game._init_power_ups({"id": 13, "mode": "classic"})
	check(int(game.power_ups.get("warm_patch", 0)) == 3, "frost grants three warm patches")

	# --- Use/spend guards: mode restrictions and game state.
	game.special_mode = "endless"
	game.power_ups["time_sand"] = 2
	game._use_power_up("time_sand")
	check(int(game.power_ups.get("time_sand", 0)) == 2, "time_sand is rejected in endless mode")

	game.special_mode = ""
	game.power_ups["warm_patch"] = 2
	game._use_power_up("warm_patch")
	check(int(game.power_ups.get("warm_patch", 0)) == 2, "warm_patch is rejected outside frost")

	game.stage_status = game.STATUS_PAUSED
	game.power_ups["reshuffle"] = 2
	game._use_power_up("reshuffle")
	check(int(game.power_ups.get("reshuffle", 0)) == 2, "power-ups cannot be spent while paused")
	game.stage_status = game.STATUS_PLAYING

	# --- Confetti spawns on demand and cleans itself up.
	var before = game._petal_layer.get_child_count()
	game._spawn_confetti(6)
	check(game._petal_layer.get_child_count() >= before + 6, "confetti pieces spawn")

	if failures == 0:
		print("power_ups_probe: ALL PASSED")
		quit(0)
	else:
		print("power_ups_probe: %d FAILURES" % failures)
		quit(1)
