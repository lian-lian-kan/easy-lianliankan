extends Reference

# Input handling: board tile clicks (select/match/arm routing) and the
# keyboard shortcut router. Statics take the live game node.

static func _on_tile_pressed(game, button):
	if not _tile_press_valid(game, button):
		return
	var r = int(button.get_meta("row"))
	var c = int(button.get_meta("col"))
	var point = Vector2(r, c)
	if _dispatch_armed_power_up(game, point):
		return
	if game._is_memory_mode():
		game._on_memory_tile_pressed(point, r, c)
		return
	if _handle_selection_toggles(game, point):
		return
	game.moves += 1
	var previous = game.selected
	var selected_value = int(game.board[previous.x][previous.y])
	var target_value = int(game.board[point.x][point.y])
	if not game._values_match(selected_value, target_value):
		var hint = "合十消：两张牌的数字相加要等于 10 哦" if game._is_sum_mode() else "请先选择相同图案"
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

# Gate every tile click: playing state, real tile, and mechanism playability.
static func _tile_press_valid(game, button) -> bool:
	if game.stage_status != game.STATUS_PLAYING:
		return false
	if button == null:
		return false
	var r = int(button.get_meta("row"))
	var c = int(button.get_meta("col"))
	if game.board[r][c] == 0:
		return false
	var point = Vector2(r, c)
	if not game._is_coord_playable(point):
		if game.BOARD_MECHANICS.is_rock(game, point):
			game._show_message("🪨 石头牌消不掉，用 💣 炸开或绕过去", 1.0)
		elif game._is_fogged(point):
			game._show_message("迷雾遮住了这块，先消除里面的方块", 1.0)
		else:
			game._show_message("⛓️ 先消除它旁边的方块来解锁", 1.0)
		return false
	return true

# Armed click-targeted power-ups take over the next board click.
static func _dispatch_armed_power_up(game, point) -> bool:
	if game.frost_pending:
		game._execute_warm_patch(point)
		return true
	if game.bomb_pending:
		game._execute_bomb(point)
		return true
	if game.rainbow_pending:
		game._execute_rainbow_click(point)
		return true
	return false

# First select and re-click deselect; true when the click was consumed here.
static func _handle_selection_toggles(game, point) -> bool:
	if game.selected.x < 0:
		game.selected = point
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
static func _execute_pair_match(game, path, previous, point):
	var a = previous
	var b = point
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
static func _on_memory_tile_pressed(game, point, r, c):
	if game.memory_previewing or game.memory_lock:
		return
	if _handle_memory_toggles(game, point, r, c):
		return
	game.moves += 1
	var previous = game.selected
	var selected_value = int(game.board[previous.x][previous.y])
	var target_value = int(game.board[r][c])
	if selected_value != target_value:
		_reject_memory_pair(game, previous, point)
		return
	var path = game._find_path(game.board, previous, point)
	if path.empty():
		_memory_path_blocked(game, previous, point)
		return
	_execute_memory_match(game, path, previous, point)

# First select and re-click deselect in memory mode (face-up tracking).
static func _handle_memory_toggles(game, point, r, c) -> bool:
	if game.selected.x < 0:
		game.selected = point
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

# A real memory match: score, effects, damage and post-board resolve.
static func _execute_memory_match(game, path, previous, point):
	var a = previous
	var b = point
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.memory_revealed.erase(game._memory_key(a))
	game.memory_revealed.erase(game._memory_key(b))

	game.audio.play_eliminate_combo(game.combo)
	var score_result = game._apply_combo_gain(int(game.tuning.get("base_score", 10)))
	game._show_path(path, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])

	var pair_patterns = [int(game.board[a.x][a.y]), int(game.board[b.x][b.y])]
	game._apply_match_damage(a, b)
	game.BOARD_MECHANICS.defuse_pair(game, a, b)
	game._on_collect_pair_progress(pair_patterns)
	game._consume_move()
	_refresh_target_pair(game)

	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()
# Keyboard map: scancode -> action spec. "playing" gates on STATUS_PLAYING,
# "arg" passes one argument; anything else is called bare. Escape (fullscreen
# exit) keeps its own branch because it only consumes when fullscreen is on.
const KEY_ACTIONS = {
	KEY_P: {"method": "_on_pause_pressed"},
	KEY_H: {"method": "_on_hint_pressed", "playing": true},
	KEY_A: {"method": "_on_auto_pressed", "playing": true},
	KEY_S: {"method": "_on_shuffle_pressed", "playing": true},
	KEY_R: {"method": "_on_reset_pressed"},
	KEY_BRACKETLEFT: {"method": "_cycle_level_selection", "arg": -1},
	KEY_BRACKETRIGHT: {"method": "_cycle_level_selection", "arg": 1},
	KEY_ENTER: {"method": "_on_jump_level_pressed"},
	KEY_KP_ENTER: {"method": "_on_jump_level_pressed"},
	KEY_F: {"method": "_toggle_fullscreen_mode"},
	KEY_1: {"method": "_use_power_up", "arg": "time_freeze"},
	KEY_2: {"method": "_use_power_up", "arg": "auto_match"},
	KEY_3: {"method": "_use_power_up", "arg": "reshuffle"},
	KEY_4: {"method": "_use_power_up", "arg": "magnifier"},
	KEY_5: {"method": "_use_power_up", "arg": "time_sand"},
	KEY_6: {"method": "_use_power_up", "arg": "bomb"},
	KEY_7: {"method": "_use_power_up", "arg": "rainbow"},
	KEY_8: {"method": "_use_power_up", "arg": "warm_patch"},
}

static func _unhandled_input(game, event):
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.scancode == KEY_ESCAPE:
			if OS.window_fullscreen:
				OS.window_fullscreen = false
				game._show_message("已退出全屏", 0.8)
				game.accept_event()
			return
		var action = KEY_ACTIONS.get(key_event.scancode)
		if action == null:
			return
		if action.get("playing", false) and game.stage_status != game.STATUS_PLAYING:
			return
		if action.has("arg"):
			game.call(action["method"], action["arg"])
		else:
			game.call(action["method"])
		game.accept_event()
# Reveal a hint pair: face-up in memory mode, highlight tiles, draw the
# hint path and refresh. Shared by the hint button and the husband rescue.
# Returns false when the hint is empty (callers decide reshuffle etc).
static func reveal_hint_pair(game, hint):
	if hint.empty():
		return false
	if game._is_memory_mode():
		game.memory_revealed[game._memory_key(hint["a"])] = true
		game.memory_revealed[game._memory_key(hint["b"])] = true
	game.hint_tiles = [hint["a"], hint["b"]]
	game.error_tiles.clear()
	var hint_path: Array = hint["path"]
	game._show_path(hint_path, "hint", int(game.tuning.get("hint_preview_ms", 1400)))
	game._animate_hint_tiles(game.hint_tiles)
	game._refresh_ui()
	game._refresh_board_visuals()
	return true


static func _on_hint_pressed(game):
	if game.stage_status != game.STATUS_PLAYING:
		return

	game.level_hints_used += 1
	game.audio.play_hint()

	var hint = game._find_any_hint(game.board)
	if hint.empty():
		game._on_shuffle_pressed()
		return

	var is_memory = game._is_memory_mode()
	# Selected state must land before the reveal's refresh so the first
	# tile renders its selection styling in the same pass.
	if not is_memory:
		game.selected = hint["a"]
	reveal_hint_pair(game, hint)
	if is_memory:
		game._memory_schedule_hide([hint["a"], hint["b"]], float(game.special_level.get("memory_face_up", 1.0)) * 1.5)
		game._show_message("已翻开一组可消除方块", 1.1)
	else:
		game._show_message("已高亮一组可消除方块", 1.1)
		game._consume_time_cost(int(game.tuning.get("hint_time_cost_seconds", 1)))

static func _on_auto_pressed(game):
	if game.stage_status != game.STATUS_PLAYING:
		return

	game.level_auto_used += 1

	var hint = game._find_any_hint(game.board)
	if hint.empty():
		game._on_shuffle_pressed()
		return

	var a = hint["a"]
	var b = hint["b"]
	var hint_path: Array = hint["path"]

	var cracked = []
	var removed = []
	game._damage_tile(a, cracked, removed)
	game._damage_tile(b, cracked, removed)
	game._break_chains_around(removed)
	# Frozen tiles survive as blockers, so judge the clear AFTER the damage.
	var will_clear = game._remaining_tiles_count() == 0
	game._consume_move()

	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.moves += 1

	game._show_path(hint_path, "eliminate", int(game.tuning.get("hint_preview_ms", 1400)))
	game._play_eliminate_effects([a, b])

	var score_result = game._apply_combo_gain(int(game.tuning.get("base_score", 10)))
	game._show_message("自动消除 +" + str(score_result["gain"]), 0.9)
	if not will_clear:
		game._consume_time_cost(int(game.tuning.get("auto_eliminate_time_cost_seconds", 2)))

	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()


static func _on_shuffle_pressed(game):
	if game.stage_status != game.STATUS_PLAYING:
		return

	game.audio.play_shuffle()

	game._animate_shuffle_wave()
	game._reshuffle_board(game.board)
	game._spawn_board_particles(14, Color("60a5fa"), 0.9)

	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game._show_message("已洗牌", 0.8)
	game._consume_time_cost(int(game.tuning.get("shuffle_time_cost_seconds", 1)))
	game._refresh_ui()
	game._refresh_board_visuals()

static func _on_reset_pressed(game):
	if game._is_special_session():
		game._start_special_mode(game.special_mode)
		return
	if game.stage_status == game.STATUS_COMPLETED:
		game._start_level(0, true)
		return
	game._start_level(game.level_index, false)

static func _on_jump_level_pressed(game):
	var target = game._selected_level_option_index()
	if not game._is_level_unlocked(target):
		game._show_message("该关卡尚未解锁", 0.9)
		game._sync_level_select_selection()
		return
	game._start_level(target, true)

static func _on_pause_pressed(game):
	if game.stage_status == game.STATUS_PLAYING:
		game._pause_stage()
	elif game.stage_status == game.STATUS_PAUSED:
		game._resume_stage()

static func _cycle_level_selection(game, step):
	if game.level_select_option == null or game.level_select_option.get_item_count() == 0:
		return
	var from_idx = game._selected_level_option_index()
	var next_idx = game.PROGRESSION_SCRIPT.find_next_unlocked(game.progression_state, from_idx, step, game.campaign_levels.size())
	game.level_select_option.select(next_idx)
	game._show_message("已选择" + game._level_label_by_index(next_idx) + "，按 Enter 跳转", 0.9)
	game._refresh_ui()
	game._trigger_level_highlight()

static func _toggle_fullscreen_mode(game):
	if OS.window_fullscreen:
		OS.window_fullscreen = false
		game._show_message("已退出全屏", 0.8)
	else:
		OS.window_fullscreen = true
		game._show_message("已进入全屏", 0.8)

