extends Reference

# Special-mode session domain: entering/leaving the 17 special modes, their
# settlement (score records, achievements, blossom payouts) and their unique
# failure paths. Campaign session flow stays in session.gd. Functions the
# modes share with the campaign (clock, combos, revival) remain there.

const ECONOMY = preload("res://scripts/economy.gd")
const SPECIAL_MODES_SCRIPT = preload("res://scripts/special_modes.gd")
const TILE_MATCH = preload("res://scripts/tile_match.gd")
const MEMORY_FLIP = preload("res://scripts/memory_flip.gd")

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
	elif mode_id == "tray":
		level = game.SPECIAL_MODES_SCRIPT.build_tray_level(config)
	elif mode_id == "collect":
		level = game.SPECIAL_MODES_SCRIPT.build_collect_level(config)
	elif mode_id == "flip":
		level = game.SPECIAL_MODES_SCRIPT.build_memory_flip_level(config)
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
		# Kick the advance timer so the next (bigger) round actually starts.
		game.level_advance_timer.stop()
		game.level_advance_timer.wait_time = float(game.tuning.get("level_advance_ms", 1200)) / 1000.0
		game.level_advance_timer.start()
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

static func _resolve_tray_clear(game):
	game.stage_status = game.STATUS_CLEARED
	var coin_reward = 20
	game.total_score = TILE_MATCH.score_for(game.tray_state)
	game.level_score = game.total_score
	game._patch_progress_state({
		"tray_result": game.total_score,
		"coins_delta": coin_reward
	})
	AudioManager.play_win()
	game._record_special_completion()
	game._play_stage_clear_celebration(false)
	game._show_message("叠叠消通关！🌸+" + str(coin_reward), 2.0)
	game._refresh_ui()

static func _resolve_collect_clear(game):
	game.stage_status = game.STATUS_CLEARED
	var coin_reward = 20
	game._patch_progress_state({
		"collect_result": game.total_score,
		"coins_delta": coin_reward
	})
	AudioManager.play_win()
	game._record_special_completion()
	game._play_stage_clear_celebration(false)
	game._show_message("目标收集达成！🌸+" + str(coin_reward), 2.0)
	game._refresh_ui()

static func _resolve_flip_clear(game):
	game.stage_status = game.STATUS_CLEARED
	var coin_reward = 20
	game.total_score += 200
	game.level_score = game.total_score
	game._patch_progress_state({
		"flip_result": game.total_score,
		"coins_delta": coin_reward
	})
	AudioManager.play_win()
	game._record_special_completion()
	game._play_stage_clear_celebration(false)
	game._show_message("全部配对完成！🌸+" + str(coin_reward), 2.0)
	game._refresh_ui()

static func _on_flip_back_timeout(game):
	MEMORY_FLIP.unflip_misses(game)

static func _fail_tray_full(game):
	game.stage_status = game.STATUS_FAILED
	AudioManager.play_shuffle()
	game._show_message("槽位满了！再试一次", 1.8)
	game._refresh_ui()

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
