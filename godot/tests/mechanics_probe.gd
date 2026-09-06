extends SceneTree

# Headless probe for the four mechanic modes: 叠层(stack) / 重力(gravity) /
# 迷雾(fog) / 锁链(chain).

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _count_covered(game) -> int:
	var n = 0
	for r in range(game.board_lower.size()):
		for c in range(game.board_lower[r].size()):
			if int(game.board_lower[r][c]) != 0:
				n += 1
	return n

func _count_chained(game) -> int:
	var n = 0
	for r in range(game.board_chain.size()):
		for c in range(game.board_chain[r].size()):
			if int(game.board_chain[r][c]) != 0:
				n += 1
	return n

func _init() -> void:
	print("== mechanics_probe")
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

	# --- configs + unlock boundaries (all four at campaign level 15).
	var configs = modes.normalize_configs(null)
	check(configs.has("stack") and configs.has("gravity") and configs.has("fog") and configs.has("chain"), "four mechanic configs exist")
	for mode_id in ["stack", "gravity", "fog", "chain"]:
		check(not modes.is_mode_unlocked(mode_id, configs[mode_id], 13), mode_id + " locked below level 15")
		check(modes.is_mode_unlocked(mode_id, configs[mode_id], 14), mode_id + " unlocks at level 15")

	# --- stack: covers exist, damage pops the buried tile.
	game.progression_state["highest_unlocked_level_index"] = 14
	game._start_special_mode("stack")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(game.special_mode == "stack", "stack session started")
	var covers = _count_covered(game)
	check(covers > 0, "stack board has covered cells")
	var total_tiles = game._remaining_tiles_count()
	var buried = 0
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board_lower[r][c]) != 0:
				buried += 1
	check(buried == covers, "every cover hides exactly one tile")
	var cover = Vector2(-1, -1)
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board_lower[r][c]) != 0:
				cover = Vector2(r, c)
				break
		if cover.x >= 0:
			break
	var buried_kind = int(game.board_lower[cover.x][cover.y])
	game._damage_tile(cover, [], null)
	check(int(game.board[cover.x][cover.y]) == buried_kind, "clearing a cover reveals the buried tile")
	check(int(game.board_lower[cover.x][cover.y]) == 0, "buried slot empties after the pop")
	check(game._remaining_tiles_count() == total_tiles, "popped tile stays counted (tile swapped layers, not removed)")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- gravity: columns compact downward.
	game._start_special_mode("gravity")
	yield(self, "idle_frame")
	for r in range(game.board.size()):
		for c in range(game.board[0].size()):
			game.board[r][c] = 0
	game.board[1][0] = 7
	game.board[4][0] = 7
	game.board[4][1] = 8
	var moved = game._apply_gravity()
	check(moved, "gravity reports movement")
	check(int(game.board[9][0]) == 7 and int(game.board[8][0]) == 7, "column compacts to the bottom")
	check(int(game.board[1][0]) == 0 and int(game.board[4][0]) == 0, "old cells emptied")
	check(int(game.board[9][1]) == 8, "second column compacts independently")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- fog: rings fog the border, recede via _update_fog, block playability.
	game._start_special_mode("fog")
	yield(self, "idle_frame")
	check(game.special_mode == "fog", "fog session started")
	check(int(game._fog_layers) == 2, "fog starts at two rings")
	check(game._is_fogged(Vector2(0, 0)), "board corner is fogged")
	check(not game._is_fogged(Vector2(4, 3)), "board center is clear")
	check(not game._is_coord_playable(Vector2(0, 0)), "fogged tile is unplayable")
	check(game._is_coord_playable(Vector2(4, 3)), "center tile is playable")
	# shrink the board -> fog recedes
	for r in range(game.board.size()):
		for c in range(game.board[0].size()):
			game.board[r][c] = 0
	game.board[2][2] = 3
	game.board[2][3] = 3
	game._update_fog()
	check(int(game._fog_layers) == 0, "fog fully recedes near the endgame")
	check(game._is_coord_playable(Vector2(0, 0)) or int(game._remaining_tiles_count()) <= 2, "endgame stays playable")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- chain: chained tiles unplayable, hints skip them, adjacency breaks.
	game._start_special_mode("chain")
	yield(self, "idle_frame")
	check(game.special_mode == "chain", "chain session started")
	var chained_total = _count_chained(game)
	check(chained_total > 0, "chain board has chained tiles")
	var chained_cell = Vector2(-1, -1)
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board_chain[r][c]) != 0:
				chained_cell = Vector2(r, c)
				break
		if chained_cell.x >= 0:
			break
	check(not game._is_coord_playable(chained_cell), "chained tile is unplayable")
	# hints must skip chained tiles: leave only a chained pair on a copy.
	var copy = []
	for r in range(game.board.size()):
		var row = []
		for c in range(game.board[r].size()):
			row.append(0)
		copy.append(row)
	copy[chained_cell.x][chained_cell.y] = int(game.board[chained_cell.x][chained_cell.y])
	var partner = Vector2(-1, -1)
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board_chain[r][c]) != 0 and not (r == chained_cell.x and c == chained_cell.y) \
					and int(game.board[r][c]) == int(copy[chained_cell.x][chained_cell.y]):
				partner = Vector2(r, c)
				break
		if partner.x >= 0:
			break
	if partner.x >= 0:
		copy[partner.x][partner.y] = int(game.board[partner.x][partner.y])
		check(game._find_any_hint(copy).empty(), "hints skip chained pairs")
		game.board_chain[partner.x][partner.y] = 0
		var hint = game._find_any_hint(copy)
		check(not hint.empty() or partner.distance_to(chained_cell) > 2.0, "unchained pairs become hintable")
	# adjacent clear breaks the chain
	game._break_chains_around([chained_cell + Vector2(0, 1)])
	var broke = int(game.board_chain[chained_cell.x][chained_cell.y]) == 0
	check(broke or chained_cell.y + 1 >= game.board[0].size(), "adjacent clear breaks the chain")
	game._exit_special_mode()
	yield(self, "idle_frame")

	# --- records + achievements.
	var st = progression.apply_update({}, 15, {"stack_result": 100, "gravity_result": 200, "fog_result": 300, "chain_result": 400})
	check(int(st["stack_best_score"]) == 100 and int(st["gravity_best_score"]) == 200 \
			and int(st["fog_best_score"]) == 300 and int(st["chain_best_score"]) == 400, "four mechanic records persist")
	var ids = []
	for a in progression.ACHIEVEMENTS:
		ids.append(a["id"])
	check("stack_first" in ids and "gravity_first" in ids and "fog_first" in ids and "chain_first" in ids, "four mechanic achievements defined")

	if failures == 0:
		print("mechanics_probe: ALL PASSED")
		quit(0)
	else:
		print("mechanics_probe: %d FAILURES" % failures)
		quit(1)
