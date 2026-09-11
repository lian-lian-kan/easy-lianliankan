extends Reference

# Home screen construction: the full main board layout (background, header,
# stat cards, power-up row, controls, board area, wallet) plus the page
# surface and nav mount. Extraction is a verbatim move from ui_hud.gd —
# state lives on the game node, refresh_ui stays in ui_hud.gd.
# build_main_ui only sequences the section builders below; each one mirrors
# a contiguous block of the original function, in the original order, so
# add_child ordering (z-order and layout) is unchanged.

const PAGE_ROUTER = preload("res://scripts/page_router.gd")
const ECONOMY = preload("res://scripts/economy.gd")
const PATH_OVERLAY_SCRIPT = preload("res://scripts/path_overlay.gd")

static func build_main_ui(game):
	_build_root(game)
	_build_header_identity(game)
	_build_header_progress(game)
	_build_power_ups(game)
	_build_controls_flow(game)
	_build_progression_flow(game)
	_build_message_banner(game)
	_build_board_area(game)
	_build_floating_overlays(game)
	_finalize_build(game)

# Background, petals, outer margin and the root vbox everything hangs off.

static func _build_root(game):
	game.set_anchors_and_margins_preset(Control.PRESET_WIDE)

	# Add gradient background
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	bg_rect.color = Color("fff0f6")
	game.add_child(bg_rect)
	game.bg_rect = bg_rect

	game._petal_layer = Control.new()
	game._petal_layer.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	game._petal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(game._petal_layer)
	game._build_petals()

	var margin = MarginContainer.new()
	margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	margin.add_constant_override("margin_left", 16)
	margin.add_constant_override("margin_right", 16)
	margin.add_constant_override("margin_top", 16)
	margin.add_constant_override("margin_bottom", 16)
	game.add_child(margin)
	game.margin_container = margin

	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_constant_override("separation", 12)
	margin.add_child(root)
	game.root_vbox = root

# Header panel: title / subtitle / description / status chip / coin chip.

static func _build_header_identity(game):
	# Header panel with glass morphism effect
	var header_panel = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._apply_glass_style(header_panel, Color("ffffff"), 0.9)
	game.root_vbox.add_child(header_panel)

	game.header_box = VBoxContainer.new()
	game.header_box.add_constant_override("separation", 8)
	header_panel.add_child(game.header_box)

	game.title_row = HBoxContainer.new()
	game.title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.header_box.add_child(game.title_row)

	var title_col = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.title_row.add_child(title_col)

	game.title_label = Label.new()
	game.title_label.text = "Sophia的连连看"
	game.title_label.add_font_override("font", game.game_font)
	game.title_label.add_color_override("font_color", Color("e64980"))
	title_col.add_child(game.title_label)

	game.subtitle_label = Label.new()
	game.subtitle_label.text = "第1/1关 · 初始化"
	game.subtitle_label.add_font_override("font", game.game_font)
	game.subtitle_label.add_color_override("font_color", Color("8f6b80"))
	title_col.add_child(game.subtitle_label)

	game.desc_label = Label.new()
	game.desc_label.add_font_override("font", game.game_font)
	game.desc_label.add_color_override("font_color", Color("c2a3b2"))
	game.desc_label.text = ""
	title_col.add_child(game.desc_label)

	game.status_chip_label = Label.new()
	game.status_chip_label.text = "进行中"
	game.status_chip_label.add_font_override("font", game.game_font)
	game.status_chip_label.align = Label.ALIGN_CENTER
	game.status_chip_label.valign = Label.VALIGN_CENTER
	game.status_chip_label.rect_min_size = Vector2(90, 32)
	game.status_chip_label.add_color_override("font_color", Color("0ca678"))
	# Add status badge style
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color("e6fcf5")
	status_style.set_corner_radius_all(16)
	game.status_chip_label.add_stylebox_override("normal", status_style)
	game.title_row.add_child(game.status_chip_label)

	var coin_chip = ECONOMY.build_coin_chip(game)
	game.title_row.add_child(coin_chip)

# Level progress bar, mode/kinds chips and the stat card grid.

static func _build_header_progress(game):
	game.level_progress_caption_label = Label.new()
	game.level_progress_caption_label.text = "闯关进度"
	game.level_progress_caption_label.add_font_override("font", game.game_font)
	game.level_progress_caption_label.add_color_override("font_color", Color("8f6b80"))
	game.header_box.add_child(game.level_progress_caption_label)

	game.level_progress_bar = ProgressBar.new()
	game.level_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.level_progress_bar.min_value = 0
	game.level_progress_bar.max_value = 100
	game.level_progress_bar.value = 0
	game.level_progress_bar.percent_visible = false
	game.level_progress_bar.rect_min_size = Vector2(0, 12)
	# Style progress bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color("ffd9e8")
	progress_bg.set_corner_radius_all(6)
	game.level_progress_bar.add_stylebox_override("background", progress_bg)
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color("f783ac")
	progress_fill.set_corner_radius_all(6)
	game.level_progress_bar.add_stylebox_override("fill", progress_fill)
	game.header_box.add_child(game.level_progress_bar)

	var meta_row = HBoxContainer.new()
	meta_row.add_constant_override("separation", 8)
	game.header_box.add_child(meta_row)

	game.mode_chip_label = game._create_chip_label()
	meta_row.add_child(game.mode_chip_label)

	game.kinds_chip_label = game._create_chip_label()
	meta_row.add_child(game.kinds_chip_label)

	game.stats_flow_container = HFlowContainer.new()
	game.stats_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.stats_flow_container.add_constant_override("h_separation", 6)
	game.stats_flow_container.add_constant_override("v_separation", 6)
	game.header_box.add_child(game.stats_flow_container)

	game._add_stat_card(game.stats_flow_container, "总分", "total_score")
	game._add_stat_card(game.stats_flow_container, "本关分", "level_score")
	game._add_stat_card(game.stats_flow_container, "步数", "moves")
	game._add_stat_card(game.stats_flow_container, "剩余", "remaining")
	game._add_stat_card(game.stats_flow_container, "倒计时", "time_left")
	game._add_stat_card(game.stats_flow_container, "连击", "combo")
	game._add_stat_card(game.stats_flow_container, "历史高分", "best_total_score")
	game._add_stat_card(game.stats_flow_container, "历史连击", "best_combo")
	game._add_stat_card(game.stats_flow_container, "对手", "race")

# Power-up chips row plus the combo timer bar underneath.

static func _build_power_ups(game):
	# Power-ups display container
	# Single row, centered. On phones the [1]-[7] shortcut chips are hidden
	# (keyboard-only affordance) so all 7 power-ups fit a 390px width.
	game.power_ups_container = HBoxContainer.new()
	game.power_ups_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game.power_ups_container.add_constant_override("separation", 6)
	game.header_box.add_child(game.power_ups_container)

	# Create power-up labels
	game._create_power_up_label("time_freeze", "⏱️", "1")
	game._create_power_up_label("auto_match", "🎯", "2")
	game._create_power_up_label("reshuffle", "🔄", "3")
	game._create_power_up_label("magnifier", "🔍", "4")
	game._create_power_up_label("time_sand", "⏳", "5")
	game._create_power_up_label("bomb", "💣", "6")
	game._create_power_up_label("rainbow", "🌈", "7")
	game._create_power_up_label("warm_patch", "🔥", "8")

	game.combo_progress_bar = ProgressBar.new()
	game.combo_progress_bar.min_value = 0
	game.combo_progress_bar.max_value = 100
	game.combo_progress_bar.value = 0
	game.combo_progress_bar.percent_visible = false
	game.combo_progress_bar.rect_min_size = Vector2(0, 10)
	# Style combo bar
	var combo_bg = StyleBoxFlat.new()
	combo_bg.bg_color = Color("ffd9e8")
	combo_bg.set_corner_radius_all(5)
	game.combo_progress_bar.add_stylebox_override("background", combo_bg)
	var combo_fill = StyleBoxFlat.new()
	combo_fill.bg_color = Color("ff8fab")
	combo_fill.set_corner_radius_all(5)
	game.combo_progress_bar.add_stylebox_override("fill", combo_fill)
	game.header_box.add_child(game.combo_progress_bar)

# Tool row: icon-set dropdown and the five play controls.

static func _build_controls_flow(game):
	game.controls_flow_container = HFlowContainer.new()
	game.controls_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.controls_flow_container.add_constant_override("h_separation", 8)
	game.controls_flow_container.add_constant_override("v_separation", 8)
	game.header_box.add_child(game.controls_flow_container)

	game.icon_set_option = OptionButton.new()
	game.icon_set_option.add_font_override("font", game.game_font)
	game.icon_set_option.rect_min_size = Vector2(140, 42)
	game.icon_set_option.connect("item_selected", game, "_on_icon_set_selected")
	game.icon_set_option.add_stylebox_override("normal", _dropdown_style())
	game.icon_set_option.add_color_override("font_color", Color("8f6b80"))
	game.controls_flow_container.add_child(game.icon_set_option)

	game.hint_button = game._create_control_button("提示")
	game.hint_button.connect("pressed", game, "_on_hint_pressed")
	game.controls_flow_container.add_child(game.hint_button)

	game.auto_button = game._create_control_button("自动消")
	game.auto_button.connect("pressed", game, "_on_auto_pressed")
	game.controls_flow_container.add_child(game.auto_button)

	game.shuffle_button = game._create_control_button("洗牌")
	game.shuffle_button.connect("pressed", game, "_on_shuffle_pressed")
	game.controls_flow_container.add_child(game.shuffle_button)

	game.pause_button = game._create_control_button("暂停")
	game.pause_button.connect("pressed", game, "_on_pause_pressed")
	game.controls_flow_container.add_child(game.pause_button)

	game.reset_button = game._create_control_button("重开")
	game.reset_button.connect("pressed", game, "_on_reset_pressed")
	game.controls_flow_container.add_child(game.reset_button)

# Progression row: modes / stats / level select / jump / clear / settings.

static func _build_progression_flow(game):
	game.progression_flow_container = HFlowContainer.new()
	game.progression_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.progression_flow_container.add_constant_override("h_separation", 8)
	game.progression_flow_container.add_constant_override("v_separation", 8)
	game.header_box.add_child(game.progression_flow_container)

	game.modes_button = game._create_control_button("🎮 玩法")
	game.modes_button.connect("pressed", game, "_on_modes_pressed")
	game.progression_flow_container.add_child(game.modes_button)

	game.stats_button = game._create_control_button("📊 数据")
	game.stats_button.connect("pressed", game, "_on_stats_pressed")
	game.progression_flow_container.add_child(game.stats_button)

	game.level_select_label = Label.new()
	game.level_select_label.text = "关卡："
	game.level_select_label.add_font_override("font", game.game_font)
	game.level_select_label.add_color_override("font_color", Color("8f6b80"))
	game.progression_flow_container.add_child(game.level_select_label)

	game.level_select_option = OptionButton.new()
	game.level_select_option.add_font_override("font", game.game_font)
	game.level_select_option.rect_min_size = Vector2(172, 42)
	game.level_select_option.connect("item_selected", game, "_on_level_select_changed")
	game.level_select_option.add_stylebox_override("normal", _dropdown_style())
	game.level_select_option.add_color_override("font_color", Color("8f6b80"))
	game.progression_flow_container.add_child(game.level_select_option)

	game.jump_level_button = game._create_control_button("跳转关卡")
	game.jump_level_button.connect("pressed", game, "_on_jump_level_pressed")
	game.progression_flow_container.add_child(game.jump_level_button)

	game.clear_progress_button = game._create_control_button("清除进度")
	game.clear_progress_button.connect("pressed", game, "_on_clear_progress_pressed")
	game.progression_flow_container.add_child(game.clear_progress_button)

	game.settings_button = game._create_control_button("⚙️ 设置")
	game.settings_button.connect("pressed", game, "_on_settings_pressed")
	game.progression_flow_container.add_child(game.settings_button)

	var achievements_button = game._create_control_button("🏆 成就")
	achievements_button.connect("pressed", game, "_on_achievements_pressed")
	game.progression_flow_container.add_child(achievements_button)

# Shared rounded white style for both OptionButtons (was one local in the
# original function, now a factory so each control gets its own copy).

static func _dropdown_style():
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color("ffffff")
	dropdown_style.set_corner_radius_all(10)
	dropdown_style.shadow_color = Color("00000010")
	dropdown_style.shadow_size = 4
	dropdown_style.shadow_offset = Vector2(0, 2)
	dropdown_style.set_border_width_all(1)
	dropdown_style.border_color = Color("ffd9e8")
	return dropdown_style

# Message banner floats over the board's bottom edge (not inside the header:
# a header banner made the canvas bounce on every combo).

static func _build_message_banner(game):
	game.message_label = Label.new()
	game.message_label.add_font_override("font", game.game_font)
	game.message_label.add_color_override("font_color", Color("ffffff"))
	game.message_label.align = Label.ALIGN_CENTER
	game.message_label.valign = Label.VALIGN_CENTER
	game.message_label.visible = false
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = Color("d6336ce6")
	banner_style.set_corner_radius_all(16)
	banner_style.content_margin_left = 14
	banner_style.content_margin_right = 14
	banner_style.content_margin_top = 5
	banner_style.content_margin_bottom = 5
	game.message_label.add_stylebox_override("normal", banner_style)
	game.message_label.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
	game.message_label.margin_left = 14
	game.message_label.margin_right = 14
	game.message_label.rect_min_size = Vector2(0, 32)
	game.add_child(game.message_label)

# Board wrapper, panel, center container, grid and the overlay layers.

static func _build_board_area(game):
	game.board_wrapper = Control.new()
	game.board_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.board_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game.board_wrapper.rect_min_size = Vector2(0, 400)
	game.root_vbox.add_child(game.board_wrapper)
	# Let the board absorb ALL remaining height instead of overflowing the canvas.
	game.board_wrapper.size_flags_stretch_ratio = 1.0

	var board_panel = PanelContainer.new()
	board_panel.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	# Apply game board style
	var board_style = StyleBoxFlat.new()
	board_style.bg_color = Color("ffffff")
	board_style.set_corner_radius_all(26)
	board_style.shadow_color = Color("00000015")
	board_style.shadow_size = 10
	board_style.shadow_offset = Vector2(0, 5)
	board_style.set_border_width_all(2)
	board_style.border_color = Color("ffd9e8")
	board_panel.add_stylebox_override("panel", board_style)
	game.board_wrapper.add_child(board_panel)

	var board_inner = Control.new()
	board_inner.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	board_panel.add_child(board_inner)

	game.board_center = CenterContainer.new()
	game.board_center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	game.board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_inner.add_child(game.board_center)

	game.collect_row = ECONOMY.build_collect_row(game)
	game.root_vbox.add_child(game.collect_row)

	game.tray_layer = Control.new()
	game.tray_layer.visible = false
	game.board_wrapper.add_child(game.tray_layer)
	game.flip_layer = Control.new()
	game.flip_layer.visible = false
	game.board_wrapper.add_child(game.flip_layer)

	game.board_grid = GridContainer.new()
	game.board_grid.columns = 6
	game.board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game.board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	game.board_grid.add_constant_override("h_separation", 10)
	game.board_grid.add_constant_override("v_separation", 10)
	game.board_center.add_child(game.board_grid)

	game.path_overlay = game.PATH_OVERLAY_SCRIPT.new()
	game.path_overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	game.path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_inner.add_child(game.path_overlay)

	game.effect_layer = Control.new()
	game.effect_layer.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	game.effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_inner.add_child(game.effect_layer)

# Floating combat text and rescue buttons anchored over the board.

static func _build_floating_overlays(game):
	game.stage_panel_label = Label.new()
	game.stage_panel_label.add_font_override("font", game.game_font)
	game.stage_panel_label.align = Label.ALIGN_CENTER
	game.stage_panel_label.add_color_override("font_color", Color("6d4a5e"))
	game.stage_panel_label.visible = false
	game.root_vbox.add_child(game.stage_panel_label)

	# Blossom revive offer, shown beside the failed-settle text.
	game.revive_button = Button.new()
	game.revive_button.text = "🌸30 复活（+30秒 / +5步）"
	game.revive_button.rect_min_size = Vector2(220, 40)
	game.revive_button.add_font_override("font", game._font_at_size(14))
	game._apply_button_style(game.revive_button, Color("f06ba8"), Color("d6336c"))
	game.revive_button.add_color_override("font_color", Color("ffffff"))
	game.revive_button.visible = false
	game.revive_button.set_anchors_and_margins_preset(Control.PRESET_TOP_WIDE)
	game.revive_button.margin_top = 148
	game.revive_button.margin_left = 85
	game.revive_button.margin_right = 85
	game.revive_button.connect("pressed", game, "_on_revive_pressed")
	game.root_vbox.add_child(game.revive_button)

	# Husband rescue button: floats above the board's bottom edge, appears
	# only when the clock is running low (visibility driven by _refresh_ui).
	game.husband_button = Button.new()
	game.husband_button.text = "🆘 求助老公"
	game.husband_button.rect_min_size = Vector2(180, 40)
	game.husband_button.add_font_override("font", game._font_at_size(14))
	game._apply_button_style(game.husband_button, Color("f06ba8"), Color("d6336c"))
	game.husband_button.add_color_override("font_color", Color("ffffff"))
	game.husband_button.visible = false
	game.husband_button.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
	game.husband_button.margin_left = 120
	game.husband_button.margin_right = 120
	game.husband_button.connect("pressed", game, "_on_husband_pressed")
	game.root_vbox.add_child(game.husband_button)

	game.combo_burst_label = Label.new()
	game.combo_burst_label.add_font_override("font", game.game_font)
	game.combo_burst_label.align = Label.ALIGN_CENTER
	game.combo_burst_label.add_color_override("font_color", Color("e67700"))
	game.combo_burst_label.visible = false
	game.combo_burst_label.set_anchors_and_margins_preset(Control.PRESET_TOP_WIDE)
	game.combo_burst_label.margin_top = 88
	game.combo_burst_label.margin_left = 0
	game.combo_burst_label.margin_right = 0
	game.add_child(game.combo_burst_label)

# Post-construction wiring: options, dialog panels, pages, theme, layout.

static func _finalize_build(game):
	game._populate_icon_set_options()
	game._populate_level_select_options()
	game._build_onboarding_panel()
	game._build_settings_panel()
	game._build_achievements_panel()
	game._build_pause_panel()
	game._build_modes_panel()
	PAGE_ROUTER.build_pages(game)
	# Apply the saved ambience theme (falls back to sakura pink).
	ECONOMY.apply_theme(game, str(game.progression_state.get("current_theme", "sakura")))
	game.call_deferred("_update_layout_for_screen_size")
