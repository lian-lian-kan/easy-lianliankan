extends Reference

# Input domain: board tile gestures are delegated to the interactions module
# (scripts/interactions/) whose manager routes them through the multi-phase
# interaction registry. What stays here: the keyboard shortcut router, the
# in-game assistance actions (hint/auto/shuffle/reset/jump/pause) and thin
# delegation shells kept for existing callers (game.gd shells, test fakes).

const INTERACTIONS = preload("res://scripts/interactions/interaction_manager.gd")

# ── 棋盘手势（委托交互模块的多阶段管理器） ──

static func _on_tile_pressed(game, button):
	return INTERACTIONS.on_tile_pressed(game, button)

# 旧签名保留 row/col（测试假体直调）；路由只按格子坐标。
static func _on_memory_tile_pressed(game, point, _r, _c):
	return INTERACTIONS.memory_press(game, point)

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
		# 首页盖场时快捷键不穿底（用 get() 兼容无该成员的测试假体）。
		if game.get("start_screen_open"):
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
