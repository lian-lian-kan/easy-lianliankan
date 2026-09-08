extends Reference

# Main screen construction, extracted from gd so the 300+ line HUD/board
# layout lives beside the dialog factories in ui_panels.gd. Every call takes
# the live game node and assigns straight onto its members.

static func build_main_ui(game):
	game.set_anchors_and_margins_preset(Control.PRESET_WIDE)

	# Add gradient background
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	bg_rect.color = Color("fff0f6")
	game.add_child(bg_rect)

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

	# Header panel with glass morphism effect
	var header_panel = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._apply_glass_style(header_panel, Color("ffffff"), 0.9)
	root.add_child(header_panel)

	game.header_box = VBoxContainer.new()
	game.header_box.add_constant_override("separation", 8)
	header_panel.add_child(game.header_box)

	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.header_box.add_child(title_row)

	var title_col = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_col)

	game.title_label = Label.new()
	game.title_label.text = "连连看 🎀"
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
	title_row.add_child(game.status_chip_label)

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

	game.controls_flow_container = HFlowContainer.new()
	game.controls_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.controls_flow_container.add_constant_override("h_separation", 8)
	game.controls_flow_container.add_constant_override("v_separation", 8)
	game.header_box.add_child(game.controls_flow_container)

	game.icon_set_option = OptionButton.new()
	game.icon_set_option.add_font_override("font", game.game_font)
	game.icon_set_option.rect_min_size = Vector2(140, 42)
	game.icon_set_option.connect("item_selected", game, "_on_icon_set_selected")
	# Style the dropdown
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color("ffffff")
	dropdown_style.set_corner_radius_all(10)
	dropdown_style.shadow_color = Color("00000010")
	dropdown_style.shadow_size = 4
	dropdown_style.shadow_offset = Vector2(0, 2)
	dropdown_style.set_border_width_all(1)
	dropdown_style.border_color = Color("ffd9e8")
	game.icon_set_option.add_stylebox_override("normal", dropdown_style)
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

	game.progression_flow_container = HFlowContainer.new()
	game.progression_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.progression_flow_container.add_constant_override("h_separation", 8)
	game.progression_flow_container.add_constant_override("v_separation", 8)
	game.header_box.add_child(game.progression_flow_container)

	game.modes_button = game._create_control_button("🎮 玩法")
	game.modes_button.connect("pressed", game, "_on_modes_pressed")
	game.progression_flow_container.add_child(game.modes_button)

	var level_select_label = Label.new()
	level_select_label.text = "关卡："
	level_select_label.add_font_override("font", game.game_font)
	level_select_label.add_color_override("font_color", Color("8f6b80"))
	game.progression_flow_container.add_child(level_select_label)

	game.level_select_option = OptionButton.new()
	game.level_select_option.add_font_override("font", game.game_font)
	game.level_select_option.rect_min_size = Vector2(172, 42)
	game.level_select_option.connect("item_selected", game, "_on_level_select_changed")
	game.level_select_option.add_stylebox_override("normal", dropdown_style)
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

	game.message_label = Label.new()
	game.message_label.add_font_override("font", game.game_font)
	game.message_label.add_color_override("font_color", Color("d6336c"))
	game.message_label.visible = false
	game.header_box.add_child(game.message_label)

	game.board_wrapper = Control.new()
	game.board_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.board_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game.board_wrapper.rect_min_size = Vector2(0, 400)
	root.add_child(game.board_wrapper)
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

	game.stage_panel_label = Label.new()
	game.stage_panel_label.add_font_override("font", game.game_font)
	game.stage_panel_label.align = Label.ALIGN_CENTER
	game.stage_panel_label.add_color_override("font_color", Color("6d4a5e"))
	game.stage_panel_label.visible = false
	root.add_child(game.stage_panel_label)

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

	game._populate_icon_set_options()
	game._populate_level_select_options()
	game._build_onboarding_panel()
	game._build_settings_panel()
	game._build_achievements_panel()
	game._build_pause_panel()
	game._build_modes_panel()
	game.call_deferred("_update_layout_for_screen_size")

static func refresh_ui(game):
	var level = game._current_level()
	var level_id = int(level.get("id", game.level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	var description = str(level.get("description", ""))
	var unlocked_level_count = int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1

	game.title_label.text = "连连看 🎀"
	if game.special_mode == "daily":
		var daily = game.progression_state.get("daily_challenge", {})
		var now_date = OS.get_date()
		var done_today = str(daily.get("last_date", "")) == game.SPECIAL_MODES_SCRIPT.date_string(now_date)
		game.subtitle_label.text = "每日挑战 · %d月%d日 · 连胜%d · 最佳%d · %s" % [
			int(now_date.month), int(now_date.day),
			int(daily.get("streak", 0)), int(daily.get("best_score", 0)),
			"今日已完成" if done_today else "今日未完成"
		]
	elif game.special_mode == "endless":
		var endless_best = game.progression_state.get("endless_best", {})
		game.subtitle_label.text = "无尽模式 · 第%d轮 · 最佳第%d轮 · 最高%d分" % [
			game.endless_round, int(endless_best.get("round", 0)), int(endless_best.get("score", 0))
		]
	elif game.special_mode == "time_attack":
		game.subtitle_label.text = "限时挑战 · 最佳%d分" % int(game.progression_state.get("time_attack_best_score", 0))
	elif game.special_mode == "memory":
		game.subtitle_label.text = "盲盒模式 · 最佳%d分" % int(game.progression_state.get("memory_best_score", 0))
	elif game.special_mode == "frost":
		game.subtitle_label.text = "冰雪挑战 · 最佳%d分" % int(game.progression_state.get("frost_best_score", 0))
	elif game.special_mode == "zen":
		game.subtitle_label.text = "休闲模式 · 最佳%d分" % int(game.progression_state.get("zen_best_score", 0))
	elif game.special_mode == "hell":
		game.subtitle_label.text = "地狱模式 · 最佳%d分" % int(game.progression_state.get("hell_best_score", 0))
	elif game.special_mode == "moves":
		game.subtitle_label.text = "步数挑战 · 最佳%d分 · 剩余%d步" % [int(game.progression_state.get("moves_best_score", 0)), game.moves_left]
	elif game.special_mode == "race":
		game.subtitle_label.text = "竞速对战 · 最佳%d分" % int(game.progression_state.get("race_best_score", 0))
	elif game.special_mode == "stack":
		game.subtitle_label.text = "叠层模式 · 最佳%d分" % int(game.progression_state.get("stack_best_score", 0))
	elif game.special_mode == "gravity":
		game.subtitle_label.text = "重力模式 · 最佳%d分" % int(game.progression_state.get("gravity_best_score", 0))
	elif game.special_mode == "fog":
		game.subtitle_label.text = "迷雾模式 · 最佳%d分" % int(game.progression_state.get("fog_best_score", 0))
	elif game.special_mode == "chain":
		game.subtitle_label.text = "锁链模式 · 最佳%d分" % int(game.progression_state.get("chain_best_score", 0))
	else:
		game.subtitle_label.text = "第" + str(level_id) + "/" + str(game.campaign_levels.size()) + "关 · " + level_name + " · 已解锁" + str(unlocked_level_count) + "/" + str(game.campaign_levels.size())
	game.desc_label.text = description

	game.status_chip_label.text = game._status_label(game.stage_status)
	# Update status chip style based on status
	var status_style = StyleBoxFlat.new()
	status_style.set_corner_radius_all(16)
	if game.stage_status == game.STATUS_PLAYING:
		game.status_chip_label.add_color_override("font_color", Color("0ca678"))
		status_style.bg_color = Color("e6fcf5")
	elif game.stage_status == game.STATUS_PAUSED:
		game.status_chip_label.add_color_override("font_color", Color("e67700"))
		status_style.bg_color = Color("fff3bf")
	elif game.stage_status == game.STATUS_CLEARED:
		game.status_chip_label.add_color_override("font_color", Color("e64980"))
		status_style.bg_color = Color("ffe3ef")
	elif game.stage_status == game.STATUS_FAILED:
		game.status_chip_label.add_color_override("font_color", Color("f06565"))
		status_style.bg_color = Color("ffe3e3")
	else:
		game.status_chip_label.add_color_override("font_color", Color("0ca678"))
		status_style.bg_color = Color("e6fcf5")
	game.status_chip_label.add_stylebox_override("normal", status_style)

	game.mode_chip_label.text = "模式：" + game._mode_label(mode)
	game.kinds_chip_label.text = "图案种类：" + str(level.get("kinds", 0))

	game.level_progress_bar.value = (float(game.level_index + 1) / float(max(1, game.campaign_levels.size()))) * 100.0
	if game.special_mode != "":
		game.level_progress_bar.value = 100.0

	game._set_stat_text("total_score", str(game.total_score))
	game._set_stat_text("level_score", str(game.level_score))
	game._set_stat_text("moves", str(game.moves))
	game._set_stat_text("remaining", str(game._remaining_tiles_count() / 2))
	game._set_stat_text("time_left", "∞" if int(game._current_level().get("time_limit", 90)) <= 0 else game._format_time(game.time_left))
	game._set_stat_text("combo", "x" + str(max(game.combo, 1)))
	game._set_stat_text("best_total_score", str(game._progress_best_score()))
	game._set_stat_text("best_combo", "x" + str(game._progress_best_combo()))

	# 对手 card only shows during the AI race.
	if game.stat_values.has("race"):
		game.stat_values["race"]["card"].visible = game.special_mode == "race"
		game._set_stat_text("race", "%d/%d" % [game.race_ai_pairs, game.race_total_pairs])

	game._update_fog()
	game._set_time_card_state(game._is_time_danger())

	var input_enabled = game.stage_status == game.STATUS_PLAYING
	game.hint_button.disabled = not input_enabled
	game.auto_button.disabled = not input_enabled
	game.shuffle_button.disabled = not input_enabled
	if game.level_select_option:
		game.level_select_option.disabled = game.campaign_levels.size() <= 1
	var selected_level_index = game._selected_level_option_index()
	var can_jump = selected_level_index != game.level_index and game._is_level_unlocked(selected_level_index)
	if game.jump_level_button:
		game.jump_level_button.disabled = not can_jump
	if game.clear_progress_button:
		game.clear_progress_button.disabled = false
	var pause_enabled = game.stage_status == game.STATUS_PLAYING or game.stage_status == game.STATUS_PAUSED
	game.pause_button.disabled = not pause_enabled
	game.pause_button.text = "继续" if game.stage_status == game.STATUS_PAUSED else "暂停"

	if game.stage_status == game.STATUS_COMPLETED:
		game.reset_button.text = "再来一轮"
	else:
		game.reset_button.text = "重开"

	# Update power-ups display
	game._update_power_ups_display()

# --- Timers and message/banner helpers (migrated from game.gd) ---

static func _show_message(game, text, duration_sec = 1.0):
	game.message_label.text = text
	game.message_label.visible = true
	game.message_timer.stop()
	game.message_timer.wait_time = max(0.1, duration_sec)
	game.message_timer.start()

static func _hide_message(game):
	game.message_label.visible = false
	game.message_timer.stop()

static func _show_stage_callout(game, text, color, font_size):
	var label = Label.new()
	label.text = text
	label.add_font_override("font", game._font_at_size(font_size))
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.set_anchors_and_margins_preset(Control.PRESET_TOP_WIDE)
	label.margin_top = 150
	label.margin_left = 0
	label.margin_right = 0
	label.margin_bottom = 190
	label.modulate = Color(1, 1, 1, 0.0)
	label.add_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(label)

	var tween = game._make_fx_tween(label)
	tween.interpolate_property(label, "margin_top", 150.0, 116.0, 0.35, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(label, "modulate:a", 0.0, 0.95, 0.2, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(label, "modulate:a", 0.95, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.1)
	tween.start()


# --- Control factories and notifications (migrated from game.gd) ---

static func _create_control_button(game, text):
	var button = Button.new()
	button.add_font_override("font", game.game_font)
	button.text = text
	button.rect_min_size = Vector2(88, 42)
	button.add_color_override("font_color", Color("ffffff"))

	# Apply gradient button style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("f06ba8")
	normal.set_corner_radius_all(20)
	normal.shadow_color = Color("f06ba840")
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color("ff9ec4")
	hover.set_corner_radius_all(20)
	hover.shadow_color = Color("f06ba860")
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 4)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color("d6336c")
	pressed.set_corner_radius_all(20)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.connect("pressed", AudioManager, "play_button_click")

	return button

static func _populate_level_select_options(game):
	if game.level_select_option == null:
		return

	game.level_select_option.clear()
	var best_times = game.progression_state.get("level_best_times", {})
	for i in range(game.campaign_levels.size()):
		var level: Dictionary = game.campaign_levels[i]
		var level_id = int(level.get("id", i + 1))
		var level_name = str(level.get("name", "关卡"))
		var unlocked = game._is_level_unlocked(i)
		var label = "第" + str(level_id) + "关 · " + level_name
		# Add best time if available
		if best_times.has(str(i)):
			var best_time = float(best_times[str(i)])
			label += " ⏱️" + game._format_time_seconds(best_time)
		if not unlocked:
			label += "（未解锁）"
		game.level_select_option.add_item(label)
		game.level_select_option.set_item_disabled(i, not unlocked)

	game.level_select_option.disabled = game.campaign_levels.size() <= 1
	game._sync_level_select_selection()

static func _show_achievement_notification(game, achievement_name):
	# Create floating achievement notification
	var notification = PanelContainer.new()
	notification.set_anchors_and_margins_preset(Control.PRESET_CENTER_TOP)
	notification.margin_top = 60
	game._apply_glass_style(notification, Color("fff3bf"), 0.95)
	game.add_child(notification)

	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 8)
	notification.add_child(hbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 16)
	margin.add_constant_override("margin_right", 16)
	margin.add_constant_override("margin_top", 12)
	margin.add_constant_override("margin_bottom", 12)
	hbox.add_child(margin)

	var label = Label.new()
	label.text = "🏆 成就解锁：" + achievement_name
	label.add_color_override("font_color", Color("d6336c"))
	label.add_font_override("font", game.game_font)
	margin.add_child(label)

	# Auto-dismiss after animation
	var dismiss_timer = Timer.new()
	dismiss_timer.one_shot = true
	dismiss_timer.wait_time = 2.5
	dismiss_timer.connect("timeout", game, "_on_achievement_dismiss", [notification])
	game.add_child(dismiss_timer)
	dismiss_timer.start()


static func _status_label(game, status):
	match status:
		game.STATUS_PLAYING:
			return "进行中"
		game.STATUS_PAUSED:
			return "已暂停"
		game.STATUS_CLEARED:
			return "过关中"
		game.STATUS_FAILED:
			return "失败"
		game.STATUS_COMPLETED:
			return "全通关"
		_:
			return "未知"


# --- Level select state glue (migrated from game.gd) ---

static func _selected_level_option_index(game):
	if game.level_select_option == null or game.level_select_option.get_item_count() == 0:
		return game.level_index
	var selected_idx = int(game.level_select_option.get_selected_id())
	if selected_idx < 0:
		selected_idx = game.level_index
	return clamp(selected_idx, 0, game.campaign_levels.size() - 1)


static func _sync_level_select_selection(game):
	if game.level_select_option == null or game.level_select_option.get_item_count() == 0:
		return
	game.level_select_option.select(game.level_index)


static func _level_label_by_index(game, level_idx):
	var clamped = clamp(level_idx, 0, game.campaign_levels.size() - 1)
	var level: Dictionary = game.campaign_levels[clamped]
	return "第" + str(int(level.get("id", clamped + 1))) + "关 · " + str(level.get("name", "关卡"))


static func _on_level_select_changed(game, index):
	if not game._is_level_unlocked(index):
		game._sync_level_select_selection()
		game._show_message("该关卡尚未解锁", 0.9)
		return
	game._refresh_ui()


static func _trigger_level_highlight(game):
	if game.level_select_option == null:
		return
	game.level_select_option.modulate = game.LEVEL_HIGHLIGHT_COLOR
	game.level_highlight_timer.stop()
	game.level_highlight_timer.wait_time = 0.4
	game.level_highlight_timer.start()


# --- Combo progress bar state (migrated from game.gd) ---

static func _reset_combo(game):
	game.combo = 0
	game.combo_expires_ms = 0
	game.combo_progress_bar.value = 0
	game.combo_reset_timer.stop()


static func _update_combo_progress(game):
	if game.stage_status != game.STATUS_PLAYING or game.combo <= 0:
		game.combo_progress_bar.value = 0
		return

	var remain = max(0, game.combo_expires_ms - OS.get_ticks_msec())
	var window_ms = max(1, int(game.tuning.get("combo_window_ms", 2600)))
	var progress = (float(remain) / float(window_ms)) * 100.0
	game.combo_progress_bar.value = progress

