extends Reference

# 经典选牌交互（选第一张 → 配对判定）：棋盘的默认单击交互。选中/拒绝/
# 消除的核心也在这里——盲盒翻牌（memory_pick）复用同一套核心，只在
# 外层多做翻面记账。模式门槛（合十消/知识配对的提示文案、指定连消的
# 金光校验）沿用关卡机制，不在这里重复。

const REGISTRY = preload("res://scripts/interactions/interaction_registry.gd")

static func wants_press(game):
	return not game._is_memory_mode()

# 阶段查询带模式门槛：不是自己的会话时返回 ""，让 current_phase 诚实。
static func phase(game):
	if game._is_memory_mode():
		return ""
	if game.selected.x < 0:
		return REGISTRY.PHASE_SELECT_FIRST
	return REGISTRY.PHASE_RESOLVE_PAIR

# 一次单击推一段：无选中 → 选中（select_first）；有选中 → 配对判定。
static func on_press(game, point):
	if _handle_selection_toggles(game, point):
		return
	game.moves += 1
	var previous = game.selected
	var selected_value = int(game.board[previous.x][previous.y])
	var target_value = int(game.board[point.x][point.y])
	if not game._values_match(selected_value, target_value):
		var hint = "请先选择相同图案"
		if game._is_sum_mode():
			hint = "合十消：两张牌的数字相加要等于 10 哦"
		elif game._is_edu_mode():
			hint = "知识配对：找一对相关的牌（如 汉字↔拼音、单词↔翻译）"
		_reject_pair(game, previous, point, hint, 0.7)
		return
	if game._is_target_mode() and not _is_target_pair(game, previous, point):
		_reject_pair(game, previous, point, "✨ 先消金光高亮的那一对！", 1.0)
		return
	var path = game._find_path(game.board, previous, point)
	if path.empty():
		_reject_pair(game, previous, point, "路径不通：最多只能拐2次弯", 0.9)
		return
	_execute_pair_match(game, path, previous, point)

# First select and re-click deselect; true when the click was consumed here.
# Memory mode additionally tracks the newly revealed face.
static func _handle_selection_toggles(game, point, is_memory = false) -> bool:
	if game.selected.x < 0:
		game.selected = point
		if is_memory:
			game.memory_revealed[game._memory_key(point)] = true
		game.hint_tiles.clear()
		game.error_tiles.clear()
		game.audio.play_select()
		game._animate_select(point)
		game._refresh_board_visuals()
		return true
	if game.selected == point:
		game.selected = Vector2(-1, -1)
		game._refresh_board_visuals()
		return true
	return false

# 指定连消：本次点击的一对是否正是金光目标。
static func _is_target_pair(game, a, b) -> bool:
	var tp = game.target_pair
	return (tp[0] == a and tp[1] == b) or (tp[0] == b and tp[1] == a)

# 消对后：若目标对已被破坏（道具炸掉/变脸换走）则重挑金光目标。
static func _refresh_target_pair(game) -> void:
	if not game._is_target_mode():
		return
	var tp = game.target_pair
	var ok = tp[0].x >= 0 and tp[1].x >= 0 \
		and game.board[tp[0].x][tp[0].y] != 0 \
		and game.board[tp[1].x][tp[1].y] != 0 \
		and game._values_match(int(game.board[tp[0].x][tp[0].y]), int(game.board[tp[1].x][tp[1].y]))
	if not ok:
		game._pick_target_pair()

# Shared mismatch path: pattern differs or no connectable path. Moves the
# selection to the new tile and shows why.
static func _reject_pair(game, previous, point, message, duration):
	game.selected = point
	game.hint_tiles.clear()
	game.audio.play_error()
	game._register_perfect_miss()
	game._flash_error_tiles([previous, point])
	game._animate_select(point)
	game._show_message(message, duration)
	# Duel: a failed attempt hands the turn to the other player.
	if game._is_duel_mode() and game.stage_status == game.STATUS_PLAYING:
		game.duel_current = 1 - game.duel_current
		game._show_message("🔁 轮到玩家%d" % (game.duel_current + 1), 0.9)
	game._refresh_ui()
	game._refresh_board_visuals()

# A real match: score, path preview, effects, damage and post-board resolve.
# Campaign and memory matches share one core — the mode gates below are all
# campaign mechanics (special_mode is a single value, so they stay inert in
# memory sessions), and the memory entry only adds face-up bookkeeping.
static func _execute_pair_match(game, path, previous, point):
	_execute_match_core(game, path, previous, point)

static func _execute_match_core(game, path, a, b):
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()

	game.audio.play_eliminate_combo(game.combo)

	var score_result = game._apply_combo_gain(int(game.tuning.get("base_score", 10)))
	game._show_path(path, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])

	var pair_patterns = [int(game.board[a.x][a.y]), int(game.board[b.x][b.y])]
	game._apply_match_damage(a, b)
	game.BOARD_MECHANICS.defuse_pair(game, a, b)
	game._on_collect_pair_progress(pair_patterns)
	game._consume_move()
	# Duel: the gain lands on the current player's own scoreboard.
	if game._is_duel_mode():
		game.duel_scores[game.duel_current] += int(score_result["gain"])
	_refresh_target_pair(game)
	# Slide: every match rotates one occupied row right by one cell.
	if game._is_slide_mode() and game.BOARD_ENGINE.slide_random_row(game.board):
		game.audio.play_shuffle()
		game._show_message("🧲 滑移！整行移动了一位", 0.8)
	# Defense: each cleared pair pushes the monster one step back.
	if game._is_defense_mode():
		var cap = int(game._current_level().get("defense_start", 5))
		game.defense_distance = min(cap, game.defense_distance + 1)
		game.defense_countdown = int(game._current_level().get("defense_step", 12))
		game._show_message("⚔️ 击退！距离还有 %d 步" % game.defense_distance, 0.8)

	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()
