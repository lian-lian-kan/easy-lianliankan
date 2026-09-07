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
