extends Reference

# Session lifecycle: level session reset, post-move resolution (win/lose/
# reshuffle/gravity), and special-mode session entry/exit. Statics take the
# live game node.

static func _start_special_mode(game, mode_id):
	var config = game.game_mode_configs.get(mode_id, {})
	if not game.SPECIAL_MODES_SCRIPT.is_mode_unlocked(mode_id, config, int(game.progression_state.get("highest_unlocked_level_index", 0))):
		game._show_message(game.SPECIAL_MODES_SCRIPT.unlock_requirement_text(mode_id, config), 1.8)
		return
	# Build the virtual level first; only touch session state once it exists.
	var level
	if mode_id == "daily":
		var today = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
		seed(game.SPECIAL_MODES_SCRIPT.seed_for_day(today))
		level = game.SPECIAL_MODES_SCRIPT.build_daily_level(today)
	elif mode_id == "time_attack":
		level = game.SPECIAL_MODES_SCRIPT.build_time_attack_level(config)
	elif mode_id == "memory":
		var tier = game.SPECIAL_MODES_SCRIPT.memory_tier(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
		level = game.SPECIAL_MODES_SCRIPT.build_memory_level(config, tier)
	elif mode_id == "frost":
		var tier = game.SPECIAL_MODES_SCRIPT.frost_tier(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
		level = game.SPECIAL_MODES_SCRIPT.build_frost_level(config, tier)
	elif mode_id == "zen" or mode_id == "hell" or mode_id == "moves" or mode_id == "race" \
				or mode_id == "stack" or mode_id == "gravity" or mode_id == "fog" or mode_id == "chain":
		level = game.SPECIAL_MODES_SCRIPT.build_classic_style_level(config, mode_id)
	else:
		level = game.SPECIAL_MODES_SCRIPT.build_endless_level(config, 1)
	game.special_mode = mode_id
	game.endless_round = 1
	game.special_level = level
	game._reset_level_session(level, true)
	print("[Game] special mode started: " + mode_id)
	if mode_id == "memory":
		game._show_message("盲盒模式！记住 %d 秒预览，然后凭记忆配对" % int(ceil(float(level.get("memory_preview", 5.0)))), 2.0)
	else:
		game._show_message(game.SPECIAL_MODES_SCRIPT.intro_text(mode_id), 1.8)

static func _exit_special_mode(game):
	game._start_level(game.level_index, false)
	game._show_message("已返回关卡模式", 1.0)

static func _reset_level_session(game, level, reset_total = false):
	game.board = game._create_playable_board(level)
	game.board_armor = game._build_frost_armor(game.board, level)
	game.board_lower = []
	game.board_chain = []
	game._fog_layers = 0
	if game._is_stack_mode():
		game._build_stack_layers(float(level.get("stack_ratio", 0.25)))
	if game._is_chain_mode():
		game._build_chain_locks(float(level.get("chain_ratio", 0.22)))
	game.frost_pending = false
	game.frost_uses = 0
	game.bomb_pending = false
	game.rainbow_pending = false
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.path_overlay.clear_path()

	for child in game.effect_layer.get_children():
		child.queue_free()

	game.moves = 0
	game.level_score = 0
	game.time_left = int(level.get("time_limit", 90))
	game.moves_left = int(level.get("move_budget", 0))
	game.race_ai_pairs = 0
	game.race_elapsed = 0
	game.race_total_pairs = int(game._remaining_tiles_count() / 2)
	if game.race_timer:
		if game.special_mode == "race":
			game.race_timer.start()
		else:
			game.race_timer.stop()
	game.stage_status = game.STATUS_PLAYING

	# Reset achievement tracking
	game.level_start_time = OS.get_ticks_msec()
	game.level_hints_used = 0
	game.level_auto_used = 0

	# Initialize power-ups based on level
	game._init_power_ups(level)
	game.time_frozen = false

	# Reset memory-mode state
	game.memory_previewing = false
	game.memory_lock = false
	game.memory_revealed.clear()
	game.memory_pending_hide.clear()
	if game.memory_hide_timer:
		game.memory_hide_timer.stop()
	if game.memory_preview_timer:
		game.memory_preview_timer.stop()

	if reset_total:
		game.total_score = 0

	game._reset_combo()
	game._hide_message()
	game.pending_level_index = -1
	game.stage_panel_label.visible = false

	game._render_board()
	game._sync_level_select_selection()
	game._refresh_ui()
	game._refresh_board_visuals()
	if game._is_memory_mode():
		game._play_level_intro_animation(level)
		game._start_memory_preview()
	else:
		game._start_second_timer()
		game._play_level_intro_animation(level)

static func _fail_moves_exhausted(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	game.stage_status = game.STATUS_FAILED
	AudioManager.play_fail()
	game._reset_combo()
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.second_timer.stop()
	game.stage_panel_label.text = "步数用完了！还剩 %d 对没消除\n点击「重开」再战，或「暂停」后返回玩法" % int(game._remaining_tiles_count() / 2)
	game.stage_panel_label.visible = true
	game._show_message("步数耗尽，挑战失败", 1.8)
	game._refresh_ui()
	game._refresh_board_visuals()

static func _resolve_after_board_changed(game):
	# 重力模式: compact columns before any win/lose evaluation.
	if game._is_gravity_mode() and game._apply_gravity():
		game._refresh_board_visuals()
	# Special sessions resolve only when the board is actually cleared;
	# partial eliminations still need the deadlock reshuffle check.
	if game.special_mode != "":
		if game._remaining_tiles_count() == 0:
			game._resolve_special_clear()
		elif game._find_any_hint(game.board).empty():
			if game._is_fog_mode() and game._fog_layers > 0:
				# Fog would trap the last tiles: recede a ring instead.
				game._fog_layers -= 1
				game._show_message("迷雾退散了一层！", 1.2)
				game._refresh_board_visuals()
				return
			if game._is_chain_mode() and game._chains_remaining() > 0:
				game._dissolve_all_chains()
				return
			game._reshuffle_board(game.board)
			game._show_message("无解，已自动重排", 1.0)
			game._refresh_board_visuals()
		return
	if game._remaining_tiles_count() == 0:
		var time_bonus_multiplier = float(game._current_level().get("time_bonus_multiplier", 2.0))
		var time_bonus = int(round(float(game.time_left) * time_bonus_multiplier))
		game.total_score += time_bonus
		game.level_score += time_bonus

		var progress_patch := {
			"score_candidate": game.total_score,
			"combo_candidate": game.combo
		}
		if game.level_index >= game.campaign_levels.size() - 1:
			progress_patch["current_level_index"] = 0
			progress_patch["highest_unlocked_level_index"] = max(0, game.campaign_levels.size() - 1)
		else:
			progress_patch["current_level_index"] = game.level_index + 1
			progress_patch["highest_unlocked_level_index"] = game.level_index + 1
		game._patch_progress_state(progress_patch)

		game._reset_combo()
		game.second_timer.stop()
		game.stage_panel_label.visible = false

		if game.level_index >= game.campaign_levels.size() - 1:
			game.stage_status = game.STATUS_COMPLETED
			game.stage_panel_label.text = "全部关卡已完成，点击'再来一轮'"
			game.stage_panel_label.visible = true
			AudioManager.play_win()
			game._show_message("全部通关！时间奖励 +" + str(time_bonus), 2.5)
			game._play_stage_clear_celebration(true)
		else:
			game.stage_status = game.STATUS_CLEARED
			game.pending_level_index = game.level_index + 1
			game.stage_panel_label.text = "过关结算中，准备进入下一关"
			game.stage_panel_label.visible = true
			AudioManager.play_win()
			game._show_message("第" + str(game._current_level().get("id", game.level_index + 1)) + "关通过！时间奖励 +" + str(time_bonus), 1.2)
			game._play_stage_clear_celebration(false)
			game.level_advance_timer.stop()
			game.level_advance_timer.wait_time = float(game.tuning.get("level_advance_ms", 1200)) / 1000.0
			game.level_advance_timer.start()

		game._refresh_ui()
		game._refresh_board_visuals()
		game._check_achievements_on_clear()
		return

	if game._find_any_hint(game.board).empty():
		game._reshuffle_board(game.board)
		game._show_message("无解，已自动重排", 1.0)
		game._refresh_board_visuals()

static func _resolve_special_clear(game):
	# 步数挑战: unused moves convert into bonus score.
	if game.special_mode == "moves":
		var move_bonus = game.moves_left * 20
		game.total_score += move_bonus
		game.level_score += move_bonus
	var time_bonus_multiplier = float(game._current_level().get("time_bonus_multiplier", 2.0))
	var time_bonus = int(round(float(game.time_left) * time_bonus_multiplier))
	game.total_score += time_bonus
	game.level_score += time_bonus

	game._reset_combo()
	game.second_timer.stop()
	if game.race_timer:
		game.race_timer.stop()
	game.stage_panel_label.visible = false
	AudioManager.play_win()

	if game.special_mode == "endless":
		game._patch_progress_state({"endless_result": {"round": game.endless_round, "score": game.total_score}})
		if game.endless_round >= 5:
			game._unlock_achievements(["endless_round_5"])
		var finished_round = game.endless_round
		game.endless_round += 1
		game.special_level = game.SPECIAL_MODES_SCRIPT.build_endless_level(game.game_mode_configs.get("endless", {}), game.endless_round)
		game.stage_status = game.STATUS_CLEARED
		game._play_stage_clear_celebration(false)
		game._show_message("第" + str(finished_round) + "轮完成！时间奖励 +" + str(time_bonus) + "，下一轮更大", 1.4)
	else:
		game._record_special_completion()
		game.stage_status = game.STATUS_COMPLETED
		game._play_stage_clear_celebration(true)

	game._refresh_ui()
	game._refresh_board_visuals()


static func _record_special_completion(game):
	var today = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	var record = game.SPECIAL_MODES_SCRIPT.RECORD_MODES.get(game.special_mode, {})
	if not record.empty():
		game._patch_progress_state({record["patch_key"]: game.total_score})
		var achievements = record["achievements"].duplicate()
		achievements.append_array(game.SPECIAL_MODES_SCRIPT.bonus_achievements(game.special_mode, {
			"frost_uses": game.frost_uses,
			"moves_left": game.moves_left,
			"move_budget": int(game._current_level().get("move_budget", 0)),
		}))
		game._unlock_achievements(achievements)
		game.stage_panel_label.text = record["label"] + "完成！得分 " + str(game.total_score) + " · 最佳 " + str(int(game.progression_state.get(record["best_key"], 0)))
		game.stage_panel_label.visible = true
		return
	if game.special_mode == "daily":
		game._patch_progress_state({
			"daily_result": {
				"date": today,
				"yesterday": game.SPECIAL_MODES_SCRIPT.yesterday_string(OS.get_date()),
				"score": game.total_score
			}
		})
		var daily = game.progression_state.get("daily_challenge", {})
		game.stage_panel_label.text = "今日挑战完成！得分 " + str(game.total_score) + " · 连胜 " + str(int(daily.get("streak", 0))) + " 天\n明天还有新的棋盘，点击「重开」可再玩今日棋盘"
		if int(daily.get("streak", 0)) >= 7:
			game._unlock_achievements(["daily_streak_7"])
	elif game.special_mode == "time_attack":
		game._patch_progress_state({"time_attack_result": game.total_score})
		game.stage_panel_label.text = "限时挑战结束！得分 " + str(game.total_score) + " · 最佳 " + str(int(game.progression_state.get("time_attack_best_score", 0)))
		if game.total_score >= 1000:
			game._unlock_achievements(["time_attack_1000"])
	else:
		game.stage_panel_label.text = "挑战完成！得分 " + str(game.total_score)
	game.stage_panel_label.visible = true

static func _apply_combo_gain(game, base_score):
	var now_ms = OS.get_ticks_msec()
	var combo_window = int(game.tuning.get("combo_window_ms", 2600))
	var max_combo = int(game.tuning.get("max_combo", 8))
	var score_multiplier = float(game._current_level().get("score_multiplier", 1.0))

	if now_ms <= game.combo_expires_ms:
		game.combo = min(game.combo + 1, max_combo)
	else:
		game.combo = 1

	game.combo_expires_ms = now_ms + combo_window
	game.combo_reset_timer.stop()
	game.combo_reset_timer.wait_time = float(combo_window) / 1000.0
	game.combo_reset_timer.start()

	var scaled_base = max(1, int(round(base_score * score_multiplier)))
	# New combo formula: base 1.5x, +0.5x per combo level
	var combo_multiplier = 1.5 + (game.combo - 1) * 0.5
	var gain = int(scaled_base * combo_multiplier)

	# Time attack: matches refund time and a hot streak ignites fever mode.
	if game.special_mode == "time_attack":
		var attack_cfg = game.game_mode_configs.get("time_attack", {})
		if game.combo >= int(attack_cfg.get("fever_mode_threshold", 5)):
			gain = int(round(gain * float(attack_cfg.get("fever_multiplier", 1.5))))
			game._show_message("🔥 Fever x" + str(game.combo), 0.8)
		var refund = int(attack_cfg.get("time_bonus_per_match", 3))
		if game.combo >= int(attack_cfg.get("fever_mode_threshold", 5)):
			refund += int(attack_cfg.get("combo_time_bonus", 1))
		game.time_left = min(999, game.time_left + refund)

	game.total_score += gain
	game.level_score += gain
	game._patch_progress_state({
		"score_candidate": game.total_score,
		"combo_candidate": game.combo
	})

	return {
		"combo": game.combo,
		"gain": gain
	}


static func _on_time_up(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	if game.special_mode != "":
		game.stage_status = game.STATUS_FAILED
		AudioManager.play_fail()
		game._reset_combo()
		game.selected = Vector2(-1, -1)
		game.hint_tiles.clear()
		game.error_tiles.clear()
		game.second_timer.stop()
		game.stage_panel_label.text = "挑战失败！得分 " + str(game.total_score) + "\n点击「重开」再战，或「暂停」后返回关卡"
		game.stage_panel_label.visible = true
		game._refresh_ui()
		game._refresh_board_visuals()
		return
	game._patch_progress_state({
		"current_level_index": game.level_index,
		"score_candidate": game.total_score,
		"combo_candidate": game.combo
	})

	game.stage_status = game.STATUS_FAILED
	AudioManager.play_fail()
	game._reset_combo()
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()

	game.second_timer.stop()
	game.stage_panel_label.text = "本关失败，点击\"重开\"重试"
	game.stage_panel_label.visible = true
	game._show_message("时间到！第" + str(game._current_level().get("id", game.level_index + 1)) + "关失败", 1.8)

	game._refresh_ui()
	game._refresh_board_visuals()


static func _memory_key(game, coord):
	return str(int(coord.x)) + "," + str(int(coord.y))


static func _start_memory_preview(game):
	game.memory_previewing = true
	game.memory_lock = true
	game.memory_revealed.clear()
	game.second_timer.stop()
	game._refresh_board_visuals()
	var preview = float(game.special_level.get("memory_preview", 5.0))
	game._show_message("记住所有图案！%d 秒后翻面" % int(ceil(preview)), 2.0)
	game.memory_preview_timer.wait_time = max(1.0, preview)
	game.memory_preview_timer.start()


static func _on_memory_preview_timeout(game):
	game.memory_previewing = false
	game.memory_lock = false
	game._refresh_board_visuals()
	game._show_message("翻面！凭记忆消除吧", 1.2)
	if game.stage_status == game.STATUS_PLAYING:
		game.second_timer.start()


static func _memory_schedule_hide(game, coords, delay):
	game.memory_pending_hide = coords.duplicate()
	game.memory_lock = true
	game.memory_hide_timer.stop()
	game.memory_hide_timer.wait_time = max(0.2, delay)
	game.memory_hide_timer.start()


static func _on_memory_hide_timeout(game):
	for coord in game.memory_pending_hide:
		game.memory_revealed.erase(game._memory_key(coord))
	game.memory_pending_hide.clear()
	game.memory_lock = false
	game._refresh_board_visuals()


static func _consume_time_cost(game, seconds):
	# Clockless modes (endless/zen/moves/race) have no time to drain.
	if game.special_mode == "endless" or int(game._current_level().get("time_limit", 90)) <= 0:
		return
	if seconds <= 0 or game.stage_status != game.STATUS_PLAYING:
		return

	game.time_left = max(0, game.time_left - seconds)
	game._refresh_ui()
	if game.time_left == 0:
		game._on_time_up()


static func _consume_move(game):
	if game.special_mode != "moves" or game.stage_status != game.STATUS_PLAYING:
		return
	game.moves_left = max(0, game.moves_left - 1)
	game._refresh_ui()
	if game.moves_left <= 0 and game._remaining_tiles_count() > 0:
		game._fail_moves_exhausted()


static func _pause_stage(game):
	if game.stage_status != game.STATUS_PLAYING:
		return

	game.stage_status = game.STATUS_PAUSED
	game.second_timer.stop()
	game.combo_reset_timer.stop()
	game._show_pause_panel()
	game._refresh_ui()
	game._refresh_board_visuals()


static func _resume_stage(game):
	if game.stage_status != game.STATUS_PAUSED:
		return

	game.stage_status = game.STATUS_PLAYING
	game._hide_pause_panel()
	game._start_second_timer()
	if game.combo > 0:
		game.combo_expires_ms = OS.get_ticks_msec() + int(game.tuning.get("combo_window_ms", 2600))
		game.combo_reset_timer.stop()
		game.combo_reset_timer.wait_time = float(game.tuning.get("combo_window_ms", 2600)) / 1000.0
		game.combo_reset_timer.start()
	game._show_message("继续游戏", 0.65)
	game._refresh_ui()
	game._refresh_board_visuals()


static func _start_level(game, next_index, reset_total = false):
	# Entering a campaign level always leaves any special session.
	game.special_mode = ""
	game.special_level = {}
	game.endless_round = 1
	game.level_index = clamp(next_index, 0, game.campaign_levels.size() - 1)
	var level = game._current_level()
	game._reset_level_session(level, reset_total)
	game._patch_progress_state({"current_level_index": game.level_index})

	var level_id = int(level.get("id", game.level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	game._show_message("进入第" + str(level_id) + "关：" + level_name + "（" + game._mode_label(mode) + "） · 快捷键 H/A/S/P/F/R/[ ]/Enter", 1.35)


static func _fail_race_lost(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	game.stage_status = game.STATUS_FAILED
	AudioManager.play_fail()
	game._reset_combo()
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.second_timer.stop()
	if game.race_timer:
		game.race_timer.stop()
	game.stage_panel_label.text = "对手先完成了！你消除了 %d/%d 对\n点击「重开」再战" % [game.race_total_pairs - int(game._remaining_tiles_count() / 2), game.race_total_pairs]
	game.stage_panel_label.visible = true
	game._show_message("惜败！再快一点点", 1.8)
	game._refresh_ui()
	game._refresh_board_visuals()


static func _unlock_achievements(game, ids):
	var new_unlocks = []
	for achievement_id in ids:
		if not game.PROGRESSION_SCRIPT.has_achievement(game.progression_state, achievement_id):
			game.progression_state = game.PROGRESSION_SCRIPT.unlock_achievement(game.progression_state, achievement_id)
			new_unlocks.append(achievement_id)
	if new_unlocks.size() > 0:
		game._save_progress_state()
		for achievement_id in new_unlocks:
			var info = game.PROGRESSION_SCRIPT.get_achievement_info(achievement_id)
			game._show_achievement_notification(info["name"])


static func _check_achievements_on_clear(game):
	var level_clear_time = (OS.get_ticks_msec() - game.level_start_time) / 1000.0
	var current_best = float(game.progression_state.get("level_best_times", {}).get(str(game.level_index), 999999.0))
	if level_clear_time < current_best:
		game._patch_progress_state({"level_best_time": {"level_index": game.level_index, "time": level_clear_time}})
		game._show_message("🎉 新纪录！用时 " + game._format_time_seconds(level_clear_time), 2.0)
	var new_unlocks = game.PROGRESSION_SCRIPT.clear_unlocked_ids(game.progression_state, {
		"level_index": game.level_index,
		"combo": game.combo,
		"clear_time": level_clear_time,
		"hints_used": game.level_hints_used,
		"auto_used": game.level_auto_used,
		"level_count": game.campaign_levels.size(),
	})
	for achievement_id in new_unlocks:
		game.progression_state = game.PROGRESSION_SCRIPT.unlock_achievement(game.progression_state, achievement_id)
	if new_unlocks.size() > 0:
		game._save_progress_state()
		for achievement_id in new_unlocks:
			var info = game.PROGRESSION_SCRIPT.get_achievement_info(achievement_id)
			game._show_achievement_notification(info["name"])

