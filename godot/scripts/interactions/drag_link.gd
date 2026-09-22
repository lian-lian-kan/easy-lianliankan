extends Reference

# 连线消手势交互（按下 → 划入延伸 → 松手结算）：与经典单击共享同一块
# 棋盘。链的纯数学（相邻/延伸/计分）留在 modes/drag_chain.gd；这里只
# 承接手势推进与结算——足够长的链整链清消，恰好两张按相邻对消除，单
# 张轻点则不动（管理器会让经典选牌流接手这次单击）。

const REGISTRY = preload("res://scripts/interactions/interaction_registry.gd")
const PAIR_SELECT = preload("res://scripts/interactions/pair_select.gd")

static func wants_press(game):
	return false

# 阶段查询带模式门槛：只有连线消会话里手势状态才是本交互的阶段。
static func phase(game):
	if not game._is_drag_mode():
		return ""
	if bool(game.get("drag_active")):
		return REGISTRY.PHASE_EXTEND
	return REGISTRY.PHASE_PRESS

static func on_press(game, _point):
	pass  # 手势不经单击路由；见 on_button_down/on_mouse_entered/on_button_up。

# --- Gesture steps (wired to every tile button, inert outside drag mode) ---

static func on_button_down(game, button):
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

static func on_mouse_entered(game, button):
	if not game.drag_active or button == null:
		return
	var point = Vector2(int(button.get_meta("row")), int(button.get_meta("col")))
	if not game.DRAG_CHAIN.can_extend(game.board, game.drag_chain, point):
		return
	game.drag_chain.append(point)
	game.audio.play_select()
	game._refresh_board_visuals()

static func on_button_up(game, button):
	if not game.drag_active:
		return
	game.drag_active = false
	var chain = game.drag_chain
	game.drag_chain = []
	if chain.size() >= game.DRAG_CHAIN.CHAIN_MIN:
		# The release may land on the start button and fire `pressed` too.
		game.drag_consumed = true
		_execute_chain_clear(game, chain)
	elif chain.size() == 2:
		game.drag_consumed = true
		game.moves += 1
		var a: Vector2 = chain[0]
		var b: Vector2 = chain[1]
		PAIR_SELECT._execute_pair_match(game, [a, b], a, b)
	else:
		game._refresh_board_visuals()

# One chain release: chain-scaled score, polyline through the chain, then the
# shared post-clear resolve (win/deadlock checks included).
static func _execute_chain_clear(game, chain):
	game.audio.play_eliminate_combo(game.combo)
	var base = game.DRAG_CHAIN.chain_score(int(game.tuning.get("base_score", 10)), chain.size())
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
