extends Reference

# 偏好面板族（ui_panels 的内容分册）：新玩家引导、设置、数据迁移三块
# 「偏好类」弹窗的工厂，以及图集选项与音效/语音开关的粘合。弹窗框架
# （shell/挂载/开合生命周期）与暂停、攀登树增益面板留在 ui_panels.gd；
# 框架壳经 game.UI_PANELS._modal_content_shell 复用。

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

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
	title.text = "🎮 欢迎来到 Sophia的连连看"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	_onboarding_sections(game, content)

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

# 玩法说明三段。
static func _onboarding_sections(game, content):
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

static func _settings_panel(game):
	game.settings_panel = PanelContainer.new()
	var content = game.UI_PANELS._modal_content_shell(game, game.settings_panel, Vector2(360, 320), 16)

	# Title
	var title = Label.new()
	title.text = "⚙️ 设置"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	_settings_audio_rows(game, content)
	_settings_feature_entries(game, content)
	_settings_page_entries(game, content)

	# 产品身份行：版本随 GAME_VERSION 单点更新，用户反馈/排查有据可依。
	var version_label = Label.new()
	version_label.text = "🌸 Sophia的连连看 v%s" % game.GAME_VERSION
	version_label.align = Label.ALIGN_CENTER
	version_label.add_font_override("font", game._font_at_size(11))
	version_label.add_color_override("font_color", Color("c2a3b2"))
	content.add_child(version_label)

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
	# Brand sweep: every settings action is a companion entry — all secondary.
	UI_STYLE.style_all_secondary_buttons(game.settings_panel)

# Volume + four toggles, every row wired to its settings callback.
static func _settings_audio_rows(game, content):
	# Master volume
	var master_row = _create_volume_row(game, "主音量", game.audio.master_volume)
	master_row.slider.connect("value_changed", game, "_on_master_volume_changed")
	content.add_child(master_row.container)

	# Effects enabled
	var effects_row = _create_toggle_row(game, "音效", game.audio.effects_enabled)
	effects_row.toggle.connect("toggled", game, "_on_effects_toggled")
	content.add_child(effects_row.container)

	# Voice lines enabled
	var voice_row = _create_toggle_row(game, "语音", game.audio.voice_enabled)
	voice_row.toggle.connect("toggled", game, "_on_voice_toggled")
	content.add_child(voice_row.container)

	# Music enabled
	var music_row = _create_toggle_row(game, "背景音乐", game.audio.music_enabled)
	music_row.toggle.connect("toggled", game, "_on_music_toggled")
	content.add_child(music_row.container)

	# Mute all
	var mute_row = _create_toggle_row(game, "静音", game.audio.muted)
	mute_row.toggle.connect("toggled", game, "_on_mute_toggled")
	content.add_child(mute_row.container)

# Feature entries: the board-first toolbar has no room for these two,
# so they live here — nothing is ever out of reach.
static func _settings_feature_entries(game, content):
	var stats_entry = Button.new()
	stats_entry.text = "📊 数据统计"
	stats_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_entry.rect_min_size = Vector2(0, 40)
	stats_entry.add_font_override("font", game.game_font)
	stats_entry.connect("pressed", game, "_on_settings_stats_entry")
	content.add_child(stats_entry)

	var achievements_entry = Button.new()
	achievements_entry.text = "🏆 成就图鉴"
	achievements_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements_entry.rect_min_size = Vector2(0, 40)
	achievements_entry.add_font_override("font", game.game_font)
	achievements_entry.connect("pressed", game, "_on_settings_achievements_entry")
	content.add_child(achievements_entry)

	var tree_entry = Button.new()
	tree_entry.text = "🌳 攀登大树"
	tree_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_entry.rect_min_size = Vector2(0, 40)
	tree_entry.add_font_override("font", game.game_font)
	tree_entry.connect("pressed", game, "_on_settings_tree_entry")
	content.add_child(tree_entry)

	var migration_entry = Button.new()
	migration_entry.text = "🔀 数据迁移"
	migration_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	migration_entry.rect_min_size = Vector2(0, 40)
	migration_entry.add_font_override("font", game.game_font)
	migration_entry.connect("pressed", game, "_on_settings_migration_entry")
	content.add_child(migration_entry)

	var editor_entry = Button.new()
	editor_entry.text = "🎨 关卡工坊"
	editor_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_entry.rect_min_size = Vector2(0, 40)
	editor_entry.add_font_override("font", game.game_font)
	editor_entry.connect("pressed", game, "_on_editor_open_pressed")
	content.add_child(editor_entry)

# Page entries: desktop hides the nav bar on the chrome-free home board,
# so the meta pages stay reachable from settings (ids match page_router).
static func _settings_page_entries(game, content):
	var page_entries = [
		["🗺️ 旅程地图", "level_map"],
		["📖 图鉴收集", "collection"],
		["🎁 每日有礼", "signin"],
		["🎉 活动日历", "events"],
		["🛍️ 樱花小铺", "shop"],
	]
	for entry in page_entries:
		var button = Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.rect_min_size = Vector2(0, 40)
		button.add_font_override("font", game.game_font)
		button.connect("pressed", game, "_on_settings_page_entry", [entry[1]])
		content.add_child(button)

# 数据迁移面板：规则文案 + 旧设备生成段 / 新设备认领段 + 关闭。
static func _migration_panel(game):
	game.migration_panel = PanelContainer.new()
	var content = game.UI_PANELS._modal_content_shell(game, game.migration_panel, Vector2(360, 0), 12)

	var title = Label.new()
	title.text = "🔀 数据迁移"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	var rules = Label.new()
	rules.text = "把进度搬到新设备：旧设备点「生成迁移码」，新设备输入同一口令。\n口令 10 分钟内有效、用一次即作废，操作时两台设备都停在本页。"
	rules.autowrap = true
	rules.add_color_override("font_color", Color("8a6b7a"))
	content.add_child(rules)

	_migration_generate_section(game, content)
	_migration_claim_section(game, content)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.rect_min_size = Vector2(0, 44)
	close_button.add_font_override("font", game.game_font)
	close_button.connect("pressed", game, "_on_settings_migration_close")
	content.add_child(close_button)
	UI_STYLE.style_secondary_button(close_button)

static func _migration_generate_section(game, content):
	var generate_button = Button.new()
	generate_button.text = "🔑 生成迁移码（旧设备）"
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_button.rect_min_size = Vector2(0, 40)
	generate_button.add_font_override("font", game.game_font)
	generate_button.connect("pressed", game, "_on_migration_generate_pressed")
	content.add_child(generate_button)
	UI_STYLE.style_dialog_buttons(generate_button)

	game.migration_code_label = Label.new()
	game.migration_code_label.align = Label.ALIGN_CENTER
	game.migration_code_label.add_color_override("font_color", Color("d4568c"))
	content.add_child(game.migration_code_label)

static func _migration_claim_section(game, content):
	var hint = Label.new()
	hint.text = "本机是新设备？输入旧设备显示的迁移码："
	hint.autowrap = true
	hint.add_color_override("font_color", Color("8a6b7a"))
	content.add_child(hint)

	game.migration_input = LineEdit.new()
	game.migration_input.placeholder_text = "例如 7K2M-9QPA"
	game.migration_input.max_length = 32
	game.migration_input.add_font_override("font", game.game_font)
	content.add_child(game.migration_input)

	var claim_button = Button.new()
	claim_button.text = "✅ 开始迁移（新设备）"
	claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_button.rect_min_size = Vector2(0, 40)
	claim_button.add_font_override("font", game.game_font)
	claim_button.connect("pressed", game, "_on_migration_claim_pressed")
	content.add_child(claim_button)
	UI_STYLE.style_dialog_buttons(claim_button)

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

static func _populate_icon_set_options(game):
	game.icon_set_option.clear()
	for i in range(game.icon_sets.size()):
		var icon_set: Dictionary = game.icon_sets[i]
		game.icon_set_option.add_item(icon_set.get("name", "主题" + str(i + 1)))

	if game.icon_sets.size() > 0:
		game.icon_set_index = clamp(game.icon_set_index, 0, game.icon_sets.size() - 1)
		game.icon_set_option.select(game.icon_set_index)


static func _on_icon_set_selected(game, index):
	game.icon_set_index = clamp(index, 0, max(0, game.icon_sets.size() - 1))
	game._refresh_board_visuals()


static func _on_effects_toggled(game, enabled):
	game.audio.set_effects_enabled(enabled)


static func _on_voice_toggled(game, enabled):
	game.audio.set_voice_enabled(enabled)
