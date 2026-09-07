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
	if score_result["combo"] > 1:
		game._show_message("连击 x" + str(score_result["combo"]) + " +" + str(score_result["gain"]), 0.88)
		game._show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	game._show_path(path, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])

	game._apply_match_damage(a, b)
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
	if score_result["combo"] > 1:
		game._show_message("连击 x" + str(score_result["combo"]) + " +" + str(score_result["gain"]), 0.88)
		game._show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	game._show_path(path, "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])

	game._apply_match_damage(a, b)
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

