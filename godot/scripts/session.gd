extends Reference

const PAGE_ROUTER = preload("res://scripts/page_router.gd")
const TILE_MATCH = preload("res://scripts/tile_match.gd")
const MEMORY_FLIP = preload("res://scripts/memory_flip.gd")
const ECONOMY = preload("res://scripts/economy.gd")

# Campaign session lifecycle: level reset, post-move resolution (win/lose/
# reshuffle/gravity), the clock, pause/resume, revival and achievements.
# Special-mode entry/exit and settlement live in special_session.gd.

static func _reset_level_session(game, level, reset_total = false):
	if game.revive_button:
		game.revive_button.visible = false
	ECONOMY.collect_level_icons(game)
	if game.collect_row:
		game.collect_row.visible = game.special_mode == "collect"
	if game.flip_layer:
		MEMORY_FLIP.clear_view(game)
		game.flip_layer.visible = false
	if game.board_grid:
		game.board_grid.visible = true
	if game.special_mode == "collect":
		game.collect_targets = {}
		game.collect_progress = {}
		for target in game.special_level.get("targets", []):
			game.collect_targets[int(target)] = int(game.special_level.get("target_pairs", 3))
			game.collect_progress[int(target)] = 0
		ECONOMY.update_collect_labels(game)
	if game.special_mode == "flip":
		_reset_special_board_state(game, int(level.get("time_limit", 180)))
		if game.flip_layer:
			game.flip_layer.visible = true
			game.board_grid.visible = false
		MEMORY_FLIP.new_round(game)
		if game.second_timer:
			game.second_timer.stop()
			game.second_timer.start()
		return
	if game.special_mode == "tray":
		_reset_special_board_state(game, int(level.get("time_limit", 240)))
		if game.tray_layer:
			game.tray_layer.visible = true
			game.board_grid.visible = false
		game.tray_state = TILE_MATCH.generate(level)
		TILE_MATCH.build_view(game)
		if game.second_timer:
			game.second_timer.stop()
			game.second_timer.start()
		return
	if game.tray_layer:
		TILE_MATCH.clear_view(game)
		game.tray_layer.visible = false
	if game.flip_layer:
		MEMORY_FLIP.clear_view(game)
		game.flip_layer.visible = false
	if game.board_grid:
		game.board_grid.visible = true
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
	game.combo_milestones_hit = []
	game.perfect_misses = 0
	game.husband_called = false
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

# Shared wipe for tray/flip sessions: the campaign board is torn down and the
# round resources (score/time/counters) restart from the level defaults.
static func _reset_special_board_state(game, time_limit):
	game.board = []
	game.board_armor = []
	game.board_lower = []
	game.board_chain = []
	game._fog_layers = 0
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.moves = 0
	game.level_score = 0
	game.total_score = 0
	game.time_left = time_limit


# Perfect mode bookkeeping: a wrong pair costs one of the 3 misses; the
# third one fails the stage. Other modes never call this (guarded in input).
static func _register_perfect_miss(game):
	if game.special_mode != "perfect" or game.stage_status != game.STATUS_PLAYING:
		return
	var miss_limit = int(game.special_level.get("miss_limit", 3))
	game.perfect_misses += 1
	if game.perfect_misses >= miss_limit:
		_fail_stage(game, "失误达到 %d 次！得分 %d\n点击「重开」再战，或「暂停」后返回玩法" % [miss_limit, game.total_score])
	else:
		game._show_message("失误 %d/%d，要零失误才完美哦" % [game.perfect_misses, miss_limit], 1.2)


static func _fail_stage(game, panel_text):
	game.stage_status = game.STATUS_FAILED
	AudioManager.play_fail()
	game.VOICE_LINES.play(game, "fail")
	game._reset_combo()
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.second_timer.stop()
	game.stage_panel_label.text = panel_text
	game.stage_panel_label.visible = true
	game._refresh_ui()
	game._refresh_board_visuals()


static func _fail_moves_exhausted(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	_fail_stage(game, "步数用完了！还剩 %d 对没消除\n点击「重开」再战，或「暂停」后返回玩法" % int(game._remaining_tiles_count() / 2))
	game._show_message("步数耗尽，挑战失败", 1.8)

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
		_settle_campaign_clear(game)
		return

	if game._find_any_hint(game.board).empty():
		game._reshuffle_board(game.board)
		game._show_message("无解，已自动重排", 1.0)
		game._refresh_board_visuals()


# Campaign clear settle: time bonus, blossom payout, star rating (by the
# remaining-time ratio), next-level unlock and the win flow for both the
# final and intermediate levels.
static func _settle_campaign_clear(game):
	game._mission_level_cleared()
	var time_bonus_multiplier = float(game._current_level().get("time_bonus_multiplier", 2.0))
	var time_bonus = int(round(float(game.time_left) * time_bonus_multiplier))
	game.total_score += time_bonus
	game.level_score += time_bonus

	var coin_reward = ECONOMY.award_level_clear(game, game._current_level())
	var stars = 1
	var level_time = int(game._current_level().get("time_limit", 0))
	if level_time > 0:
		var ratio = float(game.time_left) / float(level_time)
		stars = 3 if ratio >= 0.5 else (2 if ratio >= 0.25 else 1)
	var progress_patch := {
		"score_candidate": game.total_score,
		"combo_candidate": game.combo,
		"coins_delta": coin_reward,
		"stars": {"level_index": game.level_index, "stars": stars}
	}
	var is_final = game.level_index >= game.campaign_levels.size() - 1
	if is_final:
		progress_patch["current_level_index"] = 0
		progress_patch["highest_unlocked_level_index"] = max(0, game.campaign_levels.size() - 1)
	else:
		progress_patch["current_level_index"] = game.level_index + 1
		progress_patch["highest_unlocked_level_index"] = game.level_index + 1
	game._patch_progress_state(progress_patch)

	game._reset_combo()
	game.second_timer.stop()
	game.stage_panel_label.visible = false

	if is_final:
		game.stage_status = game.STATUS_COMPLETED
		game.stage_panel_label.text = "全部通关！Sophia 太棒啦 " + "  ⭐".repeat(stars) + "\n点击「再来一轮」"
		game.stage_panel_label.visible = true
		AudioManager.play_win()
		game._show_message("全通关！时间奖励 +" + str(time_bonus), 2.5)
		game._play_stage_clear_celebration(true)
	else:
		game.stage_status = game.STATUS_CLEARED
		game.pending_level_index = game.level_index + 1
		game.stage_panel_label.text = "过关啦～准备进入下一关  " + "⭐".repeat(stars)
		game.stage_panel_label.visible = true
		AudioManager.play_win()
		game._show_message("第" + str(game._current_level().get("id", game.level_index + 1)) + "关过关啦！奖励 +" + str(time_bonus) + " · 🌸+" + str(coin_reward), 1.2)
		game._play_stage_clear_celebration(false)
		game.level_advance_timer.stop()
		game.level_advance_timer.wait_time = float(game.tuning.get("level_advance_ms", 1200)) / 1000.0
		game.level_advance_timer.start()

	game._show_combo_burst(game.CHEERS.clear_cheer(game))
	game.VOICE_LINES.play(game, "clear")
	game._refresh_ui()
	game._refresh_board_visuals()
	game._check_achievements_on_clear()

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

	# Time attack / fever: matches refund time and a hot streak ignites
	# fever mode (fever runs it permanently from combo 2).
	if game.special_mode == "time_attack" or game.special_mode == "fever":
		var attack_cfg = game.game_mode_configs.get(game.special_mode, {})
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
	game._mission_pair_cleared()
	game._mission_combo_reached(game.combo)
	var cheer = game._combo_cheer(gain)
	if cheer != "":
		game._show_combo_burst(cheer)

	return {
		"combo": game.combo,
		"gain": gain
	}


static func _on_time_up(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	if game.special_mode != "":
		# Special sessions have no revival: _revive resolves campaign fields.
		_fail_stage(game, "挑战失败！得分 " + str(game.total_score) + "\n点击「重开」再战，或「暂停」后返回关卡")
		return
	game._patch_progress_state({
		"current_level_index": game.level_index,
		"score_candidate": game.total_score,
		"combo_candidate": game.combo
	})
	_fail_stage(game, "差一点点！点击\"重开\"再试，或复活续战")
	_offer_revive(game, 30)
	game._show_message("时间到！差一点点而已", 1.8)


# Husband rescue: the product gimmick. When time runs short the floating
# button appears; calling the husband once per round grants +15 seconds and
# a free pair hint (without charging the hint counter), wrapped in a
# doting one-liner.
static func call_husband(game):
	if game.husband_called or game.stage_status != game.STATUS_PLAYING:
		return
	game.husband_called = true
	game.time_left = min(999, game.time_left + 15)
	AudioManager.play_hint()
	var hint = game._find_any_hint(game.board)
	if hint.empty():
		game._reshuffle_board(game.board)
		hint = game._find_any_hint(game.board)
	game.GAME_INPUT.reveal_hint_pair(game, hint)
	game._show_message(game.CHEERS.husband_line(game) + " · ⏰+15 秒", 2.2)


static func _consume_time_cost(game, seconds):
	# Clockless modes (endless/zen/moves/race) carry time_limit 0, so there is
	# nothing to drain; guard against a divide of the clock into negatives.
	if int(game._current_level().get("time_limit", 90)) <= 0:
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


static func _offer_revive(game, cost):
	# Blossom revival keeps the board as-is: only the resources return.
	game.revive_cost = cost
	if game.revive_button:
		game.revive_button.visible = coins_can_afford(game, cost)

static func coins_can_afford(game, cost):
	return int(game.progression_state.get("coins", 0)) >= cost

static func _revive(game):
	var cost = int(game.revive_cost)
	if game.stage_status != game.STATUS_FAILED or not coins_can_afford(game, cost):
		if game.revive_button:
			game.revive_button.visible = false
		return
	game._patch_progress_state({"coins_delta": -cost})
	if game.time_left <= 0:
		game.time_left = int(max(30.0, float(game._current_level().get("time_limit", 60)) * 0.25))
	if game.moves_left > 0 or game._current_level().has("move_budget"):
		game.moves_left = max(game.moves_left, 5)
	game.stage_status = game.STATUS_PLAYING
	if game.revive_button:
		game.revive_button.visible = false
	game.stage_panel_label.visible = false
	game._start_second_timer()
	game._show_message("复活成功！继续加油", 1.4)
	game._refresh_ui()
	game._refresh_board_visuals()

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


static func _unlock_achievements(game, ids):
	var new_unlocks = []
	for achievement_id in ids:
		if not game.PROGRESSION_SCRIPT.has_achievement(game.progression_state, achievement_id):
			game.progression_state = game.PROGRESSION_SCRIPT.unlock_achievement(game.progression_state, achievement_id)
			new_unlocks.append(achievement_id)
	_announce_achievements(game, new_unlocks)


static func _announce_achievements(game, ids):
	if ids.size() <= 0:
		return
	game.VOICE_LINES.play(game, "achievement")
	game._save_progress_state()
	for achievement_id in ids:
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
	_announce_achievements(game, new_unlocks)

