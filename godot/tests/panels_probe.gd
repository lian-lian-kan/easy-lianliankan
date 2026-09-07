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
	game.special_mode = "zen"
	game._patch_progress_state({"combo_candidate": 12, "current_level_index": 3})
	check(int(game.progression_state.get("best_combo", 0)) >= 41, "special session combo candidate never lowers campaign best")
	check(int(game.progression_state.get("current_level_index", 0)) != 3, "special session never touches campaign progress")
	game._patch_progress_state({"zen_result": 99})
	check(int(game.progression_state.get("zen_best_score", 0)) >= 99, "special session persists its own record")
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

	# modes: 13 mode cards inside the scroll box
	game._build_modes_panel()
	game._refresh_modes_panel()
	check(game.modes_panel != null, "modes panel built")
	var content = game.modes_panel.get_child(0).get_child(0).get_child(0)
	var rows_box = content.get_child(1).get_child(0)
	check(rows_box.get_child_count() == 13, "modes panel has 13 mode cards (got %d)" % rows_box.get_child_count())

	if failures == 0:
		print("panels_probe: ALL PASSED")
		quit(0)
	else:
		print("panels_probe: %d FAILURES" % failures)
		quit(1)
