extends Reference

# Screen adaptation: viewport classification and the responsive layout pass
# (board height, margins, grid separation, stat/control sizing, portrait
# header compaction). Extracted from ui_hud.gd so the main-screen module
# stays build/refresh only.

static func update_layout(game):
	if game.board_wrapper == null or game.board_grid == null:
		return

	# Get viewport size for responsive layout
	var viewport_size = game.get_viewport_rect().size
	var flags = game._viewport_flags(viewport_size)
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]

	# Give board more vertical room on mobile and wide desktop.
	if is_mobile:
		# Portrait relies on EXPAND_FILL for remaining space; keep the min small to avoid overflow.
		var mobile_ratio = game.BOARD_RATIO_MOBILE_PORTRAIT if is_portrait else game.BOARD_RATIO_MOBILE_LANDSCAPE
		# Portrait is the flagship layout: the board is the product, the header
		# is chrome. Cap lifted to 80% so tall boards (endless/hell) can breathe.
		var portrait_cap = 0.80 if is_portrait else 0.62
		game.board_wrapper.rect_min_size = Vector2(0, min(max(game.BOARD_MIN_HEIGHT, viewport_size.y * mobile_ratio), viewport_size.y * portrait_cap))
	else:
		game.board_wrapper.rect_min_size = Vector2(0, max(420.0, viewport_size.y * game.BOARD_RATIO_DESKTOP))

	# Adjust margins based on screen size
	var margin_value = 4 if (is_mobile and is_portrait) else (6 if is_compact_height else (8 if is_mobile else 16))
	# The bottom strip also reserves room for the persistent navigation bar.
	var nav_strip = 50 if is_mobile else 64
	if game.margin_container:
		game.margin_container.add_constant_override("margin_left", margin_value)
		game.margin_container.add_constant_override("margin_right", margin_value)
		game.margin_container.add_constant_override("margin_top", margin_value)
		game.margin_container.add_constant_override("margin_bottom", margin_value + nav_strip)

	# Adjust header font sizes
	if game.title_label:
		pass
	if game.subtitle_label:
		pass
	if game.desc_label:
		game.desc_label.visible = not is_mobile

	# Power-up shortcut chips only make sense with a keyboard.
	for power_up_id in game.power_up_labels:
		var labels = game.power_up_labels[power_up_id]
		if labels.has("shortcut") and labels["shortcut"] != null:
			labels["shortcut"].visible = not is_mobile

	# Adjust tile separation based on screen size
	if is_mobile and is_compact_height:
		game.board_grid.add_constant_override("h_separation", 3)
		game.board_grid.add_constant_override("v_separation", 3)
	elif is_mobile:
		# Portrait phones are width-bound: tighter separation buys ~1 tile of width.
		game.board_grid.add_constant_override("h_separation", 3)
		game.board_grid.add_constant_override("v_separation", 3)
	else:
		game.board_grid.add_constant_override("h_separation", 10)
		game.board_grid.add_constant_override("v_separation", 10)

	if game.stats_flow_container:
		game.stats_flow_container.add_constant_override("h_separation", 4 if is_mobile else 6)
		game.stats_flow_container.add_constant_override("v_separation", 6 if is_mobile else 6)

	var stat_card_size = Vector2(66, 44) if is_mobile and is_portrait else (Vector2(82, 54) if is_mobile else Vector2(100, 64))
	var stat_value_size = 16 if is_mobile and is_portrait else (20 if is_mobile else 22)
	var stat_title_size = 10 if is_mobile else 11
	for key in game.stat_values.keys():
		var card = game.stat_values[key]["card"]
		var title_small = game.stat_values[key]["title"]
		var value_label = game.stat_values[key]["value"]
		card.rect_min_size = stat_card_size
		title_small.rect_min_size = Vector2(0, stat_title_size + 4)
		value_label.rect_min_size = Vector2(0, stat_value_size + 6)

	var control_min = Vector2(72, 34) if is_mobile and is_compact_height else (Vector2(76, 36) if is_mobile and is_portrait else (Vector2(80, 36) if is_mobile else Vector2(88, 42)))
	if game.icon_set_option:
		game.icon_set_option.rect_min_size = Vector2(108 if is_mobile else 122, control_min.y)
	if game.level_select_option:
		game.level_select_option.rect_min_size = Vector2(130 if is_mobile else 172, control_min.y)
	for button in [game.hint_button, game.auto_button, game.shuffle_button, game.pause_button, game.reset_button, game.jump_level_button, game.clear_progress_button, game.modes_button]:
		if button:
			button.rect_min_size = control_min
	# Portrait: compact taps keep both control rows on single lines.
	if is_mobile and is_portrait:
		for button in [game.hint_button, game.auto_button, game.shuffle_button, game.pause_button, game.reset_button, game.modes_button, game.stats_button, game.settings_button]:
			if button:
				button.rect_min_size = Vector2(62, 34)

	if game.controls_flow_container:
		game.controls_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		game.controls_flow_container.add_constant_override("v_separation", 6 if is_mobile else 8)
	if game.progression_flow_container:
		game.progression_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		game.progression_flow_container.add_constant_override("v_separation", 6 if is_mobile else 8)

	# Portrait phones: compress the header so the board owns the screen.
	# The board is the product — every hidden strip here is board real estate.
	if is_mobile and is_portrait:
		if game.root_vbox:
			game.root_vbox.add_constant_override("separation", 4)
		if game.header_box:
			game.header_box.add_constant_override("separation", 3)
		# Title column: keep only the game name; status/meta chips are noise.
		if game.subtitle_label:
			game.subtitle_label.visible = false
		if game.desc_label:
			game.desc_label.visible = false
		if game.status_chip_label:
			game.status_chip_label.visible = false
		if game.mode_chip_label:
			game.mode_chip_label.visible = false
		if game.kinds_chip_label:
			game.kinds_chip_label.visible = false
		if game.level_progress_caption_label:
			game.level_progress_caption_label.visible = false
		if game.level_progress_bar:
			game.level_progress_bar.rect_min_size = Vector2(0, 6)
		if game.jump_level_button:
			game.jump_level_button.visible = false
		if game.clear_progress_button:
			game.clear_progress_button.visible = false
		# Set picking lives in the shop page, level picking in the journey map:
		# the two dropdowns only cost header rows on touch screens.
		if game.icon_set_option:
			game.icon_set_option.visible = false
		if game.level_select_option:
			game.level_select_option.visible = false
		if game.level_select_label:
			game.level_select_label.visible = false
		if game.combo_progress_bar:
			game.combo_progress_bar.rect_min_size = Vector2(0, 4)
		# Single row of the 4 essential cards keeps the header to one stat line.
		for hidden_key in ["level_score", "moves", "best_total_score", "best_combo"]:
			if game.stat_values.has(hidden_key) and game.stat_values[hidden_key].has("card"):
				game.stat_values[hidden_key]["card"].visible = false
	else:
		if game.subtitle_label:
			game.subtitle_label.visible = true
		if game.status_chip_label:
			game.status_chip_label.visible = true
		if game.mode_chip_label:
			game.mode_chip_label.visible = true
		if game.kinds_chip_label:
			game.kinds_chip_label.visible = true
		if game.icon_set_option:
			game.icon_set_option.visible = true
		if game.level_select_option:
			game.level_select_option.visible = true
		if game.level_select_label:
			game.level_select_label.visible = true
		for hidden_key in ["level_score", "moves", "best_total_score", "best_combo"]:
			if game.stat_values.has(hidden_key) and game.stat_values[hidden_key].has("card"):
				game.stat_values[hidden_key]["card"].visible = true
		if game.level_progress_caption_label:
			game.level_progress_caption_label.visible = true
		if game.jump_level_button:
			game.jump_level_button.visible = true
		if game.clear_progress_button:
			game.clear_progress_button.visible = true

	game._update_modal_panel_sizes(viewport_size, is_portrait)


static func _viewport_flags(game, viewport_size):
	var short_side = min(viewport_size.x, viewport_size.y)
	var is_mobile = short_side <= game.MOBILE_SHORT_SIDE_MAX
	var is_portrait = viewport_size.y >= viewport_size.x
	var is_compact_height = viewport_size.y <= game.MOBILE_COMPACT_HEIGHT_MAX
	return {
		"is_mobile": is_mobile,
		"is_portrait": is_portrait,
		"is_compact_height": is_compact_height
	}
