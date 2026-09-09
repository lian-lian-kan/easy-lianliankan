extends SceneTree

# Panels probe: the five extracted UI panel builders still produce the
# expected structure when driven through the game wrappers.

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== panels_probe")
	var scene = load("res://scenes/Main.tscn")
	var game = scene.instance()
	root.add_child(game)
	for _i in range(6):
		yield(self, "idle_frame")
	game.progression_state["highest_unlocked_level_index"] = 14

	# main UI built by _ready through UI_HUD.build_main_ui
	check(game.board_grid != null and game.board_grid is GridContainer, "board grid built")
	check(game.board_center != null and game.effect_layer != null, "board center and effect layer built")
	check(game.message_label != null and game.title_label != null, "message and title labels built")
	check(game.status_chip_label != null and game.combo_burst_label != null and game.stage_panel_label != null, "status/combo/stage labels built")
	check(game.stats_flow_container is HFlowContainer, "stats row is an HFlowContainer")
	check(game.controls_flow_container != null and game.progression_flow_container != null, "controls and progression rows built")
	check(game.power_up_labels != null and game.power_up_labels.size() > 0, "power-up labels registered")

	# board_view: board built and the refresh pipeline is idempotent
	check(game.board.size() > 0 && game.cell_buttons.size() == game.board.size(), "board and cell buttons built")
	var found_value = 0
	var face_text = ""
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board[r][c]) > 0:
				found_value = int(game.board[r][c])
				face_text = game.cell_buttons[r][c].text
				break
		if found_value > 0:
			break
	game._refresh_board_visuals()
	check(found_value > 0 && face_text != "", "tile face renders its icon after refresh")
	game._update_tile_sizes()
	check(float(game.cell_buttons[0][0].rect_min_size.x) >= 30.0, "tile size clamped to readable minimum")

	# ui_hud layout: mobile-portrait compaction applied at logical 390x844
	game._update_layout_for_screen_size()
	check(float(game.margin_container.get_constant("margin_left")) <= 8.0, "compact margins applied on mobile portrait")
	check(game.hint_button != null && float(game.hint_button.rect_min_size.y) <= 40.0, "control buttons sized for mobile")
	check(game.stat_values.has("level_score") && !game.stat_values["level_score"]["card"].visible, "portrait hides non-essential stat cards")

	# game_input: tile press selects, second press deselects
	var press_cell = null
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board[r][c]) > 0:
				press_cell = Vector2(r, c)
				break
		if press_cell != null:
			break
	check(press_cell != null, "found a filled tile to press")
	game.stage_status = game.STATUS_PLAYING
	game.selected = Vector2(-1, -1)
	game._on_tile_pressed(game.cell_buttons[press_cell.x][press_cell.y])
	check(game.selected == press_cell, "first press selects the tile")
	game._on_tile_pressed(game.cell_buttons[press_cell.x][press_cell.y])
	check(game.selected == Vector2(-1, -1), "second press on the same tile deselects")
	check(int(game.moves) == 0, "select/deselect round trip does not consume a move")

	# game_input: keyboard P toggles pause through the input router
	var ev = InputEventKey.new()
	ev.scancode = KEY_P
	ev.pressed = true
	game._unhandled_input(ev)
	check(game.stage_status == game.STATUS_PAUSED, "keyboard P pauses the stage")
	var ev2 = InputEventKey.new()
	ev2.scancode = KEY_P
	ev2.pressed = true
	game._unhandled_input(ev2)
	check(game.stage_status == game.STATUS_PLAYING, "keyboard P again resumes the stage")

	# session: reset clears transient state and keeps the level playing
	game.bomb_pending = true
	game.moves = 99
	game.selected = Vector2(1, 1)
	game._reset_level_session(game._current_level(), false)
	check(!game.bomb_pending && game.selected == Vector2(-1, -1) && int(game.moves) == 0, "session reset clears transient state")
	check(game.stage_status == game.STATUS_PLAYING, "session reset returns to playing")

	# session: locked special mode rejected; unlocked zen starts; exit returns
	var saved_unlocked = int(game.progression_state["highest_unlocked_level_index"])
	game.progression_state["highest_unlocked_level_index"] = 0
	game._start_special_mode("hell")
	check(game.special_mode == "", "locked special mode is rejected")
	game.progression_state["highest_unlocked_level_index"] = saved_unlocked
	game._start_special_mode("zen")
	check(game.special_mode == "zen" && game.stage_status == game.STATUS_PLAYING, "zen session starts and plays")
	game._exit_special_mode()
	check(game.special_mode == "", "exit returns to campaign mode")

	# ui_panels/ui_hud: settings glue + modal sizing + status label
	game._populate_icon_set_options()
	check(game.icon_set_option.get_item_count() == int(game.icon_sets.size()), "icon set options populated for every set")
	game._on_icon_set_selected(0)
	check(int(game.icon_set_index) == 0, "icon set selection clamps and applies")
	game._update_modal_panel_sizes(game.get_viewport_rect().size, true)
	check(game.pause_panel.rect_min_size.x > 0, "modal sizes applied")
	check(game._status_label(game.STATUS_PLAYING) == "进行中", "status label maps playing")
	check(game._status_label(-999) == "未知", "status label unknown fallback")

	# session: memory helpers (pure key + schedule)
	check(game._memory_key(Vector2(3, 4)) == "3,4", "memory key maps coord to string")
	game.memory_lock = false
	game._memory_schedule_hide([Vector2(0, 0)], 30.0)
	check(game.memory_pending_hide.size() == 1 && bool(game.memory_lock), "memory schedule records pending coords and locks")

	# ui_hud: viewport flags classify phone portrait vs desktop landscape
	var vflags = game._viewport_flags(Vector2(390, 844))
	check(bool(vflags.is_mobile) && bool(vflags.is_portrait), "viewport flags classify phone portrait")
	check(!bool(game._viewport_flags(Vector2(1280, 720)).is_portrait), "viewport flags classify desktop landscape")
	check(bool(game._viewport_flags(Vector2(390, 430)).is_compact_height), "viewport flags flag compact heights")

	# game_config: reload pipeline keeps the campaign table intact
	var level_count_before = int(game.campaign_levels.size())
	game._load_config()
	check(int(game.campaign_levels.size()) == level_count_before && level_count_before > 0, "config reload keeps the campaign table")
	check(game.tuning != null && game.tuning.size() > 0, "tuning loaded with defaults")

	# progress_store: campaign patch persists bests and writes the save file
	game._patch_progress_state({"combo_candidate": 41})
	check(int(game.progression_state.get("best_combo", 0)) >= 41, "campaign combo candidate raises best combo")
	check(File.new().file_exists(game.PROGRESS_SAVE_PATH), "progress persisted to disk")

	# progress_store: special sessions persist their own records only
	var campaign_current_before = int(game.progression_state.get("current_level_index", 0))
	game.special_mode = "zen"
	game._patch_progress_state({"combo_candidate": 12, "current_level_index": 3})
	check(int(game.progression_state.get("best_combo", 0)) >= 41, "special session combo candidate never lowers campaign best")
	check(int(game.progression_state.get("current_level_index", 0)) == campaign_current_before, "special session never touches campaign progress")
	game._patch_progress_state({"zen_result": 99})
	check(int(game.progression_state.get("zen_best_score", 0)) >= 99, "special session persists its own record")

	# style helpers: glass panels, full-state button styles, recursive dialog styling
	game.special_mode = ""
	game._apply_glass_style(game.pause_panel, Color("fff0f6"), 0.9)
	check(game.pause_panel.has_stylebox_override("panel"), "glass style overrides the panel stylebox")
	var plain_button = Button.new()
	game.add_child(plain_button)
	game._apply_button_style(plain_button, Color("f06ba8"), Color("d6336c"))
	check(plain_button.has_stylebox_override("normal") && plain_button.has_stylebox_override("hover") && plain_button.has_stylebox_override("pressed") && plain_button.has_stylebox_override("disabled"), "button style overrides all states")
	game._style_dialog_buttons(game.pause_panel)
	var dialog_button = null
	var stack = [game.pause_panel]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is Button:
			dialog_button = node
			break
		for child in node.get_children():
			stack.append(child)
	check(dialog_button != null && dialog_button.get_color("font_color") == Color("ffffff"), "dialog buttons get the rose white font")
	plain_button.queue_free()

	# board_view: spawn/shuffle animations emit tweens
	var tweens_before = 0
	for child in game.get_children():
		if child is Tween:
			tweens_before += 1
	game._animate_board_spawn()
	var tweens_after = 0
	for child in game.get_children():
		if child is Tween:
			tweens_after += 1
	check(tweens_after > tweens_before, "board spawn animation emits tweens")
	game._animate_shuffle_wave()

	# game_input: hint highlights a pair; auto eliminates it
	var hints_before = int(game.level_hints_used)
	game._on_hint_pressed()
	check(int(game.level_hints_used) == hints_before + 1 && game.hint_tiles.size() == 2, "hint highlights a pair")
	var tiles_before = int(game._remaining_tiles_count())
	var autos_before = int(game.level_auto_used)
	game._on_auto_pressed()
	check(int(game.level_auto_used) == autos_before + 1, "auto press registers usage")
	check(int(game._remaining_tiles_count()) == tiles_before - 2, "auto press eliminates the hinted pair")

	# session: resource drain, stage pause/resume, level start
	game.time_left = 50
	game._consume_time_cost(1)
	check(int(game.time_left) == 49, "time cost drains one second in campaign")
	game.special_mode = "zen"
	game.special_level = {"time_limit": 0}
	game._consume_time_cost(1)
	check(int(game.time_left) == 49, "clockless zen ignores time cost")
	game.special_mode = ""
	var moves_left_before = int(game.moves_left)
	game._consume_move()
	check(int(game.moves_left) == moves_left_before, "consume move is a no-op outside moves mode")
	game._pause_stage()
	check(game.stage_status == game.STATUS_PAUSED, "pause stage enters paused")
	game._resume_stage()
	check(game.stage_status == game.STATUS_PLAYING, "resume stage returns to playing")
	game._start_level(2, true)
	check(int(game.level_index) == 2 && game.stage_status == game.STATUS_PLAYING, "start level opens campaign level 3")
	game._unlock_achievements(["first_clear"])
	check(game.PROGRESSION_SCRIPT.has_achievement(game.progression_state, "first_clear"), "unlock achievements persists to progression")

	# board_view: de-coroutined tile animations return the tile to rest
	var anim_cell = null
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board[r][c]) > 0:
				anim_cell = Vector2(r, c)
				break
		if anim_cell != null:
			break
	var rest_button = game.cell_buttons[anim_cell.x][anim_cell.y]
	var before_panels = []
	for child in game.effect_layer.get_children():
		if child is Panel:
			before_panels.append(child)
	game._animate_select(anim_cell)
	yield(self.create_timer(0.25), "timeout")
	var new_panels = 0
	for child in game.effect_layer.get_children():
		if child is Panel and before_panels.find(child) == -1:
			new_panels += 1
	check(new_panels == 1, "select spawns exactly one new ring panel")
	yield(self.create_timer(0.35), "timeout")
	check(rest_button.rect_scale.distance_to(Vector2.ONE) < 0.01, "select animation returns the tile to rest scale")
	game._pulse_tile(anim_cell, 1.14, 0.08)
	yield(self.create_timer(0.6), "timeout")
	check(rest_button.rect_scale.distance_to(Vector2.ONE) < 0.01, "pulse animation returns the tile to rest scale")
	game._shake_tile(anim_cell)
	check(rest_button.rect_scale != Vector2.ZERO, "shake keeps the tile alive")

	# fx_layer: error flash registers tiles; path overlay shows hint paths
	game._flash_error_tiles([press_cell])
	check(game.error_tiles.size() == 1 && game.error_tiles[0] == press_cell, "error flash registers the tile")
	game._show_path([Vector2(0, 0), Vector2(0, 1)], "hint", 500)
	check(game.path_overlay.visible, "path overlay shows the hint path")

	# ui_hud callbacks: message timeout hides the banner; freeze timeout unfreezes
	game._show_message("超时测试", 5.0)
	game._on_message_timeout()
	check(!game.message_label.visible, "message timeout hides the banner")
	game.time_frozen = true
	game._on_time_freeze_timeout()
	check(!game.time_frozen, "freeze timeout unfreezes time")

	# game_input actions: second tick consumes the clock; shuffle costs time
	game.stage_status = game.STATUS_PLAYING
	game.special_mode = ""
	game.time_frozen = false
	game.time_left = 30
	game._on_second_tick()
	check(int(game.time_left) == 29, "second tick consumes one second")
	game._on_shuffle_pressed()
	check(int(game.time_left) == 28, "shuffle costs one second")
	check(game.stage_status == game.STATUS_PLAYING, "shuffle keeps the stage playing")

	# board_view: render_board rebuilds the grid consistently
	var grid_children = game.board_grid.get_child_count()
	game._render_board()
	check(game.board_grid.columns == int(game.board[0].size()) && game.cell_buttons.size() == game.board.size(), "render_board rebuilds the grid consistently")

	# session: combo gain formula and score/progress patch
	game.stage_status = game.STATUS_PLAYING
	game.special_mode = ""
	game.combo = 1
	game.combo_expires_ms = OS.get_ticks_msec() + 99999
	var score_before = int(game.total_score)
	var gain_res = game._apply_combo_gain(10)
	var exp_gain = int(max(1, int(round(10 * float(game._current_level().get("score_multiplier", 1.0))))) * 2.0)
	check(int(gain_res.combo) == 2 && int(gain_res.gain) == exp_gain, "combo gain applies the combo formula (got %d want %d)" % [int(gain_res.gain), exp_gain])
	check(int(game.total_score) == score_before + exp_gain, "combo gain adds the gain to total score")

	# session: time up fails the stage, restart restores play
	game.stage_status = game.STATUS_PLAYING
	game.time_left = 0
	game._on_time_up()
	check(game.stage_status == game.STATUS_FAILED, "time up fails the stage")
	game._start_level(game.level_index, false)
	check(game.stage_status == game.STATUS_PLAYING, "restart returns to playing")

	# session: special completion records results (zen + daily branches)
	game.special_mode = "zen"
	game.total_score = 7777
	game._record_special_completion()
	check(int(game.progression_state.get("zen_best_score", 0)) >= 7777, "zen completion records its result")
	check(game.stage_panel_label.visible && game.stage_panel_label.text.find("完成") != -1, "zen completion shows the settle panel")
	game.special_mode = "daily"
	game.total_score = 321
	game._record_special_completion()
	check(game.progression_state.get("daily_challenge", {}).get("last_date", "") == game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date()), "daily completion stamps today")
	game.special_mode = ""

	# ui_hud: control button factory, level select population, achievement notification
	var ctrl_button = game._create_control_button("提示")
	check(ctrl_button != null && ctrl_button.text == "提示" && ctrl_button.has_stylebox_override("normal"), "control button factory styles its button")
	game._populate_level_select_options()
	check(game.level_select_option.get_item_count() == int(game.campaign_levels.size()), "level select populated for every campaign level")
	var notif_before = game.get_child_count()
	game._show_achievement_notification("测试成就")
	check(game.get_child_count() > notif_before, "achievement notification panel created")

	# ui_hud: session timers built and the second timer ticks during play
	check(game.second_timer != null && game.race_timer != null && game.memory_hide_timer != null && game.time_freeze_timer != null, "all session timers built")
	check(!game.second_timer.is_stopped(), "second timer ticks during play")

	# ui_hud: message banner show/hide
	game._show_message("测试消息", 0.5)
	check(game.message_label.visible && game.message_label.text == "测试消息", "message banner shows text")
	game._hide_message()
	check(!game.message_label.visible, "message banner hides")

	# ui_hud: stage callout creates a floating label
	game._show_stage_callout("横幅测试", Color("ffffff"), 20)
	var callout_found = false
	for child in game.get_children():
		if child is Label && child.text == "横幅测试":
			callout_found = true
	check(callout_found, "stage callout label created")
	game.special_mode = ""
	# fx_layer: eliminate effects emit into the effect layer
	var fx_before = game.effect_layer.get_child_count()
	game.combo = 5
	game._play_eliminate_effects([press_cell])
	check(game.effect_layer.get_child_count() > fx_before, "eliminate effects spawn into the effect layer")
	game._show_combo_burst("连击 x5 +50")
	check(game.combo_burst_label != null && game.combo_burst_label.text != "", "combo burst label shows the burst text")

	# refresh_ui reflects stage status on the pause button
	game.stage_status = game.STATUS_PAUSED
	game._refresh_ui()
	check(game.pause_button.text == "继续", "refresh_ui shows resume while paused (got %s)" % game.pause_button.text)
	game.stage_status = game.STATUS_PLAYING
	game._refresh_ui()
	check(game.pause_button.text == "暂停", "refresh_ui shows pause while playing (got %s)" % game.pause_button.text)



	# onboarding
	game._build_onboarding_panel()
	check(game.onboarding_panel != null and game.onboarding_panel.get_child_count() > 0, "onboarding panel built")

	# settings
	game._build_settings_panel()
	check(game.settings_panel != null and game.settings_panel.get_child_count() > 0, "settings panel built")

	# achievements
	game._build_achievements_panel()
	check(game.achievements_panel != null and game.achievements_panel.get_child_count() > 0, "achievements panel built")

	# pause
	game._build_pause_panel()
	check(game.pause_panel != null and game.pause_panel.get_child_count() > 0, "pause panel built")

	# modes: 13 mode cards rebuilt through the registered rows box
	game._build_modes_panel()
	game._refresh_modes_panel()
	check(game.modes_panel != null, "modes panel built")
	check(game.modes_content != null && game.modes_content.get_child_count() == 14,
		"modes panel has 14 mode cards (got %d)" % (game.modes_content.get_child_count() if game.modes_content != null else -1))

	# modal lifecycle: open pauses the stage clock, close resumes it
	game.stage_status = game.STATUS_PLAYING
	game._on_settings_pressed()
	check(game.settings_panel.visible && game.stage_status == game.STATUS_PAUSED, "opening settings pauses the stage")
	check(game.second_timer.is_stopped(), "opening settings stops the second timer")
	game._on_settings_close()
	check(!game.settings_panel.visible && game.stage_status == game.STATUS_PLAYING, "closing settings resumes the stage")
	check(!game.second_timer.is_stopped(), "closing settings restarts the second timer")

	# closing must never resume a stage that paused for another reason
	game.stage_status = game.STATUS_FAILED
	game.settings_panel.visible = true
	game._on_settings_close()
	check(!game.settings_panel.visible && game.stage_status == game.STATUS_FAILED, "closing a modal never resumes a failed stage")
	game.stage_status = game.STATUS_PLAYING

	# opening while paused keeps the pause; the close owns the resume
	game._pause_stage()
	game._on_settings_pressed()
	check(game.stage_status == game.STATUS_PAUSED, "opening a modal while paused stays paused")
	game._on_settings_close()
	check(game.stage_status == game.STATUS_PLAYING, "closing a pre-paused modal resumes the stage")

	# onboarding: first run pauses until dismissed, dismissal persists
	game.progression_state.erase(game.ONBOARDING_SEEN_KEY)
	game._show_onboarding_if_needed()
	check(game.onboarding_panel.visible && game.stage_status == game.STATUS_PAUSED, "onboarding shows for unseen progress and pauses")
	game._on_onboarding_dismissed()
	check(!game.onboarding_panel.visible && game.stage_status == game.STATUS_PLAYING, "dismissing onboarding resumes the stage")
	check(bool(game.progression_state.get(game.ONBOARDING_SEEN_KEY, false)), "dismissing onboarding persists the seen flag")
	game._show_onboarding_if_needed()
	check(!game.onboarding_panel.visible, "seen progress keeps onboarding hidden")

	# achievements: reopen frees the old holder, rebuilds the list, and joins
	# the pause lifecycle
	var old_ach_holder = game.achievements_panel.get_parent()
	game._on_achievements_pressed()
	check(game.achievements_panel.get_parent() != old_ach_holder && old_ach_holder.is_queued_for_deletion(), "achievements reopen frees the old holder and mounts a fresh panel")
	check(game.achievements_panel.visible && game.stage_status == game.STATUS_PAUSED, "opening achievements pauses the stage")
	check(game.achievements_panel.get_child_count() == 1, "fresh achievements panel carries exactly one content block")
	game._on_achievements_close()
	check(!game.achievements_panel.visible && game.stage_status == game.STATUS_PLAYING, "closing achievements resumes the stage")

	# modes browser: plain show/hide that never pauses; rows rebuilt from data
	game._on_modes_pressed()
	check(game.modes_panel.visible && game.stage_status == game.STATUS_PLAYING, "opening modes never pauses the stage")
	var saved_modes_unlock = int(game.progression_state["highest_unlocked_level_index"])
	game.progression_state["highest_unlocked_level_index"] = 0
	game._refresh_modes_panel()
	var locked_count = 0
	var unlocked_count = 0
	var unlocked_wired = true
	for mode_button in game.modes_content.get_children():
		if mode_button is Button:
			if mode_button.text.find("关解锁") != -1:
				locked_count += 1
			else:
				unlocked_count += 1
				unlocked_wired = unlocked_wired && mode_button.is_connected("pressed", game, "_on_special_mode_pressed")
	check(locked_count == 12 && unlocked_count == 2, "fresh save unlocks only daily and zen (locked %d unlocked %d)" % [locked_count, unlocked_count])
	check(unlocked_wired, "unlocked mode rows wire the session start")
	var locked_sample = ""
	for mode_button in game.modes_content.get_children():
		if mode_button is Button && mode_button.text.find("关解锁") != -1:
			locked_sample = mode_button.text
			break
	check(locked_sample.find("\n完成第") != -1, "locked mode rows show their unlock requirement")
	game.progression_state["highest_unlocked_level_index"] = saved_modes_unlock
	game._refresh_modes_panel()
	var late_locked = 0
	for mode_button in game.modes_content.get_children():
		if mode_button is Button && mode_button.text.find("关解锁") != -1:
			late_locked += 1
	check(late_locked == 0 && game.modes_content.get_child_count() == 14, "rebuilt rows reflect the restored unlock index")
	game._on_modes_close_pressed()
	check(!game.modes_panel.visible, "closing modes hides the browser")

	# pause panel refresh: campaign text vs special session text + exit button
	game.special_mode = ""
	game._show_pause_panel()
	var pause_content = game.pause_panel.get_child(0).get_child(0).get_child(0)
	var pause_level_info = pause_content.get_child(1) as Label
	check(pause_level_info.text == "第3关 - 连击", "pause panel shows the campaign level (got %s)" % pause_level_info.text)
	check(!game.pause_exit_button.visible, "campaign pause hides the special exit button")
	game.special_mode = "zen"
	game.special_level = {"name": "测试模式"}
	game._show_pause_panel()
	check(pause_level_info.text == "测试模式 · " + game._mode_label("zen"), "pause panel shows the special session (got %s)" % pause_level_info.text)
	check(game.pause_exit_button.visible, "special pause shows the exit button")
	game._hide_pause_panel()
	check(!game.pause_panel.visible, "hide pause panel hides it")
	game.special_mode = ""

	# ui_hud level-select glue: locked picks bounce back with a message
	game.stage_status = game.STATUS_PLAYING
	var synced_before = game._selected_level_option_index()
	game._on_level_select_changed(99 if game.campaign_levels.size() > 99 else 0)
	check(game._selected_level_option_index() == synced_before, "level select index survives a change event")
	var unlocked_pick = -1
	for i in range(game.campaign_levels.size()):
		if game._is_level_unlocked(i) && i != int(game.level_index):
			unlocked_pick = i
			break
	check(unlocked_pick != -1, "found another unlocked level to pick")
	var index_before_pick = int(game.level_index)
	game._on_level_select_changed(unlocked_pick)
	check(int(game.level_index) == index_before_pick, "picking another unlocked level only refreshes UI, the advance flow owns the jump")
	game._sync_level_select_selection()
	check(int(game.level_select_option.selected) == int(game.level_index), "sync aligns the dropdown with the level index")
	check(game._level_label_by_index(2) == "第3关 · 连击", "level label maps index to 第N关 · name")
	game._trigger_level_highlight()
	check(game.level_select_option.modulate == game.LEVEL_HIGHLIGHT_COLOR, "level highlight tints the dropdown amber")
	game._on_level_highlight_timeout()
	check(game.level_select_option.modulate == game.LEVEL_NORMAL_COLOR, "highlight timeout restores the dropdown color")

	# ui_hud combo bar: reset clears, progress reflects the remaining window
	game.stage_status = game.STATUS_PLAYING
	game.combo = 3
	game.combo_expires_ms = OS.get_ticks_msec() + 99999
	game._update_combo_progress()
	check(float(game.combo_progress_bar.value) > 0.0, "combo bar fills while the combo window runs")
	game.stage_status = game.STATUS_PAUSED
	game._update_combo_progress()
	check(float(game.combo_progress_bar.value) == 0.0, "combo bar empties when the stage is not playing")
	game.stage_status = game.STATUS_PLAYING
	game._reset_combo()
	check(int(game.combo) == 0 && int(game.combo_expires_ms) == 0 && float(game.combo_progress_bar.value) == 0.0, "combo reset clears streak, window and bar")
	check(game.combo_reset_timer.is_stopped(), "combo reset stops the reset timer")

	# stage callout: campaign intro renders through the data-driven callout
	game.special_mode = ""
	game._play_level_intro_animation(game._current_level())
	var intro_found = false
	for child in game.get_children():
		if child is Label && child.text == "第3关 · 连击":
			intro_found = true
	check(intro_found, "campaign intro callout shows 第3关 · 连击")

	# hud_timers heartbeat callbacks: frozen clock exemption and error/combo resets
	game.stage_status = game.STATUS_PLAYING
	game.time_frozen = true
	game.time_left = 40
	game._on_second_tick()
	check(int(game.time_left) == 40, "second tick is exempt while time is frozen")
	game.time_frozen = false
	game._on_second_tick()
	check(int(game.time_left) == 39, "second tick resumes draining once unfrozen")
	game.error_tiles = [Vector2(0, 0), Vector2(1, 1)]
	game._on_error_timeout()
	check(game.error_tiles.empty(), "error timeout clears the flash registration")
	game.combo = 4
	game.combo_expires_ms = OS.get_ticks_msec() + 99999
	game._on_combo_reset_timeout()
	check(int(game.combo) == 0 && float(game.combo_progress_bar.value) == 0.0, "combo timeout resets the streak and bar")

	# hud_timers level advance: cleared campaign stage jumps to the pending level
	game.special_mode = ""
	game.stage_status = game.STATUS_CLEARED
	game.pending_level_index = 5
	game._on_level_advance_timeout()
	check(int(game.level_index) == 5 && game.stage_status == game.STATUS_PLAYING, "advance timeout starts the pending level")

	# hud_timers race tick: the AI steps on its interval and updates the pair count
	game.special_mode = "race"
	game.special_level = {"name": "竞速对战", "ai_interval": 2.0, "time_limit": 0}
	game.race_total_pairs = 30
	game.race_ai_pairs = 0
	game.race_elapsed = 0
	game.stage_status = game.STATUS_PLAYING
	game._on_race_tick()
	check(int(game.race_ai_pairs) == 0 && int(game.race_elapsed) == 1, "race tick below the interval is a no-op")
	game._on_race_tick()
	check(int(game.race_ai_pairs) == 1 && int(game.race_elapsed) == 0, "race tick at the interval adds an AI pair")
	game.special_mode = ""

	# session memory timeout: preview ends, tiles hide through the session domain
	game.special_mode = "memory"
	game.memory_previewing = true
	game.memory_lock = true
	game.memory_pending_hide = [Vector2(0, 0)]
	game.memory_revealed["0,0"] = 3
	game._on_memory_hide_timeout()
	check(game.memory_pending_hide.empty() && !game.memory_lock && !game.memory_revealed.has("0,0"), "memory hide timeout clears pending reveals")
	game._on_memory_preview_timeout()
	check(!game.memory_previewing && !game.memory_lock, "memory preview timeout unlocks the board")
	game.special_mode = ""

	# board_mechanics: frost armor cracks first, clears on the second match
	game.special_mode = "frost"
	game.board_armor = []
	for r in range(game.board.size()):
		var armor_row := []
		for c in range(game.board[0].size()):
			armor_row.append(0)
		game.board_armor.append(armor_row)
	game.board_armor[0][0] = 1
	game.board_armor[1][0] = 1
	var tile_value = int(game.board[0][0])
	var cracked1 = game._apply_match_damage(Vector2(0, 0), Vector2(1, 0))
	check(cracked1.size() == 2 && int(game.board[0][0]) == tile_value && int(game.board_armor[0][0]) == 0, "first match cracks both armored tiles without clearing")
	var cracked2 = game._apply_match_damage(Vector2(0, 0), Vector2(1, 0))
	check(cracked2.size() == 0 && int(game.board[0][0]) == 0, "second match clears the cracked tiles")
	game.board_armor = []
	game.special_mode = ""

	# board_mechanics: chain locks block playability, dissolve restores it
	game.special_mode = "chain"
	game.board_chain = []
	for r in range(game.board.size()):
		var chain_row := []
		for c in range(game.board[0].size()):
			chain_row.append(0)
		game.board_chain.append(chain_row)
	game.board_chain[2][2] = 1
	check(!game._is_coord_playable(Vector2(2, 2)), "chained cell is not playable")
	check(game._is_coord_playable(Vector2(0, 0)), "unchained cell stays playable")
	game._dissolve_all_chains()
	check(int(game._chains_remaining()) == 0 && game._is_coord_playable(Vector2(2, 2)), "dissolve clears the chains and restores playability")
	game.board_chain = []
	game.special_mode = ""

	# board_mechanics: gravity compacts the column and resets the selection
	game.selected = Vector2(0, 0)
	var rows_n = int(game.board.size())
	for r in range(rows_n):
		game.board[r][0] = 0
	game.board[0][0] = 5
	var moved = game._apply_gravity()
	check(bool(moved) && int(game.board[rows_n - 1][0]) == 5 && int(game.board[0][0]) == 0, "gravity compacts the column downward")
	check(game.selected == Vector2(-1, -1) && game.hint_tiles.empty(), "gravity resets selection and hints")

	# board_mechanics: fog layers follow the mode and reset outside it
	game.special_mode = "fog"
	game.special_level = {"name": "迷雾模式", "fog_layers": 2}
	game._update_fog()
	check(int(game._fog_layers) >= 1, "fog mode derives its outer ring layers")
	game.special_mode = ""
	game._update_fog()
	check(int(game._fog_layers) == 0, "fog layers reset outside fog mode")

	# board_engine: bomb/rainbow edge path leaves through the top row
	var edge = game._board_edge_path(Vector2(2, 5), Vector2(3, 8))
	check(edge.size() == 3 && edge[1] == Vector2(-1, 5), "edge path routes over the top edge")

	# ui_fonts: per-size cache returns the same font; theme stays mounted
	var font_a = game._font_at_size(24)
	check(font_a != null && font_a == game._font_at_size(24), "font cache returns the same DynamicFont per size")
	check(game.theme != null && game.game_font != null, "global theme and game_font stay mounted")

	# board_view glue: tile lookup bounds and icon color fallback
	check(game._try_get_tile_button(Vector2(-1, 0)) == null && game._try_get_tile_button(Vector2(9999, 0)) == null, "tile lookup rejects out-of-bounds coords")
	check(game._try_get_tile_button(Vector2(0, 0)) != null, "tile lookup returns the board button")
	var saved_icon_sets = game.icon_sets
	var saved_icon_set_index = int(game.icon_set_index)
	game.icon_sets = []
	check(game._color_for(3) == Color("ffffff"), "icon color falls back to white without icon sets")
	game.icon_sets = saved_icon_sets
	game.icon_set_index = saved_icon_set_index

	# fx_layer glue: tween factory parents to the game; celebration spawns fx
	var tween = game._make_fx_tween()
	check(tween != null && tween.get_parent() == game, "fx tween factory parents the tween to the game")
	var children_before_celebration = game.get_child_count()
	game._play_stage_clear_celebration(false)
	check(game.get_child_count() > children_before_celebration, "stage clear celebration spawns fx nodes")

	# stats_hud: time danger honors clockless modes and the danger threshold
	game.stage_status = game.STATUS_PLAYING
	game.special_mode = "endless"
	check(!game._is_time_danger(), "clockless endless never hits time danger")
	game.special_mode = ""
	game.time_left = 3
	check(game._is_time_danger(), "low time in a playing stage flags danger")
	game.time_left = 999
	check(!game._is_time_danger(), "healthy time clears danger")
	game.stage_status = game.STATUS_PAUSED
	check(!game._is_time_danger(), "paused stage never flags danger")
	game.stage_status = game.STATUS_PLAYING

	# ui_panels actions: session-aware restart and the campaign reset path
	game.special_mode = "zen"
	game._on_restart_current_level()
	check(game.special_mode == "zen", "restart inside a special session reruns the session")
	game.special_mode = ""
	game._on_back_to_first_level()
	check(int(game.level_index) == 0 && game.stage_status == game.STATUS_PLAYING, "back to first level starts level 1")

	if failures == 0:
		print("panels_probe: ALL PASSED")
		quit(0)
	else:
		print("panels_probe: %d FAILURES" % failures)
		quit(1)
