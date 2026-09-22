extends Reference

# 结算与计分域（session 的内容分册）：过关结算（时间奖励/樱花发放/星级/
# 解锁推进/胜负演出）、连击计分（窗口/倍率/限时返时）与成就发放。
# 会话生命周期（重置/走子裁决/暂停/复活）留在 session.gd；经薄壳互调。

const ECONOMY = preload("res://scripts/pages/economy.gd")

# Campaign clear settle: time bonus, blossom payout, star rating (by the
# remaining-time ratio), next-level unlock and the win flow for both the
# final and intermediate levels.
static func _settle_campaign_clear(game):
	game._mission_level_cleared()
	var reward = _settle_campaign_rewards(game)
	game._reset_combo()
	game.second_timer.stop()
	game.stage_panel_label.visible = false
	if reward["is_final"]:
		_finish_final_clear(game, reward)
	else:
		_finish_intermediate_clear(game, reward)
	game._show_combo_burst(game.CHEERS.clear_cheer(game))
	game.VOICE_LINES.play(game, "clear")
	game._refresh_ui()
	game._refresh_board_visuals()
	game._check_achievements_on_clear()


# Time bonus, coin reward, star rating and the progression push; returns
# the settlement context for the two presentation paths.
static func _settle_campaign_rewards(game):
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
	return {"time_bonus": time_bonus, "coin_reward": coin_reward, "stars": stars, "is_final": is_final}


# Campaign finished: completed status + full celebration.
static func _finish_final_clear(game, reward):
	game.stage_status = game.STATUS_COMPLETED
	game.stage_panel_label.text = "全部通关！Sophia 太棒啦 " + "  ⭐".repeat(reward["stars"]) + "\n点击「再来一轮」"
	game.stage_panel_label.visible = true
	game.audio.play_win()
	game._show_message("全通关！时间奖励 +" + str(reward["time_bonus"]), 2.5)
	game._play_stage_clear_celebration(true)


# Intermediate clear: advance pending index and schedule the next level.
static func _finish_intermediate_clear(game, reward):
	game.stage_status = game.STATUS_CLEARED
	game.pending_level_index = game.level_index + 1
	game.stage_panel_label.text = "过关啦～准备进入下一关  " + "⭐".repeat(reward["stars"])
	game.stage_panel_label.visible = true
	game.audio.play_win()
	game._show_message("第" + str(game._current_level().get("id", game.level_index + 1)) + "关过关啦！奖励 +" + str(reward["time_bonus"]) + " · 🌸+" + str(reward["coin_reward"]), 1.2)
	game._play_stage_clear_celebration(false)
	game.level_advance_timer.stop()
	game.level_advance_timer.wait_time = float(game.tuning.get("level_advance_ms", 1200)) / 1000.0
	game.level_advance_timer.start()

static func _apply_combo_gain(game, base_score):
	var now_ms = OS.get_ticks_msec()
	# 攀登树余烬连击：本层增益拉长连击窗口（无增益时恒为 1.0）。
	var combo_window = int(float(game.tuning.get("combo_window_ms", 2600)) * game.TREE_BUFFS.combo_window_mult(game.get("tree_buffs")))
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
		_refund_attack_time(game, attack_cfg)

	_register_combo_score(game, gain)
	var cheer = game._combo_cheer(gain)
	if cheer != "":
		game._show_combo_burst(cheer)

	return {
		"combo": game.combo,
		"gain": gain
	}


# Attack modes refund clock per match; hot combos add the bonus refund.
static func _refund_attack_time(game, attack_cfg):
	var refund = int(attack_cfg.get("time_bonus_per_match", 3))
	if game.combo >= int(attack_cfg.get("fever_mode_threshold", 5)):
		refund += int(attack_cfg.get("combo_time_bonus", 1))
	game.time_left = min(999, game.time_left + refund)


# Book the gain everywhere it matters: session totals, cloud-save candidates,
# and the weekly-mission counters that watch score and combo.
static func _register_combo_score(game, gain):
	game.total_score += gain
	game.level_score += gain
	game._patch_progress_state({
		"score_candidate": game.total_score,
		"combo_candidate": game.combo
	})
	game._mission_pair_cleared()
	game._mission_combo_reached(game.combo)


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
