extends Reference

# Session heartbeat: timer factory and every callback the timers drive
# (clock ticks, message/error/combo/highlight timeouts, level advance,
# freeze thaw, memory preview/hide, race AI). Extracted from ui_hud.gd
# so the main-screen module stays build/refresh/layout only.

static func _build_timers(game):
	game.second_timer = Timer.new()
	game.second_timer.wait_time = 1.0
	game.second_timer.one_shot = false
	game.second_timer.connect("timeout", game, "_on_second_tick")
	game.add_child(game.second_timer)

	game.message_timer = Timer.new()
	game.message_timer.one_shot = true
	game.message_timer.connect("timeout", game, "_on_message_timeout")
	game.add_child(game.message_timer)

	game.error_timer = Timer.new()
	game.error_timer.one_shot = true
	game.error_timer.connect("timeout", game, "_on_error_timeout")
	game.add_child(game.error_timer)

	game.combo_reset_timer = Timer.new()
	game.combo_reset_timer.one_shot = true
	game.combo_reset_timer.connect("timeout", game, "_on_combo_reset_timeout")
	game.add_child(game.combo_reset_timer)

	game.level_highlight_timer = Timer.new()
	game.level_highlight_timer.one_shot = true
	game.level_highlight_timer.connect("timeout", game, "_on_level_highlight_timeout")
	game.add_child(game.level_highlight_timer)

	game.level_advance_timer = Timer.new()
	game.level_advance_timer.one_shot = true
	game.level_advance_timer.connect("timeout", game, "_on_level_advance_timeout")
	game.add_child(game.level_advance_timer)

	game.time_freeze_timer = Timer.new()
	game.time_freeze_timer.one_shot = true
	game.time_freeze_timer.connect("timeout", game, "_on_time_freeze_timeout")
	game.add_child(game.time_freeze_timer)

	game.memory_preview_timer = Timer.new()
	game.memory_preview_timer.one_shot = true
	game.memory_preview_timer.connect("timeout", game, "_on_memory_preview_timeout")
	game.add_child(game.memory_preview_timer)

	game.memory_hide_timer = Timer.new()
	game.memory_hide_timer.one_shot = true
	game.memory_hide_timer.connect("timeout", game, "_on_memory_hide_timeout")
	game.add_child(game.memory_hide_timer)

	game.race_timer = Timer.new()
	game.race_timer.wait_time = 1.0
	game.race_timer.one_shot = false
	game.race_timer.connect("timeout", game, "_on_race_tick")
	game.add_child(game.race_timer)

static func _on_second_tick(game):
	if game.stage_status != game.STATUS_PLAYING:
		return

	if game.time_frozen:
		return

	# Endless/zen/moves/race have no countdown clock at all.
	if game.special_mode == "endless" or int(game._current_level().get("time_limit", 90)) <= 0:
		return

	game.time_left = max(0, game.time_left - 1)
	game._refresh_ui()

	if game.time_left <= 0:
		game._on_time_up()

static func _on_race_tick(game):
	if game.special_mode != "race" or game.stage_status != game.STATUS_PLAYING:
		return
	var interval = max(1.0, float(game._current_level().get("ai_interval", 8.5)))
	game.race_elapsed += 1
	if game.race_elapsed < int(interval):
		return
	game.race_elapsed = 0
	game.race_ai_pairs = min(game.race_total_pairs, game.race_ai_pairs + 1)
	AudioManager.play_select()
	game._refresh_ui()
	if game.race_ai_pairs >= game.race_total_pairs:
		game._fail_race_lost()

static func _on_message_timeout(game):
	game.message_label.visible = false

static func _on_error_timeout(game):
	game.error_tiles.clear()
	game._refresh_board_visuals()

static func _on_combo_reset_timeout(game):
	game._reset_combo()
	game._refresh_ui()

static func _on_level_highlight_timeout(game):
	if game.level_select_option != null:
		game.level_select_option.modulate = game.LEVEL_NORMAL_COLOR

static func _on_level_advance_timeout(game):
	if game.stage_status != game.STATUS_CLEARED:
		return
	if game.special_mode == "endless":
		# Next endless round keeps the running total score.
		game._reset_level_session(game.special_level, false)
		game._show_message("第" + str(game.endless_round) + "轮开始", 1.2)
		return
	if game.pending_level_index < 0:
		return

	var next_index = game.pending_level_index
	game.pending_level_index = -1
	game._start_level(next_index, false)

static func _on_time_freeze_timeout(game):
	game.time_frozen = false
	game._show_message("时间恢复流逝", 1.0)

# Memory preview/hide timeouts live in session.gd with the memory session
# domain; hud_timers only owns the generic heartbeat callbacks.
