extends Reference

const PAGE_ROUTER = preload("res://scripts/pages/page_router.gd")
const TILE_MATCH = preload("res://scripts/modes/tile_match.gd")
const REVIVE = preload("res://scripts/session/revive.gd")
const MEMORY_FLIP = preload("res://scripts/modes/memory_flip.gd")
const ECONOMY = preload("res://scripts/pages/economy.gd")
const SESSION_SETTLE = preload("res://scripts/session/session_settle.gd")
const INTERACTIONS = preload("res://scripts/interactions/interaction_manager.gd")

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
	_reset_collect_targets(game)
	if _reset_flip_session(game, level):
		return
	if _reset_tray_session(game, level):
		return
	_reset_board_session(game, level)
	_reset_session_counters(game, level)
	_reset_session_meta(game, level)
	_reset_session_ui(game, reset_total)
	game._refresh_ui()
	game._refresh_board_visuals()
	if game._is_memory_mode():
		game._play_level_intro_animation(level)
		game._start_memory_preview()
	else:
		game._start_second_timer()
		game._play_level_intro_animation(level)


# Collect targets init (no early return: the general board reset follows).
static func _reset_collect_targets(game):
	if game.special_mode == "collect":
		game.collect_targets = {}
		game.collect_progress = {}
		for target in game.special_level.get("targets", []):
			game.collect_targets[int(target)] = int(game.special_level.get("target_pairs", 3))
			game.collect_progress[int(target)] = 0
		ECONOMY.update_collect_labels(game)


static func _reset_flip_session(game, level) -> bool:
	if game.special_mode != "flip":
		return false
	_reset_special_board_state(game, int(level.get("time_limit", 180)))
	if game.flip_layer:
		game.flip_layer.visible = true
		game.board_grid.visible = false
	MEMORY_FLIP.new_round(game)
	if game.second_timer:
		game.second_timer.stop()
		game.second_timer.start()
	return true


static func _reset_tray_session(game, level) -> bool:
	if game.special_mode != "tray":
		return false
	_reset_special_board_state(game, int(level.get("time_limit", 240)))
	if game.tray_layer:
		game.tray_layer.visible = true
		game.board_grid.visible = false
	game.tray_state = TILE_MATCH.generate(level)
	TILE_MATCH.build_view(game)
	if game.second_timer:
		game.second_timer.stop()
		game.second_timer.start()
	return true


# Fresh board + mechanism layers for the campaign board.
static func _reset_board_session(game, level):
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
	game.board_bomb = {}
	_init_mode_boards(game, level)
	game.target_pair = [Vector2(-1, -1), Vector2(-1, -1)]
	game.shift_countdown = int(level.get("shift_interval", 0))
	game.defense_distance = int(level.get("defense_start", 0))
	game.defense_countdown = int(level.get("defense_step", 0))
	game.duel_scores = [0, 0]
	game.duel_current = 0
	game._fog_layers = 0
	if game._is_target_mode():
		_pick_target_pair(game)
	_reset_interaction_state(game)

	for child in game.effect_layer.get_children():
		child.queue_free()


# Board-shape mechanics for special sessions: obstacles, face transforms and
# stacked layers. Modes are mutually exclusive (special_mode is one value),
# so each block only ever fires for its own session.
static func _init_mode_boards(game, level):
	if game._is_rock_mode():
		game.BOARD_MECHANICS.build_rocks(game, level)
	if game._is_defuse_mode():
		game.BOARD_MECHANICS.build_bombs(game, level)
	if game._is_sum_mode():
		game.BOARD_ENGINE.apply_sum10_faces(game.board)
	if game._is_edu_mode():
		game.edu_faces = game.EDU.faces_for(str(level.get("subject", "hanzi")))
		game.BOARD_ENGINE.apply_edu_faces(game.board)
	if game._is_stack_mode():
		game._build_stack_layers(float(level.get("stack_ratio", 0.25)))
	if game._is_chain_mode():
		game._build_chain_locks(float(level.get("chain_ratio", 0.22)))


# Interaction scratch state: nothing armed, no stale highlights or paths.
# The contract lives in the interactions module; session only forwards.
static func _reset_interaction_state(game):
	INTERACTIONS.reset(game)



# Session counters: moves/score/clock and the race bookkeeping.
static func _reset_session_counters(game, level):
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



# Achievement tracking, power-ups and memory-mode state.
static func _reset_session_meta(game, level):
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



# 指定连消：从当前盘面挑一对可连消的格子作为金光目标。
static func _pick_target_pair(game):
	var hint = game._find_any_hint(game.board)
	if hint.empty():
		game.target_pair = [Vector2(-1, -1), Vector2(-1, -1)]
		return
	game.target_pair = [hint["a"], hint["b"]]
	game._refresh_board_visuals()


# Final UI sync of the level reset.
static func _reset_session_ui(game, reset_total):
	if reset_total:
		game.total_score = 0

	game._reset_combo()
	game._hide_message()
	game.pending_level_index = -1
	game.stage_panel_label.visible = false

	game._render_board()
	game._sync_level_select_selection()



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
	game.audio.play_fail()
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
	if game._is_special_session():
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


static func _on_time_up(game):
	if game.stage_status != game.STATUS_PLAYING:
		return
	if game._is_special_session():
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


# ── revive/rescue (delegated to session/revive.gd; shells keep the
# game.gd call sites stable) ──

static func call_husband(game):
	return REVIVE.call_husband(game)

static func _consume_time_cost(game, seconds):
	return REVIVE._consume_time_cost(game, seconds)

static func _consume_move(game):
	return REVIVE._consume_move(game)

static func _offer_revive(game, cost):
	return REVIVE._offer_revive(game, cost)

static func coins_can_afford(game, cost):
	return REVIVE.coins_can_afford(game, cost)

static func _revive(game):
	return REVIVE._revive(game)


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


# ── 结算与计分/成就发放（delegated to session_settle.gd; shells keep the
# game.gd call sites and the internal resolve path stable） ──

static func _settle_campaign_clear(game):
	return SESSION_SETTLE._settle_campaign_clear(game)

static func _settle_campaign_rewards(game):
	return SESSION_SETTLE._settle_campaign_rewards(game)

static func _apply_combo_gain(game, base_score):
	return SESSION_SETTLE._apply_combo_gain(game, base_score)

static func _unlock_achievements(game, ids):
	return SESSION_SETTLE._unlock_achievements(game, ids)

static func _check_achievements_on_clear(game):
	return SESSION_SETTLE._check_achievements_on_clear(game)
