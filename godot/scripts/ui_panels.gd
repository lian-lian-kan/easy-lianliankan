extends Reference

# UI panel factories extracted from game.gd (Round D). Each builder
# takes the game node: signals bind to game methods and game members
# (fonts, style helpers, progression state) are accessed via game.<x>.

static func _onboarding_panel(game):
	game.onboarding_panel = PanelContainer.new()
	game.onboarding_panel.rect_min_size = Vector2(320, 400)
	game.onboarding_panel.visible = false
	game._apply_glass_style(game.onboarding_panel, Color("ffffff"), 0.95)
	game._mount_modal_panel(game.onboarding_panel)

	var vbox = VBoxContainer.new()
	game.onboarding_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 20)
	margin.add_constant_override("margin_right", 20)
	margin.add_constant_override("margin_top", 20)
	margin.add_constant_override("margin_bottom", 20)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 12)
	margin.add_child(content)

	var title = Label.new()
	title.text = "🎮 欢迎来到连连看"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	var sections = [
		{"title": "🎯 基本玩法", "content": "点击两个相同图案进行连接消除。路径最多可以拐弯 2 次。"},
		{"title": "🔓 解锁规则", "content": "完成当前关卡即可解锁下一关。已解锁的关卡可以随时切换挑战。"},
		{"title": "⌨️ 快捷键", "content": "H - 提示  |  A - 自动消除  |  S - 洗牌\nR - 重置  |  P - 暂停  |  [ / ] - 切换关卡"}
	]

	for section in sections:
		var section_title = Label.new()
		section_title.text = section.title
		section_title.add_color_override("font_color", Color("7a5064"))
		section_title.add_font_override("font", game.game_font)
		content.add_child(section_title)

		var section_content = Label.new()
		section_content.text = section.content
		section_content.autowrap = true
		section_content.add_color_override("font_color", Color("8f6b80"))
		section_content.add_font_override("font", game.game_font)
		content.add_child(section_content)

	var spacer = Control.new()
	spacer.rect_min_size = Vector2(0, 8)
	content.add_child(spacer)

	var got_it_button = Button.new()
	got_it_button.text = "知道了，开始游戏"
	got_it_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	got_it_button.rect_min_size = Vector2(0, 44)
	got_it_button.add_font_override("font", game.game_font)
	got_it_button.connect("pressed", game, "_on_onboarding_dismissed")
	content.add_child(got_it_button)
	game._style_dialog_buttons(game.onboarding_panel)

static func _settings_panel(game):
	game.settings_panel = PanelContainer.new()
	game.settings_panel.rect_min_size = Vector2(360, 320)
	game.settings_panel.visible = false
	game._apply_glass_style(game.settings_panel, Color("ffffff"), 0.95)
	game._mount_modal_panel(game.settings_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 16)
	game.settings_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 16)
	margin.add_child(content)

	# Title
	var title = Label.new()
	title.text = "⚙️ 设置"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	# Master volume
	var master_row = _create_volume_row(game, "主音量", AudioManager.master_volume)
	master_row.slider.connect("value_changed", game, "_on_master_volume_changed")
	content.add_child(master_row.container)

	# Effects enabled
	var effects_row = _create_toggle_row(game, "音效", AudioManager.effects_enabled)
	effects_row.toggle.connect("toggled", game, "_on_effects_toggled")
	content.add_child(effects_row.container)

	# Music enabled
	var music_row = _create_toggle_row(game, "背景音乐", AudioManager.music_enabled)
	music_row.toggle.connect("toggled", game, "_on_music_toggled")
	content.add_child(music_row.container)

	# Mute all
	var mute_row = _create_toggle_row(game, "静音", AudioManager.muted)
	mute_row.toggle.connect("toggled", game, "_on_mute_toggled")
	content.add_child(mute_row.container)

	var spacer = Control.new()
	spacer.rect_min_size = Vector2(0, 8)
	content.add_child(spacer)

	# Close button
	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.rect_min_size = Vector2(0, 44)
	close_button.add_font_override("font", game.game_font)
	close_button.connect("pressed", game, "_on_settings_close")
	content.add_child(close_button)

static func _create_volume_row(game, label_text, initial_value):
	var container = HBoxContainer.new()
	container.add_constant_override("separation", 12)

	var label = Label.new()
	label.text = label_text
	label.rect_min_size = Vector2(80, 0)
	label.add_color_override("font_color", Color("7a5064"))
	label.add_font_override("font", game.game_font)
	container.add_child(label)

	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	container.add_child(slider)

	return {"container": container, "slider": slider}

static func _create_toggle_row(game, label_text, initial_value):
	var container = HBoxContainer.new()
	container.add_constant_override("separation", 12)

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_color_override("font_color", Color("7a5064"))
	label.add_font_override("font", game.game_font)
	container.add_child(label)

	var toggle = CheckBox.new()
	toggle.pressed = initial_value
	container.add_child(toggle)

	return {"container": container, "toggle": toggle}

static func _achievements_panel(game):
	game.achievements_panel = PanelContainer.new()
	game.achievements_panel.rect_min_size = Vector2(400, 480)
	game.achievements_panel.visible = false
	game._apply_glass_style(game.achievements_panel, Color("ffffff"), 0.95)
	game._mount_modal_panel(game.achievements_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 16)
	game.achievements_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 12)
	margin.add_child(content)

	# Title
	var title = Label.new()
	title.text = "🏆 成就"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	# Achievement list
	var achievements_list = VBoxContainer.new()
	achievements_list.add_constant_override("separation", 10)
	content.add_child(achievements_list)

	for achievement in game.PROGRESSION_SCRIPT.ACHIEVEMENTS:
		var item = _create_achievement_item(game, achievement)
		achievements_list.add_child(item)

	var spacer = Control.new()
	spacer.rect_min_size = Vector2(0, 8)
	content.add_child(spacer)

	# Close button
	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.rect_min_size = Vector2(0, 44)
	close_button.add_font_override("font", game.game_font)
	close_button.connect("pressed", game, "_on_achievements_close")
	content.add_child(close_button)

static func _create_achievement_item(game, achievement):
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 12)

	var unlocked = game.PROGRESSION_SCRIPT.has_achievement(game.progression_state, achievement["id"])

	# Icon
	var icon_label = Label.new()
	icon_label.text = "🏆" if unlocked else "🔒"
	hbox.add_child(icon_label)

	# Text content
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label = Label.new()
	name_label.text = achievement["name"]
	name_label.add_color_override("font_color", Color("059669" if unlocked else "94a3b8"))
	name_label.add_font_override("font", game.game_font)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = achievement["desc"]
	desc_label.add_color_override("font_color", Color("64748b" if unlocked else "cbd5e1"))
	desc_label.add_font_override("font", game.game_font)
	vbox.add_child(desc_label)

	return hbox

static func _pause_panel(game):
	game.pause_panel = PanelContainer.new()
	game.pause_panel.rect_min_size = Vector2(320, 280)
	game.pause_panel.visible = false
	game._apply_glass_style(game.pause_panel, Color("ffffff"), 0.98)
	game._mount_modal_panel(game.pause_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 12)
	game.pause_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 12)
	margin.add_child(content)

	# Title
	var title = Label.new()
	title.text = "⏸️ 游戏暂停"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	# Level info
	var level_info = Label.new()
	level_info.text = "当前关卡"
	level_info.align = Label.ALIGN_CENTER
	level_info.add_color_override("font_color", Color("8f6b80"))
	level_info.add_font_override("font", game.game_font)
	content.add_child(level_info)

	var line = HSeparator.new()
	content.add_child(line)

	# Resume button
	var resume_button = Button.new()
	resume_button.text = "▶️ 继续游戏 (P)"
	resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_button.rect_min_size = Vector2(0, 44)
	resume_button.add_font_override("font", game.game_font)
	resume_button.connect("pressed", game, "_resume_stage")
	content.add_child(resume_button)

	# Restart button
	var restart_button = Button.new()
	restart_button.text = "🔄 重新开始"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.rect_min_size = Vector2(0, 44)
	restart_button.add_font_override("font", game.game_font)
	restart_button.connect("pressed", game, "_on_restart_current_level")
	content.add_child(restart_button)

	# Back to level 1 button
	var back_button = Button.new()
	back_button.text = "🏠 返回第1关"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.rect_min_size = Vector2(0, 44)
	back_button.add_font_override("font", game.game_font)
	back_button.connect("pressed", game, "_on_back_to_first_level")
	content.add_child(back_button)

	# Exit special session button (daily / time attack / endless)
	game.pause_exit_button = Button.new()
	game.pause_exit_button.text = "🚪 返回关卡模式"
	game.pause_exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.pause_exit_button.rect_min_size = Vector2(0, 44)
	game.pause_exit_button.add_font_override("font", game.game_font)
	game.pause_exit_button.connect("pressed", game, "_on_exit_special_pressed")
	game.pause_exit_button.visible = false
	content.add_child(game.pause_exit_button)

static func _modes_panel(game):
	game.modes_panel = PanelContainer.new()
	game.modes_panel.rect_min_size = Vector2(340, 640)
	game.modes_panel.visible = false
	game._apply_glass_style(game.modes_panel, Color("ffffff"), 0.95)
	game._mount_modal_panel(game.modes_panel)

	var vbox = VBoxContainer.new()
	game.modes_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 20)
	margin.add_constant_override("margin_right", 20)
	margin.add_constant_override("margin_top", 20)
	margin.add_constant_override("margin_bottom", 20)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 10)
	margin.add_child(content)

	var title = Label.new()
	title.text = "🎮 玩法模式"
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", game.game_font)
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	# Mode rows are rebuilt on every open; keep them in a dedicated box.
	# ScrollContainer keeps thirteen mode cards usable on short screens.
	var rows_scroll = ScrollContainer.new()
	rows_scroll.scroll_horizontal_enabled = false
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(rows_scroll)
	var rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_constant_override("separation", 7)
	rows_scroll.add_child(rows_box)

	var spacer = Control.new()
	spacer.rect_min_size = Vector2(0, 6)
	content.add_child(spacer)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.rect_min_size = Vector2(0, 44)
	close_button.add_font_override("font", game.game_font)
	close_button.connect("pressed", game, "_on_modes_close_pressed")
	content.add_child(close_button)
	game._style_dialog_buttons(game.modes_panel)
