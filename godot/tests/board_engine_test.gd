extends SceneTree

# Full-coverage unit tests for scripts/board_engine.gd (pure static module).

const ENGINE = preload("res://scripts/board/board_engine.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class BlockAll:
	func playable(_coord):
		return false

class AllowAll:
	func playable(_coord):
		return true

func _init() -> void:
	print("== board_engine_test")

	# --- is_inside
	var b = [[1, 0], [2, 2]]
	check(ENGINE.is_inside(b, Vector2(1, 1)), "is_inside accepts the last cell")
	check(not ENGINE.is_inside(b, Vector2(2, 0)), "is_inside rejects past-bottom")
	check(not ENGINE.is_inside(b, Vector2(0, -1)), "is_inside rejects negative col")

	# --- pad_board
	var padded = ENGINE.pad_board([[1, 2], [3, 4]])
	check(padded.size() == 4 and padded[0].size() == 4, "pad_board adds a border ring")
	check(int(padded[1][1]) == 1 and int(padded[2][2]) == 4, "pad_board shifts content by (1,1)")
	check(int(padded[0][0]) == 0 and int(padded[3][3]) == 0, "pad_board border is empty")

	# --- count_tiles
	check(ENGINE.count_tiles([[1, 0], [2, 2]]) == 3, "count_tiles counts non-zero cells")
	check(ENGINE.count_tiles([[0, 0]]) == 0, "count_tiles zero on empty board")

	# --- format_time
	check(ENGINE.format_time(0) == "00:00", "format_time zero")
	check(ENGINE.format_time(65) == "01:05", "format_time 65s")
	check(ENGINE.format_time(599) == "09:59", "format_time 599s")
	check(ENGINE.format_time(3600) == "60:00", "format_time one hour")

	# --- ring_of
	check(ENGINE.ring_of(10, 8, 0, 0) == 0, "ring of a corner is 0")
	check(ENGINE.ring_of(10, 8, 4, 3) == 3, "ring of the center is 3")
	check(ENGINE.ring_of(10, 8, 9, 7) == 0, "ring of the far corner is 0")
	check(ENGINE.ring_of(10, 8, 8, 6) == 1, "ring of second-to-last row/col is 1")

	# --- shuffle_array keeps elements
	var arr = [1, 2, 3, 4, 5, 6, 7, 8]
	ENGINE.shuffle_array(arr)
	check(arr.size() == 8, "shuffle keeps length")
	var sorted_arr = arr.duplicate()
	sorted_arr.sort()
	check(sorted_arr == [1, 2, 3, 4, 5, 6, 7, 8], "shuffle keeps elements")

	# --- create_board: even board
	var created = ENGINE.create_board(6, 6, 4)
	check(created.size() == 6 and created[0].size() == 6, "create_board dims")
	var counts = {}
	for row in created:
		for v in row:
			counts[int(v)] = counts.get(int(v), 0) + 1
			check_v(int(v), 4)
	var parity_ok = true
	for k in counts:
		if counts[k] % 2 != 0:
			parity_ok = false
	check(parity_ok, "create_board keeps kind parity")
	check(counts.size() <= 4 and counts.size() >= 1, "create_board respects kinds bound")

	# --- create_board: odd board leaves tail empty instead of crashing
	var odd = ENGINE.create_board(5, 5, 4)
	var odd_tiles = 0
	for row in odd:
		for v in row:
			if int(v) != 0:
				odd_tiles += 1
	check(odd_tiles == 24, "odd board fills 24 of 25 cells")

	# --- find_path
	check(not ENGINE.find_path([[1, 0, 0, 1]], Vector2(0, 0), Vector2(0, 3)).empty(), "straight path exists")
	check(not ENGINE.find_path([[1, 2, 2, 1]], Vector2(0, 1), Vector2(0, 2)).empty(), "adjacent tiles connect")
	check(not ENGINE.find_path([[1, 0, 0], [0, 9, 9], [0, 0, 1]], Vector2(0, 0), Vector2(2, 2)).empty(), "route around obstacles exists")
	check(ENGINE.find_path([[9, 9, 9, 9], [9, 1, 9, 1], [9, 9, 9, 9]], Vector2(1, 1), Vector2(1, 3)).empty(), "enclosed tiles have no path")
	check(ENGINE.find_path([[1, 0, 0, 2]], Vector2(0, 0), Vector2(0, 3)).empty(), "different kinds never connect")
	check(ENGINE.find_path([[0, 0], [0, 0]], Vector2(0, 0), Vector2(1, 1)).empty(), "empty cells never connect")
	check(ENGINE.find_path([[1, 0], [0, 1]], Vector2(0, 0), Vector2(0, 0)).empty(), "same cell is not a path")
	check(ENGINE.find_path([[1, 0], [0, 1]], Vector2(-1, 0), Vector2(1, 1)).empty(), "out-of-bounds is rejected")

	# --- find_any_hint
	var hint = ENGINE.find_any_hint([[1, 2, 1]])
	check(hint.size() == 3 and ENGINE.is_inside([[1, 2, 1]], hint["a"]), "hint found for a pair")
	check(ENGINE.find_any_hint([[1, 2, 3]]).empty(), "no hint without a pair")
	var blocked_hint = ENGINE.find_any_hint([[1, 2, 1]], BlockAll.new(), "playable")
	check(blocked_hint.empty(), "hint respects a blocking filter")
	var allowed_hint = ENGINE.find_any_hint([[1, 2, 1]], AllowAll.new(), "playable")
	check(not allowed_hint.empty(), "hint respects an allowing filter")

	# --- reshuffle_board
	var odd_board = [[1, 1, 2]]
	check(ENGINE.reshuffle_board(odd_board) == false, "odd tile count refuses to reshuffle")
	var swap_board = [[1, 2, 1, 2]]
	check(ENGINE.reshuffle_board(swap_board) == true, "even board reshuffles to a solvable state")
	var filtered_board = [[1, 2, 1, 2]]
	check(ENGINE.reshuffle_board(filtered_board, BlockAll.new(), "playable") == false, "all-filtered boards cannot reshuffle")

	# --- create_playable_board
	var level = {"rows": 6, "cols": 6, "kinds": 4}
	var playable = ENGINE.create_playable_board(level)
	check(playable.size() == 6 and not ENGINE.find_any_hint(playable).empty(), "generated board is solvable")
	var playable_filtered = ENGINE.create_playable_board(level, AllowAll.new(), "playable")
	check(not ENGINE.find_any_hint(playable_filtered).empty(), "filtered generation is solvable")

	# --- compact_columns
	var g1 = [[1, 0], [0, 0], [2, 3]]
	check(ENGINE.compact_columns(g1) == true, "gravity reports movement")
	check(int(g1[1][0]) == 1 and int(g1[2][0]) == 2 and int(g1[0][0]) == 0, "column compacts downward")
	check(int(g1[2][1]) == 3, "second column compacts independently")
	var g2 = [[1, 0], [2, 3]]
	check(ENGINE.compact_columns(g2) == false, "full board reports no movement")

	# --- mechanic grids: frost armor / chains / stack burying / fog layers
	var small_board = [
		[1, 2, 0],
		[3, 0, 4],
	]
	var armor = ENGINE.build_frost_armor_grid(small_board, 0.0)
	check(armor.size() == 2 and armor[0].size() == 3 and armor[0][0] == 0 and armor[1][2] == 0, "frost ratio 0 yields an all-zero parallel grid")
	armor = ENGINE.build_frost_armor_grid(small_board, 1.0)
	check(armor[0][0] == 1 and armor[0][1] == 1 and armor[0][2] == 0 and armor[1][0] == 1 and armor[1][1] == 0 and armor[1][2] == 1, "frost ratio 1 freezes exactly the filled cells")
	check(small_board[0][0] == 1 and small_board[1][2] == 4, "frost grid build leaves the board untouched")
	armor = ENGINE.build_frost_armor_grid(small_board, 0.34)
	var frozen = 0
	for row in armor:
		for v in row:
			frozen += int(v != 0)
	check(frozen == 1, "frost ratio 0.34 freezes round(4*0.34) cells")
	check(ENGINE.build_frost_armor_grid([], 1.0).size() == 0, "empty board yields empty armor")
	var chains = ENGINE.build_chain_grid(small_board, 0.0)
	check(ENGINE.count_chains(chains) == 0, "chain ratio 0 chains nothing")
	chains = ENGINE.build_chain_grid(small_board, 1.0)
	check(ENGINE.count_chains(chains) == 4 and chains[0][2] == 0 and chains[1][1] == 0, "chain ratio 1 chains exactly the filled cells")
	chains = ENGINE.build_chain_grid(small_board, 2.0)
	check(ENGINE.count_chains(chains) == 4, "chain ratio above 1 clamps to filled count")
	check(ENGINE.count_chains([[0, 1], [1, 1]]) == 3, "count_chains counts non-zero cells")
	var stack_board = [
		[1, 2],
		[3, 4],
	]
	var lower = ENGINE.bury_stack_layer(stack_board, 0.0)
	var lower_count = 0
	for row in lower:
		for v in row:
			lower_count += int(v != 0)
	check(lower_count == 0 and stack_board[0][0] == 1 and stack_board[1][1] == 4, "stack ratio 0 leaves board unchanged")
	lower = ENGINE.bury_stack_layer(stack_board, 1.0)
	lower_count = 0
	for row in lower:
		for v in row:
			lower_count += int(v != 0)
	check(lower_count == 2, "stack ratio 1 buries at most half the tiles")
	var both = 0
	for r in range(stack_board.size()):
		for c in range(stack_board[r].size()):
			both += int(stack_board[r][c] != 0) + int(lower[r][c] != 0)
	check(both == 4, "burying preserves the tile count across both layers")
	check(ENGINE.bury_stack_layer([], 1.0).size() == 0, "empty board yields empty lower layer")
	var chain_grid = [
		[1, 0, 2],
		[0, 3, 0],
	]
	check(ENGINE.break_chains_around(chain_grid, [Vector2(0, 1)]) == 3, "breaking decrements the three orthogonally adjacent chains")
	check(chain_grid[0][0] == 0 and chain_grid[0][2] == 1 and chain_grid[1][1] == 2 and chain_grid[0][1] == 0, "only 4-neighbours are decremented, never the coord itself")
	check(ENGINE.break_chains_around(chain_grid, [Vector2(-1, -1), Vector2(0, 0)]) == 0, "out-of-bounds neighbours are skipped and zero cells never break")
	var pb = [[0]]
	var pl = [[7]]
	check(ENGINE.pop_stack(pb, pl, Vector2(0, 0)) == true and pb[0][0] == 7 and pl[0][0] == 0, "pop_stack lifts the buried tile to the visible board")
	check(ENGINE.pop_stack(pb, pl, Vector2(0, 0)) == false, "pop_stack on an emptied lower cell is a no-op")
	check(ENGINE.pop_stack(pb, pl, Vector2(3, 0)) == false and ENGINE.pop_stack(pb, pl, Vector2(-1, 0)) == false, "pop_stack guards out-of-bounds coords")
	check(ENGINE.fog_layers(24, 2) == 1 and ENGINE.fog_layers(12, 2) == 0 and ENGINE.fog_layers(240, 2) == 2 and ENGINE.fog_layers(100, 5) == 4, "fog layers follow remaining/24 clamped to max")
	check(ENGINE.zero_grid([[1, 2], [3, 4]])[1][0] == 0, "zero_grid clears every cell")

	if failures == 0:
		print("board_engine_test: ALL PASSED")
		quit(0)
	else:
		print("board_engine_test: %d FAILURES" % failures)
		quit(1)

var _kind_bound = 0
func check_v(value, bound):
	if value < 1 or value > bound:
		failures += 1
		push_error("FAIL - kind id %d out of 1..%d" % [value, bound])
	_kind_bound = bound
