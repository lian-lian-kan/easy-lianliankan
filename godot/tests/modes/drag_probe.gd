extends SceneTree

# 连线消探针：纯链规则 + 真实会话里的按下/拖入/松手输入流。

const DRAG_CHAIN = preload("res://scripts/modes/drag_chain.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	# Black-hole the API: a live cloud save adopting mid-probe would replace
	# the drag session (and the crafted board) with a campaign level.
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")
	print("== drag_probe")
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("FAIL - cannot load Main.tscn")
		quit(1)
		return
	var game = scene.instance()
	root.add_child(game)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	# --- pure chain math
	var board = [
		[5, 5, 5, 3],
		[5, 0, 0, 3],
		[2, 2, 0, 3],
	]
	var chain = [Vector2(0, 0)]
	check(DRAG_CHAIN.can_extend(board, chain, Vector2(0, 1)), "extends right through the same kind")
	check(DRAG_CHAIN.can_extend(board, chain, Vector2(1, 0)), "extends down through the same kind")
	check(not DRAG_CHAIN.can_extend(board, chain, Vector2(0, 2)), "skips a gap")
	check(not DRAG_CHAIN.can_extend(board, chain, Vector2(0, 0)), "never revisits the head")
	check(not DRAG_CHAIN.can_extend(board, chain, Vector2(2, 2)), "a different kind never extends")
	check(not DRAG_CHAIN.can_extend(board, chain, Vector2(9, 9)), "out of bounds rejected")
	check(not DRAG_CHAIN.can_extend(board, [], Vector2(0, 0)), "an empty chain extends nowhere")
	check(DRAG_CHAIN.adjacent(Vector2(1, 1), Vector2(1, 2)), "orthogonal adjacency holds")
	check(not DRAG_CHAIN.adjacent(Vector2(1, 1), Vector2(2, 2)), "diagonals are not adjacent")
	check(DRAG_CHAIN.chain_score(10, 2) == 20, "a pair scores plainly")
	check(DRAG_CHAIN.chain_score(10, 3) == 45, "a triple scores x1.5")
	check(DRAG_CHAIN.chain_score(10, 4) == 80, "a quad scores x2")

	# --- real session: unlock, start the drag mode
	game.progression_state["highest_unlocked_level_index"] = 16
	game._start_special_mode("drag")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(game.special_mode == "drag", "drag session started")
	check(game._is_drag_mode(), "drag mode flag live")

	# Craft a guaranteed L-run of three identical tiles in the corner. The
	# chain walks (0,0)→(0,1)→(1,1): consecutive tiles must be orthogonal
	# neighbours — (1,0) would be a diagonal jump off (0,1).
	game.board[0][0] = 7
	game.board[0][1] = 7
	game.board[1][1] = 7
	game.selected = Vector2(-1, -1)
	var before = game._remaining_tiles_count()
	var moves_before = int(game.moves)

	var start_button = game.cell_buttons[0][0]
	game._on_tile_button_down(start_button)
	check(game.drag_active, "press arms the chain")
	check(game.drag_chain.size() == 1, "press starts a one-tile chain")

	game._on_tile_mouse_entered(game.cell_buttons[0][1])
	game._on_tile_mouse_entered(game.cell_buttons[1][1])
	check(game.drag_chain.size() == 3, "entering same-kind neighbours extends the chain")
	game._on_tile_mouse_entered(game.cell_buttons[3][3])
	check(game.drag_chain.size() == 3, "a non-adjacent cell never joins")

	game._on_tile_button_up(start_button)
	check(not game.drag_active, "release disarms the chain")
	check(game.drag_chain.empty(), "release clears the chain scratchpad")
	check(game._remaining_tiles_count() == before - 3, "the whole chain cleared at once")
	check(int(game.moves) == moves_before + 1, "a chain counts as one move")
	check(game.drag_consumed, "the trailing pressed emission is suppressed")

	# The suppressed pressed must be swallowed exactly once.
	game._on_tile_pressed(start_button)
	check(not game.drag_consumed, "the guard consumes itself")

	# --- a lone tap falls through to the classic select flow (the engine
	# emits `pressed` after our manual button_up, so replay it here)
	game._on_tile_button_down(game.cell_buttons[2][2])
	game._on_tile_button_up(game.cell_buttons[2][2])
	check(game.selected == Vector2(-1, -1), "a chain of one defers to the click flow")
	game._on_tile_pressed(game.cell_buttons[2][2])
	check(game.selected == Vector2(2, 2), "the click flow selects the tile")

	# --- a two-chain resolves as the adjacent pair it already is
	game.selected = Vector2(-1, -1)
	before = game._remaining_tiles_count()
	game.board[3][3] = 4
	game.board[3][4] = 4
	game._on_tile_button_down(game.cell_buttons[3][3])
	game._on_tile_mouse_entered(game.cell_buttons[3][4])
	game._on_tile_button_up(game.cell_buttons[3][4])
	check(game._remaining_tiles_count() == before - 2, "a two-chain clears as the adjacent pair")

	if failures == 0:
		print("drag_probe: ALL PASSED")
		quit(0)
	else:
		print("drag_probe: %d FAILURES" % failures)
		quit(1)
