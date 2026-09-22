extends Reference

# 盲盒翻牌交互（翻第一张 → 配对/盖回）：复用 pair_select 的选中与消除
# 核心，外层多做两件事——把新翻开的牌记进 memory_revealed；错配时把
# 两张牌短暂亮出再盖回，帮玩家记住位置。

const REGISTRY = preload("res://scripts/interactions/interaction_registry.gd")
const PAIR_SELECT = preload("res://scripts/interactions/pair_select.gd")

static func wants_press(game):
	return game._is_memory_mode()

# 阶段查询带模式门槛：不是自己的会话时返回 ""，让 current_phase 诚实。
static func phase(game):
	if not game._is_memory_mode():
		return ""
	if game.selected.x < 0:
		return REGISTRY.PHASE_FLIP_FIRST
	return REGISTRY.PHASE_RESOLVE_PAIR

# 一次单击推一段：无翻开 → 翻牌记账（flip_first）；有翻开 → 配对判定。
static func on_press(game, point):
	if game.memory_previewing or game.memory_lock:
		return
	if PAIR_SELECT._handle_selection_toggles(game, point, true):
		return
	game.moves += 1
	var previous = game.selected
	var selected_value = int(game.board[previous.x][previous.y])
	var target_value = int(game.board[point.x][point.y])
	if selected_value != target_value:
		_reject_memory_pair(game, previous, point)
		return
	var path = game._find_path(game.board, previous, point)
	if path.empty():
		_memory_path_blocked(game, previous, point)
		return
	_execute_memory_match(game, path, previous, point)

static func _execute_memory_match(game, path, previous, point):
	game.memory_revealed.erase(game._memory_key(previous))
	game.memory_revealed.erase(game._memory_key(point))
	PAIR_SELECT._execute_match_core(game, path, previous, point)

# Pattern mismatch: reveal both faces briefly so the player learns positions.
static func _reject_memory_pair(game, previous, point):
	game.selected = Vector2(-1, -1)
	game.memory_revealed[game._memory_key(previous)] = true
	game.memory_revealed[game._memory_key(point)] = true
	game.hint_tiles.clear()
	game.audio.play_error()
	game._flash_error_tiles([previous, point])
	game._show_message("不一样，记住位置", 0.8)
	game._memory_schedule_hide([previous, point], float(game.special_level.get("memory_face_up", 1.0)))
	game._refresh_ui()
	game._refresh_board_visuals()

# No connectable path: keep the clicked tile selected in memory mode.
static func _memory_path_blocked(game, previous, point):
	game.selected = point
	game.memory_revealed[game._memory_key(point)] = true
	game.hint_tiles.clear()
	game.audio.play_error()
	game._flash_error_tiles([previous, point])
	game._show_message("路径不通：最多只能拐2次弯", 0.9)
	game._refresh_board_visuals()
