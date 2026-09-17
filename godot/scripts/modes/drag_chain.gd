extends Reference

# 连线消 (drag chain): press a tile and drag through orthogonally adjacent
# tiles of the same kind; releasing clears the whole chain at once. A chain of
# 2 resolves as the adjacent pair it already is, and a lone tap falls through
# to the classic click flow — both input paradigms share one board. Pure
# chain math lives here; the input handlers take the live game node.

const CHAIN_MIN = 3
const CHAIN_BONUS_PER_TILE = 0.5
const CHAIN_COLOR = Color("da77f2")

static func adjacent(a: Vector2, b: Vector2) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

# Can `point` legally extend this chain on this board: in bounds, not already
# chained, occupied, orthogonally adjacent to the chain head, and same kind
# as the head (head equality implies the whole chain shares one kind).
static func can_extend(board_state, chain, point: Vector2) -> bool:
	if chain.empty() or point.x < 0 or point.y < 0:
		return false
	if point.x >= board_state.size() or point.y >= board_state[0].size():
		return false
	for coord in chain:
		if coord == point:
			return false
	var value = int(board_state[point.x][point.y])
	if value == 0 or value != int(board_state[chain[0].x][chain[0].y]):
		return false
	return adjacent(chain[chain.size() - 1], point)

# Base score for one chain: per-tile value plus a bonus per tile beyond the
# pair (3 tiles = x1.5, 4 = x2, ...), feeding the regular combo pipeline.
static func chain_score(base_score: int, chain_size: int) -> int:
	var bonus = 1.0 + CHAIN_BONUS_PER_TILE * float(max(0, chain_size - 2))
	return int(max(1.0, round(float(base_score) * chain_size * bonus)))

# --- Input handlers (wired to every tile button, inert outside drag mode) ---

static func on_tile_button_down(game, button):
	if not game._is_drag_mode() or game.drag_active:
		return
	if button == null or game.stage_status != game.STATUS_PLAYING:
		return
	var r = int(button.get_meta("row"))
	var c = int(button.get_meta("col"))
	var point = Vector2(r, c)
	if int(game.board[r][c]) == 0 or not game._is_coord_playable(point):
		return
	game.drag_active = true
	game.drag_chain = [point]
	game.audio.play_select()
	game._refresh_board_visuals()

static func on_tile_mouse_entered(game, button):
	if not game.drag_active or button == null:
		return
	var point = Vector2(int(button.get_meta("row")), int(button.get_meta("col")))
	if not can_extend(game.board, game.drag_chain, point):
		return
	game.drag_chain.append(point)
	game.audio.play_select()
	game._refresh_board_visuals()

static func on_tile_button_up(game, button):
	if not game.drag_active:
		return
	game.drag_active = false
	var chain = game.drag_chain
	game.drag_chain = []
	if chain.size() >= CHAIN_MIN:
		# The release may land on the start button and fire `pressed` too.
		game.drag_consumed = true
		_execute_chain_clear(game, chain)
	elif chain.size() == 2:
		game.drag_consumed = true
		game.moves += 1
		var a: Vector2 = chain[0]
		var b: Vector2 = chain[1]
		game.GAME_INPUT._execute_pair_match(game, [a, b], a, b)
	else:
		game._refresh_board_visuals()

# One chain release: chain-scaled score, polyline through the chain, then the
# shared post-clear resolve (win/deadlock checks included).
static func _execute_chain_clear(game, chain):
	game.audio.play_eliminate_combo(game.combo)
	var base = chain_score(int(game.tuning.get("base_score", 10)), chain.size())
	var score_result = game._apply_combo_gain(base)
	game._show_path(chain, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects(chain)
	var cracked = []
	var removed = []
	for coord in chain:
		game._damage_tile(coord, cracked, removed)
	game._break_chains_around(removed)
	game.moves += 1
	game._show_message("🔗 连消 x%d！+%d" % [chain.size(), int(score_result["gain"])], 0.9)
	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()
