extends SceneTree

# 关卡工坊：分享码编码/解码往返、校验和防抄错、布局校验（成对/有解）、
# 自定义会话装配。

const LEVEL_EDITOR = preload("res://scripts/modes/level_editor.gd")
const ENGINE = preload("res://scripts/board/board_engine.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== level_editor_test")

	# --- grid helpers + dims
	check(LEVEL_EDITOR.blank_grid(2, 3).size() == 2, "blank grid shapes rows")
	check(LEVEL_EDITOR.dims_ok(6, 6, 4), "6x6 kinds4 is legal")
	check(not LEVEL_EDITOR.dims_ok(3, 6, 4), "rows below the floor rejected")
	check(not LEVEL_EDITOR.dims_ok(6, 6, 13), "too many kinds rejected")
	check(not LEVEL_EDITOR.dims_ok(5, 5, 4), "odd tile capacity rejected")

	# --- default state
	var state = LEVEL_EDITOR.default_state()
	check(int(state["rows"]) == 6 and int(state["grid"][0].size()) == 6, "default canvas is 6x6")
	check(int(state["active_kind"]) == 1, "the first kind starts armed")

	# --- validation
	var grid = LEVEL_EDITOR.blank_grid(4, 4)
	check(not LEVEL_EDITOR.validate_layout(grid, 4)["ok"], "an empty board is invalid")
	grid[0][0] = 1
	grid[0][1] = 1
	check(not LEVEL_EDITOR.validate_layout(grid, 4)["ok"], "a lone pair is below the tile floor")
	grid[1][0] = 1
	grid[1][1] = 1
	var verdict = LEVEL_EDITOR.validate_layout(grid, 4)
	check(verdict["ok"], "a 2x2 block of one kind validates: " + str(verdict["reason"]))
	grid[2][0] = 1
	check(not LEVEL_EDITOR.validate_layout(grid, 4)["ok"], "odd kind count rejects the layout")
	grid[2][0] = 5
	check(not LEVEL_EDITOR.validate_layout(grid, 4)["ok"], "value beyond kinds rejects the layout")

	# --- share code round trip (sparse + dense boards)
	var play_board = ENGINE.create_playable_board({"rows": 6, "cols": 6, "kinds": 4})
	var code = LEVEL_EDITOR.encode(play_board, 4)
	check(code.begins_with("LK1"), "share codes carry the LK1 prefix")
	check(code.length() < 120, "share codes stay compact (got %d)" % code.length())
	var decoded = LEVEL_EDITOR.decode(code)
	check(decoded["ok"], "a dealt board round-trips: " + str(decoded["reason"]))
	var same := true
	for r in range(6):
		for c in range(6):
			if int(decoded["grid"][r][c]) != int(play_board[r][c]):
				same = false
	check(same, "round-trip preserves every cell")
	check(int(decoded["kinds"]) == 4 and int(decoded["rows"]) == 6, "round-trip preserves dims and kinds")

	# --- corruption + tampering
	var corrupt = LEVEL_EDITOR.decode(code.substr(0, code.length() - 4) + "AAAA")
	check(not corrupt["ok"], "damaged payloads fail the checksum")
	check(not LEVEL_EDITOR.decode("XXnonsense")["ok"], "wrong prefix rejected")
	check(not LEVEL_EDITOR.decode("LK1")["ok"], "empty payload rejected")
	check(LEVEL_EDITOR.decode("  " + code + "  ")["ok"], "surrounding whitespace is tolerated")

	# --- custom session assembly
	var level = LEVEL_EDITOR.build_custom_level(play_board, 4)
	check(str(level["mode"]) == "custom", "custom level carries its mode")
	check(level.has("custom_grid"), "custom level embeds the grid")
	check(int(level["time_limit"]) == 60 + 36 * 2, "clock scales with the tile count")

	if failures == 0:
		print("level_editor_test: ALL PASSED")
		quit(0)
	else:
		print("level_editor_test: %d FAILURES" % failures)
		quit(1)
