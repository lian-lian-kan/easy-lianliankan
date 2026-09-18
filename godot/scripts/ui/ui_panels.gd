extends Reference

# UI panel factories extracted from game.gd (Round D). Each builder
# takes the game node: signals bind to game methods and game members
# (fonts, style helpers, progression state) are accessed via game.<x>.

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

# Shared modal shell: glass panel mounted on the game, a 24px padded margin
# and the content box the panel body renders into.
static func _modal_content_shell(game, panel, min_size, content_separation):
	panel.rect_min_size = min_size
	panel.visible = false
	game._apply_glass_style(panel, Color("ffffff"), 0.95)
	game._mount_modal_panel(panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 16)
	panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", content_separation)
	margin.add_child(content)
	return content

static func _settings_panel(game):
	game.settings_panel = PanelContainer.new()
	var content = _modal_content_shell(game, game.settings_panel, Vector2(360, 320), 16)

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
	var content = _modal_content_shell(game, game.migration_panel, Vector2(360, 0), 12)

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

static func _migration_generate_section(game, content):
	var generate_button = Button.new()
	generate_button.text = "🔑 生成迁移码（旧设备）"
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_button.rect_min_size = Vector2(0, 40)
	generate_button.add_font_override("font", game.game_font)
	generate_button.connect("pressed", game, "_on_migration_generate_pressed")
	content.add_child(generate_button)

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
	var content = _modal_content_shell(game, game.achievements_panel, Vector2(400, 480), 12)

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

	for achievement in game.PROGRESSION_SCRIPT.get_achievement_definitions():
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

	_pause_buttons(game, content)


# 继续重开返回三键 + 特殊会话的退出键（默认隐藏）。
static func _pause_buttons(game, content):
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

	# 首页入口：标题页随时可达（棋盘头部不放按钮，保住棋盘 ≥92% 高度契约）。
	var home_button = Button.new()
	home_button.text = "🌸 回到首页"
	home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_button.rect_min_size = Vector2(0, 44)
	home_button.add_font_override("font", game.game_font)
	home_button.connect("pressed", game, "_on_pause_home_pressed")
	content.add_child(home_button)

	# Exit special session button (daily / time attack / endless)
	game.pause_exit_button = Button.new()
	game.pause_exit_button.text = "🚪 返回关卡模式"
	game.pause_exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.pause_exit_button.rect_min_size = Vector2(0, 44)
	game.pause_exit_button.add_font_override("font", game.game_font)
	game.pause_exit_button.connect("pressed", game, "_on_exit_special_pressed")
	game.pause_exit_button.visible = false
	content.add_child(game.pause_exit_button)


# --- Shared style helpers (migrated from game.gd) ---

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


static func _update_modal_panel_sizes(game, viewport_size, is_portrait):
	var max_width = viewport_size.x * 0.92
	var max_height = viewport_size.y * (0.90 if is_portrait else 0.82)

	if game.onboarding_panel:
		game.onboarding_panel.rect_min_size = Vector2(min(320.0, max_width), min(400.0, max_height))
	if game.settings_panel:
		game.settings_panel.rect_min_size = Vector2(min(360.0, max_width), min(320.0, max_height))
	if game.achievements_panel:
		game.achievements_panel.rect_min_size = Vector2(min(400.0, max_width), min(480.0, max_height))
	if game.pause_panel:
		game.pause_panel.rect_min_size = Vector2(min(320.0, max_width), min(280.0, max_height))
	if game.tree_buff_panel:
		game.tree_buff_panel.rect_min_size = Vector2(min(360.0, max_width), 0)


static func _mount_modal_panel(game, panel):
	var holder = CenterContainer.new()
	holder.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(holder)
	holder.add_child(panel)
	return holder


# --- Modal lifecycle (migrated from game.gd) ---
# Opening a modal pauses the stage clock; closing it resumes — but only from
# the pause this modal caused (a failed/finished stage is never force-resumed).
# The modes browser is browse-only and uses the game's plain show/hide pair.

static func open_modal(game, panel):
	if panel == null:
		return
	panel.visible = true
	if game.stage_status == game.STATUS_PLAYING:
		game.stage_status = game.STATUS_PAUSED
		if game.second_timer:
			game.second_timer.stop()


static func close_modal(game, panel):
	if panel == null:
		return
	panel.visible = false
	if game.stage_status == game.STATUS_PAUSED:
		game.stage_status = game.STATUS_PLAYING
		if game.second_timer:
			game.second_timer.start()


static func reopen_achievements(game):
	# Rebuild the list so unlock states reflect the current progression.
	# Free the whole old holder: the factory mounts a fresh holder+panel, and
	# freeing only the old panel children leaked the holder on every reopen.
	if game.achievements_panel == null:
		return
	var old_holder = game.achievements_panel.get_parent()
	if old_holder != null:
		old_holder.queue_free()
	game._build_achievements_panel()



static func _tree_buff_panel(game):
	game.tree_buff_panel = PanelContainer.new()
	var content = _modal_content_shell(game, game.tree_buff_panel, Vector2(360, 0), 12)

	var title = Label.new()
	title.text = "🌳 层间休整 · 三选一增益"
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", game.game_font)
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	game.tree_buff_options = VBoxContainer.new()
	game.tree_buff_options.add_constant_override("separation", 10)
	content.add_child(game.tree_buff_options)

	var skip_button = Button.new()
	skip_button.text = "跳过，直接继续攀登"
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_button.rect_min_size = Vector2(0, 44)
	skip_button.add_font_override("font", game.game_font)
	skip_button.connect("pressed", game, "_on_tree_buff_skipped")
	content.add_child(skip_button)
	game._style_dialog_buttons(game.tree_buff_panel)


static func offer_tree_buffs(game):
	if game.tree_buff_panel == null:
		_tree_buff_panel(game)
	_refresh_tree_buff_options(game)
	game.tree_buff_panel.visible = true


static func hide_tree_buff_panel(game):
	if game.tree_buff_panel:
		game.tree_buff_panel.visible = false


static func _refresh_tree_buff_options(game):
	for child in game.tree_buff_options.get_children():
		game.tree_buff_options.remove_child(child)
		child.queue_free()
	for buff_id in game.tree_pending_buffs:
		var buff = game.TREE_BUFFS.buff_by_id(buff_id)
		if buff.empty():
			continue
		var button = Button.new()
		button.text = "%s %s\n%s" % [str(buff["icon"]), str(buff["name"]), str(buff["desc"])]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.rect_min_size = Vector2(0, 52)
		button.add_font_override("font", game.game_font)
		button.connect("pressed", game, "_on_tree_buff_picked", [str(buff["id"])])
		game._style_dialog_buttons(button)
		game.tree_buff_options.add_child(button)


static func refresh_pause_panel(game):
	# The pause panel shows the current level (or special session) and the
	# exit button only during special sessions; pause/resume semantics stay
	# with session._pause_stage/_resume_stage.
	if game.pause_panel == null:
		return
	var vbox = game.pause_panel.get_child(0)
	var margin = vbox.get_child(0)
	var content = margin.get_child(0)
	var level_info = content.get_child(1) as Label
	var level = game._current_level()
	if game._is_special_session():
		level_info.text = str(level.get("name", "特殊模式")) + " · " + game._mode_label(game.special_mode)
	else:
		var level_id = int(level.get("id", game.level_index + 1))
		var level_name = str(level.get("name", "关卡"))
		level_info.text = "第" + str(level_id) + "关 - " + level_name
	if game.pause_exit_button:
		game.pause_exit_button.visible = game._is_special_session()
	game.pause_panel.visible = true


static func hide_pause_panel(game):
	if game.pause_panel:
		game.pause_panel.visible = false



static func restart_current_level(game):
	hide_pause_panel(game)
	if game._is_special_session():
		game._start_special_mode(game.special_mode)
		game._show_message("重新开始挑战", 1.0)
		return
	game._start_level(game.level_index, false)
	game._show_message("重新开始当前关卡", 1.0)


static func back_to_first_level(game):
	hide_pause_panel(game)
	game._start_level(0, true)
	game._show_message("返回第1关", 1.0)
