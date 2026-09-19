extends SceneTree

# Screen-fit contracts: factor-shape enumeration over a fixed tile count,
# least-distortion aspect picking, and the opt-out rules (editor grids,
# lock_shape, headless/zero viewports). The tile count, kinds and clock are
# the difficulty contract; only the arrangement may adapt to the screen.

const FIT = preload("res://scripts/board/board_fit.gd")

var failures := 0


func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)


func _init() -> void:
	# --- pick: the least-distortion shape wins
	var transposed = FIT.pick(8, 6, 8.0 / 6.0)
	check(int(transposed["rows"]) == 6 and int(transposed["cols"]) == 8, "the transpose matching the aspect wins")
	var square = FIT.pick(8, 8, 1.0)
	check(int(square["rows"]) == 8 and int(square["cols"]) == 8, "square boards stay square on square areas")

	# --- pick: factor shapes keep the tile count exactly
	var wide = FIT.pick(8, 6, 2560.0 / 1080.0 / 0.9)
	check(int(wide["rows"]) * int(wide["cols"]) == 48, "ultra-wide refit keeps the 48 tile count")
	check(int(wide["cols"]) == 12 and int(wide["rows"]) == 4, "an ultra-wide area deals 12x4 (least distortion)")

	# --- pick: tiny counts and degenerate aspects pass through
	var tiny = FIT.pick(2, 3, 3.0)
	check(int(tiny["rows"]) == 2 and int(tiny["cols"]) == 3, "counts under two rows of four are untouched")
	var zero = FIT.pick(8, 6, 0.0)
	check(int(zero["rows"]) == 8 and int(zero["cols"]) == 6, "a zero aspect is untouched")

	# --- level_with_fitted_shape: only the shape moves, on a copy
	var level = {"rows": 8, "cols": 6, "kinds": 6, "time_limit": 90, "name": "热身"}
	var fitted = FIT.level_with_fitted_shape(level, Vector2(2560, 1080))
	check(fitted != level, "a refit returns a copy, not the level itself")
	check(int(level["rows"]) == 8 and int(level["cols"]) == 6, "the incoming level dict is never mutated")
	check(int(fitted["kinds"]) == 6 and int(fitted["time_limit"]) == 90, "kinds and clock carry over unchanged")

	# --- opt-outs: editor grids, locked shapes, headless/zero viewports
	var custom = {"rows": 8, "cols": 6, "custom_grid": [[1]]}
	check(FIT.level_with_fitted_shape(custom, Vector2(2560, 1080)) == custom, "editor custom grids pass through untouched")
	var locked = {"rows": 8, "cols": 8, "lock_shape": true}
	check(FIT.level_with_fitted_shape(locked, Vector2(2560, 1080)) == locked, "lock_shape levels pass through untouched")
	check(FIT.level_with_fitted_shape(level, Vector2.ZERO) == level, "a zero viewport passes the level through")
	var desktop = FIT.level_with_fitted_shape(level, Vector2(1280, 720))
	check(int(desktop["rows"]) == 6 and int(desktop["cols"]) == 8, "16:9 deals the transposed 8 wide x 6 tall board")
	var portrait = FIT.level_with_fitted_shape(level, Vector2(390, 844))
	check(int(portrait["rows"]) == 8 and int(portrait["cols"]) == 6, "a phone keeps a board wider than tall")

	if failures == 0:
		print("board_fit_test: ALL PASSED")
		quit(0)
	else:
		print("board_fit_test: %d FAILURES" % failures)
		quit(1)
