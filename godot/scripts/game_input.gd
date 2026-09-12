extends Reference

# Input handling: board tile clicks (select/match/arm routing) and the
# keyboard shortcut router. Statics take the live game node.

static func _on_tile_pressed(game, button):
	if game.stage_status != game.STATUS_PLAYING:
		return
	if button == null:
		return
	var r = int(button.get_meta("row"))
	var c = int(button.get_meta("col"))
	if game.board[r][c] == 0:
		return

	var point = Vector2(r, c)

	if not game._is_coord_playable(point):
		if game._is_fogged(point):
			game._show_message("迷雾遮住了这块，先消除里面的方块", 1.0)
		else:
			game._show_message("⛓️ 先消除它旁边的方块来解锁", 1.0)
		return

	# Armed click-targeted power-ups take over the next board click.
	if game.frost_pending:
		game._execute_warm_patch(point)
		return
	if game.bomb_pending:
		game._execute_bomb(point)
		return
	if game.rainbow_pending:
		game._execute_rainbow_click(point)
		return

	if game._is_memory_mode():
		game._on_memory_tile_pressed(point, r, c)
		return

	if game.selected.x < 0:
		game.selected = point
		game.hint_tiles.clear()
		game.error_tiles.clear()
		AudioManager.play_select()
		game._animate_select(point)
		game._refresh_board_visuals()
		return

	if game.selected == point:
		game.selected = Vector2(-1, -1)
		game._refresh_board_visuals()
		return

	game.moves += 1
	var previous = game.selected

	var selected_value = int(game.board[previous.x][previous.y])
	var target_value = int(game.board[point.x][point.y])

	if selected_value != target_value:
		game.selected = point
		game.hint_tiles.clear()
		AudioManager.play_error()
		game._register_perfect_miss()
		game._flash_error_tiles([previous, point])
		game._animate_select(point)
		game._show_message("请先选择相同图案", 0.7)
		game._refresh_ui()
		game._refresh_board_visuals()
		return

	var path = game._find_path(game.board, previous, point)
	if path.empty():
		game.selected = point
		game.hint_tiles.clear()
		AudioManager.play_error()
		game._register_perfect_miss()
		game._flash_error_tiles([previous, point])
		game._animate_select(point)
		game._show_message("路径不通：最多只能拐2次弯", 0.9)
		game._refresh_ui()
		game._refresh_board_visuals()
		return

	var a = previous
	var b = point
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()

	AudioManager.play_eliminate_combo(game.combo)

	var score_result = game._apply_combo_gain(int(game.tuning.get("base_score", 10)))
	game._show_path(path, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])

	var pair_patterns = [int(game.board[a.x][a.y]), int(game.board[b.x][b.y])]
	game._apply_match_damage(a, b)
	game._on_collect_pair_progress(pair_patterns)
	game._consume_move()

	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()

static func _on_memory_tile_pressed(game, point, r, c):
	if game.memory_previewing or game.memory_lock:
		return
	if game.selected.x < 0:
		game.selected = point
		game.memory_revealed[game._memory_key(point)] = true
		game.hint_tiles.clear()
		game.error_tiles.clear()
		AudioManager.play_select()
		game._animate_select(point)
		game._refresh_board_visuals()
		return
	if game.selected == point:
		game.selected = Vector2(-1, -1)
		game._refresh_board_visuals()
		return

	game.moves += 1
	var previous = game.selected
	var selected_value = int(game.board[previous.x][previous.y])
	var target_value = int(game.board[r][c])

	if selected_value != target_value:
		# Reveal both briefly so the player learns the positions, then hide.
		game.selected = Vector2(-1, -1)
		game.memory_revealed[game._memory_key(previous)] = true
		game.memory_revealed[game._memory_key(point)] = true
		game.hint_tiles.clear()
		AudioManager.play_error()
		game._flash_error_tiles([previous, point])
		game._show_message("不一样，记住位置", 0.8)
		game._memory_schedule_hide([previous, point], float(game.special_level.get("memory_face_up", 1.0)))
		game._refresh_ui()
		game._refresh_board_visuals()
		return

	var path = game._find_path(game.board, previous, point)
	if path.empty():
		game.selected = point
		game.memory_revealed[game._memory_key(point)] = true
		game.hint_tiles.clear()
		AudioManager.play_error()
		game._flash_error_tiles([previous, point])
		game._show_message("路径不通：最多只能拐2次弯", 0.9)
		game._refresh_board_visuals()
		return

	var a = previous
	var b = point
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.memory_revealed.erase(game._memory_key(a))
	game.memory_revealed.erase(game._memory_key(b))

	AudioManager.play_eliminate_combo(game.combo)
	var score_result = game._apply_combo_gain(int(game.tuning.get("base_score", 10)))
	game._show_path(path, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])

	var pair_patterns = [int(game.board[a.x][a.y]), int(game.board[b.x][b.y])]
	game._apply_match_damage(a, b)
	game._on_collect_pair_progress(pair_patterns)
	game._consume_move()

	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()

static func _unhandled_input(game, event):
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.scancode:
			KEY_P:
				game._on_pause_pressed()
				game.accept_event()
			KEY_H:
				if game.stage_status == game.STATUS_PLAYING:
					game._on_hint_pressed()
					game.accept_event()
			KEY_A:
				if game.stage_status == game.STATUS_PLAYING:
					game._on_auto_pressed()
					game.accept_event()
			KEY_S:
				if game.stage_status == game.STATUS_PLAYING:
					game._on_shuffle_pressed()
					game.accept_event()
			KEY_R:
				game._on_reset_pressed()
				game.accept_event()
			KEY_BRACKETLEFT:
				game._cycle_level_selection(-1)
				game.accept_event()
			KEY_BRACKETRIGHT:
				game._cycle_level_selection(1)
				game.accept_event()
			KEY_ENTER, KEY_KP_ENTER:
				game._on_jump_level_pressed()
				game.accept_event()
			KEY_F:
				game._toggle_fullscreen_mode()
				game.accept_event()
			KEY_1:
				game._use_power_up("time_freeze")
				game.accept_event()
			KEY_2:
				game._use_power_up("auto_match")
				game.accept_event()
			KEY_3:
				game._use_power_up("reshuffle")
				game.accept_event()
			KEY_4:
				game._use_power_up("magnifier")
				game.accept_event()
			KEY_5:
				game._use_power_up("time_sand")
				game.accept_event()
			KEY_6:
				game._use_power_up("bomb")
				game.accept_event()
			KEY_7:
				game._use_power_up("rainbow")
				game.accept_event()
			KEY_8:
				game._use_power_up("warm_patch")
				game.accept_event()
			KEY_ESCAPE:
				if OS.window_fullscreen:
					OS.window_fullscreen = false
					game._show_message("已退出全屏", 0.8)
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
	AudioManager.play_hint()

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

	AudioManager.play_shuffle()

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

