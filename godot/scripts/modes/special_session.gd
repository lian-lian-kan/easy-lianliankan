extends Reference

# Special-mode session domain: entering/leaving the 19 special modes, their
# settlement (score records, achievements, blossom payouts) and their unique
# failure paths. Campaign session flow stays in session.gd. Functions the
# modes share with the campaign (clock, combos, revival) remain there.

const ECONOMY = preload("res://scripts/pages/economy.gd")
const SPECIAL_MODES_SCRIPT = preload("res://scripts/modes/special_modes.gd")
const TILE_MATCH = preload("res://scripts/modes/tile_match.gd")
const MEMORY_FLIP = preload("res://scripts/modes/memory_flip.gd")
const EVENTS = preload("res://scripts/content/events_calendar.gd")


# Shared tail of the per-mode win settlements: record, celebration, banner.
# Modes dealt by build_classic_style_level (one row in DEFAULT_CONFIGS, no bespoke builder).
const CLASSIC_STYLE_MODES = ["zen", "hell", "moves", "race", "stack", "gravity", "fog", "chain", "fever", "perfect", "target", "shift", "slide", "defense", "duel", "sum10", "drag"]

static func _finish_special_win(game, message):
	if game._is_duel_mode():
		var s1 = int(game.duel_scores[0])
		var s2 = int(game.duel_scores[1])
		var verdict = "平局，握手言和～" if s1 == s2 else ("🏆 玩家1 获胜！" if s1 > s2 else "🏆 玩家2 获胜！")
		message = "%s %d:%d %s" % [verdict, s1, s2, message]
	game.stage_status = game.STATUS_CLEARED
	game.audio.play_win()
	game.VOICE_LINES.play(game, "clear")
	game._record_special_completion()
	game._play_stage_clear_celebration(false)
	game._show_combo_burst(game.CHEERS.clear_cheer(game))
	game._show_message(message, 2.0)
	game._refresh_ui()

static func _start_special_mode(game, mode_id):
	var config = game.game_mode_configs.get(mode_id, {})
	if not game.SPECIAL_MODES_SCRIPT.is_mode_unlocked(mode_id, config, int(game.progression_state.get("highest_unlocked_level_index", 0))):
		game._show_message(game.SPECIAL_MODES_SCRIPT.unlock_requirement_text(mode_id, config), 1.8)
		return
	# Build the virtual level first; only touch session state once it exists.
	var level = _build_special_level(game, mode_id, config)
	game.special_mode = mode_id
	game.endless_round = 1
	game.special_level = level
	game.tree_height = int(level.get("tree_height", 1))
	# A fresh climb starts with no buffs (roguelike offers arrive per layer).
	game.tree_buffs = {}
	game.tree_pending_buffs = []
	game._reset_level_session(level, true)
	print("[Game] special mode started: " + mode_id)
	if mode_id == "memory":
		game._show_message("盲盒模式！记住 %d 秒预览，然后凭记忆配对" % int(ceil(float(level.get("memory_preview", 5.0)))), 2.0)
	else:
		game._show_message(game.SPECIAL_MODES_SCRIPT.intro_text(mode_id), 1.8)

# One explicit branch per virtual-level builder — signatures differ (tiers,
# seeds, unlock floors), so a table would hide more than it saves. Unknown
# modes fall back to endless.
static func _build_special_level(game, mode_id, config):
	if mode_id == "daily":
		var today = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
		seed(game.SPECIAL_MODES_SCRIPT.seed_for_day(today))
		return game.SPECIAL_MODES_SCRIPT.build_daily_level(today)
	if mode_id == "time_attack":
		return game.SPECIAL_MODES_SCRIPT.build_time_attack_level(config)
	if mode_id == "memory":
		var tier = game.SPECIAL_MODES_SCRIPT.memory_tier(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
		return game.SPECIAL_MODES_SCRIPT.build_memory_level(config, tier)
	if mode_id == "frost":
		var tier = game.SPECIAL_MODES_SCRIPT.frost_tier(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
		return game.SPECIAL_MODES_SCRIPT.build_frost_level(config, tier)
	if mode_id == "tray":
		return game.SPECIAL_MODES_SCRIPT.build_tray_level(config)
	if mode_id == "collect":
		return game.SPECIAL_MODES_SCRIPT.build_collect_level(config)
	if mode_id == "flip":
		return game.SPECIAL_MODES_SCRIPT.build_memory_flip_level(config)
	if mode_id == "rock":
		return game.SPECIAL_MODES_SCRIPT.build_rock_level(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
	if mode_id == "defuse":
		return game.SPECIAL_MODES_SCRIPT.build_defuse_level(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
	if mode_id == "tree":
		return game.SPECIAL_MODES_SCRIPT.build_tree_level(config, int(game.progression_state.get("tree_best_height", 0)) + 1)
	if mode_id == "edu":
		return game.SPECIAL_MODES_SCRIPT.build_edu_level(config, int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1)
	if mode_id == "custom":
		# 关卡工坊「试玩」：the level was assembled by the editor beforehand.
		return game.custom_level
	if mode_id in CLASSIC_STYLE_MODES:
		return game.SPECIAL_MODES_SCRIPT.build_classic_style_level(config, mode_id)
	return game.SPECIAL_MODES_SCRIPT.build_endless_level(config, 1)

static func _exit_special_mode(game):
	if game.tree_buff_offer_open:
		game.tree_buff_offer_open = false
		game.UI_PANELS.hide_tree_buff_panel(game)
	game._start_level(game.level_index, false)
	game._show_message("已返回关卡模式", 1.0)

static func _resolve_special_clear(game):
	game._mission_level_cleared()
	# 步数挑战: unused moves convert into bonus score.
	if game.special_mode == "moves":
		var move_bonus = game.moves_left * 20
		game.total_score += move_bonus
		game.level_score += move_bonus
	_finish_special_clear(game, _special_time_bonus(game))

# 剩余时间按关卡倍率折成奖励分。
static func _special_time_bonus(game) -> int:
	var time_bonus_multiplier = float(game._current_level().get("time_bonus_multiplier", 2.0))
	return int(round(float(game.time_left) * time_bonus_multiplier))

# 结算发放：奖励入账、停表收场，再按模式走各自的完赛分支。
static func _finish_special_clear(game, time_bonus):
	game.total_score += time_bonus
	game.level_score += time_bonus

	game._reset_combo()
	game.second_timer.stop()
	if game.race_timer:
		game.race_timer.stop()
	game.stage_panel_label.visible = false
	game.audio.play_win()

	if game.special_mode == "endless":
		_advance_endless_round(game, time_bonus)
	elif game.special_mode == "tree":
		_advance_tree_layer(game, time_bonus)
	elif game.special_mode == "custom":
		_settle_custom_win(game)
	else:
		game._record_special_completion()
		game.stage_status = game.STATUS_COMPLETED
		game._play_stage_clear_celebration(true)

# 无尽模式一轮完成：记成绩、发徽章、推进到更大的一轮并踢推进计时器。
static func _advance_endless_round(game, time_bonus):
	game._patch_progress_state({"endless_result": {"round": game.endless_round, "score": game.total_score}})
	if game.endless_round >= 5:
		game._unlock_achievements(["endless_round_5"])
	var finished_round = game.endless_round
	game.endless_round += 1
	game.special_level = game.SPECIAL_MODES_SCRIPT.build_endless_level(game.game_mode_configs.get("endless", {}), game.endless_round)
	game.stage_status = game.STATUS_CLEARED
	game._play_stage_clear_celebration(false)
	game._show_message("第" + str(finished_round) + "轮完成～奖励 +" + str(time_bonus) + "，下一轮更大", 1.4)
	# Kick the advance timer so the next (bigger) round actually starts.
	game.level_advance_timer.stop()
	game.level_advance_timer.wait_time = float(game.tuning.get("level_advance_ms", 1200)) / 1000.0
	game.level_advance_timer.start()

# UGC 试玩结算：a small flat thank-you, no records/missions/leaderboard.
static func _settle_custom_win(game):
	game._patch_progress_state({"coins_delta": 10})
	game.stage_status = game.STATUS_COMPLETED
	game._play_stage_clear_celebration(true)
	game._show_message("自定义关卡通关！作者之手一定能难住朋友 · 🌸+10", 2.0)

	game._refresh_ui()
	game._refresh_board_visuals()

# Tree climb: bank the cleared layer (best height, one-time milestone payout),
# build the next layer and kick the advance timer, endless-style.
static func _advance_tree_layer(game, time_bonus):
	var cleared_height = int(game.special_level.get("tree_height", game.tree_height))
	var claimed = game.progression_state.get("tree_milestones", [])
	var patch = {"tree_result": cleared_height}
	var clear_message = "第" + str(cleared_height) + "层登顶！奖励 +" + str(time_bonus)
	var reward = EVENTS.apply_earn(OS.get_date(), game.SPECIAL_MODES_SCRIPT.TREE_LADDER.milestone_reward(cleared_height))
	if reward > 0 and not claimed.has(cleared_height):
		var updated_claimed = claimed.duplicate()
		updated_claimed.append(cleared_height)
		patch["tree_milestones"] = updated_claimed
		patch["coins_delta"] = reward
		clear_message += "\n🌳 里程碑达成！🌸+" + str(reward)
	game._patch_progress_state(patch)
	game.tree_height = cleared_height + 1
	game.special_level = game.SPECIAL_MODES_SCRIPT.build_tree_level(game.game_mode_configs.get("tree", {}), game.tree_height)
	game.stage_status = game.STATUS_CLEARED
	game._play_stage_clear_celebration(false)
	game._show_message(clear_message, 1.6)
	# Roguelike interlude: offer three buffs before the next layer starts;
	# the offer's resolve kicks the advance timer.
	_offer_tree_buffs(game)

# Roll the three-choice buff offer and surface it; the clock stays stopped
# (the stage is CLEARED) until the player picks or skips.
static func _offer_tree_buffs(game):
	game.tree_pending_buffs = game.TREE_BUFFS.roll_offer()
	game.tree_buff_offer_open = true
	game.UI_PANELS.offer_tree_buffs(game)

# Buff picked (or skipped with ""): apply it to the pending layer, then let
# the advance timer start the next layer.
static func _resolve_tree_buff_pick(game, buff_id):
	game.tree_buff_offer_open = false
	game.UI_PANELS.hide_tree_buff_panel(game)
	game.tree_buffs = {}
	if str(buff_id) != "" and not game.TREE_BUFFS.buff_by_id(buff_id).empty():
		game.tree_buffs = {str(buff_id): true}
		game.TREE_BUFFS.apply_score_mult(game.special_level, game.tree_buffs)
		var buff = game.TREE_BUFFS.buff_by_id(buff_id)
		game._show_message("%s %s：%s" % [str(buff["icon"]), str(buff["name"]), str(buff["desc"])], 1.6)
	game.level_advance_timer.stop()
	game.level_advance_timer.wait_time = float(game.tuning.get("level_advance_ms", 1200)) / 1000.0
	game.level_advance_timer.start()

static func _record_special_completion(game):
	game._mission_special_done()
	var today = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	var record = game.SPECIAL_MODES_SCRIPT.record_modes().get(game.special_mode, {})
	if not record.empty():
		game._patch_progress_state({record["patch_key"]: game.total_score})
		var achievements = record["achievements"].duplicate()
		achievements.append_array(game.SPECIAL_MODES_SCRIPT.bonus_achievements(game.special_mode, {
			"frost_uses": game.frost_uses,
			"moves_left": game.moves_left,
			"move_budget": int(game._current_level().get("move_budget", 0)),
		}))
		game._unlock_achievements(achievements)
		game.stage_panel_label.text = record["label"] + "完成～得分 " + str(game.total_score) + " · 最佳 " + str(int(game.progression_state.get(record["best_key"], 0)))
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
		game.stage_panel_label.text = "今日挑战完成，辛苦啦！得分 " + str(game.total_score) + " · 连胜 " + str(int(daily.get("streak", 0))) + " 天\n明天还有新的棋盘，点击「重开」可再玩今日棋盘"
		if int(daily.get("streak", 0)) >= 7:
			game._unlock_achievements(["daily_streak_7"])
	elif game.special_mode == "time_attack":
		game._patch_progress_state({"time_attack_result": game.total_score})
		game.stage_panel_label.text = "限时挑战结束～得分 " + str(game.total_score) + " · 最佳 " + str(int(game.progression_state.get("time_attack_best_score", 0)))
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
	var coin_reward = EVENTS.apply_earn(OS.get_date(), 20)
	game.total_score = TILE_MATCH.score_for(game.tray_state)
	game.level_score = game.total_score
	game._patch_progress_state({
		"tray_result": game.total_score,
		"coins_delta": coin_reward
	})
	_finish_special_win(game, "叠叠消通关！🌸+" + str(coin_reward))

static func _resolve_collect_clear(game):
	var coin_reward = EVENTS.apply_earn(OS.get_date(), 20)
	game._patch_progress_state({
		"collect_result": game.total_score,
		"coins_delta": coin_reward
	})
	_finish_special_win(game, "目标收集达成！🌸+" + str(coin_reward))

static func _resolve_flip_clear(game):
	var coin_reward = EVENTS.apply_earn(OS.get_date(), 20)
	game.total_score += 200
	game.level_score = game.total_score
	game._patch_progress_state({
		"flip_result": game.total_score,
		"coins_delta": coin_reward
	})
	_finish_special_win(game, "全部配对完成！🌸+" + str(coin_reward))

static func _on_flip_back_timeout(game):
	MEMORY_FLIP.unflip_misses(game)

static func _fail_tray_full(game):
	game.stage_status = game.STATUS_FAILED
	game.audio.play_shuffle()
	game._show_message("槽位满了！再试一次", 1.8)
	game._refresh_ui()

static func _fail_race_lost(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	if game.race_timer:
		game.race_timer.stop()
	game.SESSION._fail_stage(game, "对手先完成了！你消除了 %d/%d 对\n点击「重开」再战" % [game.race_total_pairs - int(game._remaining_tiles_count() / 2), game.race_total_pairs])
	game._show_message("惜败！再快一点点", 1.8)
