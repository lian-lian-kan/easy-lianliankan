extends SceneTree

# Screen-derived grid contracts: columns and rows come from the board area
# itself (tiles may be rectangular), the grid always fills the area with an
# even tile count >= the level's seed count, extras are bounded, distortion
# stays readable, clocks scale with the dealt count, and the opt-outs
# (editor grids, lock_shape, headless viewports) pass through untouched.

const FIT = preload("res://scripts/board/board_fit.gd")
const BOARD_ENGINE = preload("res://scripts/board/board_engine.gd")

var failures := 0


func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)


func _fills_area(cols: int, rows: int, width: float, height: float) -> bool:
	var tile_w = width / float(cols)
	var tile_h = height / float(rows)
	return tile_w <= FIT.MAX_TILE and tile_h <= FIT.MAX_TILE and tile_w >= FIT.MIN_TILE and tile_h >= FIT.MIN_TILE


func _init() -> void:
	# --- desktop 16:9: the grid tiles the area exactly, no side margins
	var desktop = FIT.grid_for(48, 1280.0, 648.0)
	check(int(desktop["rows"]) * int(desktop["cols"]) >= 48, "desktop grid deals at least the seed count")
	check((int(desktop["rows"]) * int(desktop["cols"])) % 2 == 0, "desktop grid deals an even tile count")
	check(_fills_area(int(desktop["cols"]), int(desktop["rows"]), 1280.0, 648.0), "desktop tiles stay within the readable size band")
	check(int(desktop["extra"]) <= 24, "desktop extras stay bounded (got %d)" % int(desktop["extra"]))

	# --- phone portrait: fills the tall area, tiles stay near square
	var phone = FIT.grid_for(48, 390.0, 760.0)
	check(int(phone["rows"]) * int(phone["cols"]) >= 48, "phone grid deals at least the seed count")
	check(FIT._tile_distortion(390.0, 760.0, int(phone["cols"]), int(phone["rows"])) <= FIT.MAX_DISTORTION, "phone grid distortion stays within the cap")
	check(_fills_area(int(phone["cols"]), int(phone["rows"]), 390.0, 760.0), "phone tiles stay within the readable size band")

	# --- 4K: big screens deal more tiles instead of growing poster pieces
	var four_k = FIT.grid_for(48, 3840.0, 1890.0)
	check(int(four_k["rows"]) * int(four_k["cols"]) > 48, "a 4K area deals more tiles than a phone")
	check(_fills_area(int(four_k["cols"]), int(four_k["rows"]), 3840.0, 1890.0), "4K tiles stay within the readable size band")

	# --- distortion stays readable even on awkward areas
	var awkward = FIT.grid_for(48, 1000.0, 300.0)
	check(FIT._tile_distortion(1000.0, 300.0, int(awkward["cols"]), int(awkward["rows"])) <= FIT.MAX_DISTORTION,
		"an awkward area still lands within the distortion cap (or pays extras)")

	# --- the deal stays pairable on grids kinds cannot divide evenly
	var board = BOARD_ENGINE.create_board(9, 6, 6)
	var counts := {}
	var zeros := 0
	for r in range(board.size()):
		for c in range(board[r].size()):
			var v = int(board[r][c])
			if v == 0:
				zeros += 1
			counts[v] = int(counts.get(v, 0)) + 1
	var all_even := true
	for k in counts.keys():
		if k > 0 and int(counts[k]) % 2 != 0:
			all_even = false
	check(all_even, "a 9x6 board deals every kind in even counts (54 is not divisible by 6)")
	check(BOARD_ENGINE.find_any_hint(board).empty() == false, "a 9x6 board is solvable from the start")
	var odd = BOARD_ENGINE.create_board(5, 5, 6)
	check(int(odd[4][4]) == 0, "odd boards leave exactly the tail cell empty")

	# --- level_with_fitted_shape: grid scales, clock scales, copy stays clean
	var level = {"rows": 8, "cols": 6, "kinds": 6, "time_limit": 90, "name": "热身"}
	var four_k_level = FIT.level_with_fitted_shape(level, Vector2(3840, 2160))
	check(four_k_level != level, "a refit returns a copy, not the level itself")
	check(int(level["rows"]) == 8 and int(level["cols"]) == 6, "the incoming level dict is never mutated")
	check(int(four_k_level["rows"]) * int(four_k_level["cols"]) > 48, "the 4K level deals more tiles")
	var scaled_time = int(four_k_level["time_limit"])
	var dealt = int(four_k_level["rows"]) * int(four_k_level["cols"])
	check(scaled_time == int(round(90.0 * float(dealt) / 48.0)), "the clock scales with the dealt tile count")
	var phone_level = FIT.level_with_fitted_shape(level, Vector2(390, 844))
	check(int(phone_level["time_limit"]) == 90, "an unchanged grid keeps the clock untouched")

	# --- opt-outs: editor grids, locked shapes, headless/zero viewports
	var custom = {"rows": 8, "cols": 6, "custom_grid": [[1]]}
	check(FIT.level_with_fitted_shape(custom, Vector2(3840, 2160)) == custom, "editor custom grids pass through untouched")
	var locked = {"rows": 8, "cols": 8, "lock_shape": true}
	check(FIT.level_with_fitted_shape(locked, Vector2(3840, 2160)) == locked, "lock_shape levels pass through untouched")
	check(FIT.level_with_fitted_shape(level, Vector2.ZERO) == level, "a zero viewport passes the level through")

	if failures == 0:
		print("board_fit_test: ALL PASSED")
		quit(0)
	else:
		print("board_fit_test: %d FAILURES" % failures)
		quit(1)
