extends Reference

# 弹窗框架 + 强上下文面板：shell/挂载/开合生命周期、暂停面板、攀登树
# 增益三选一。偏好类弹窗（引导/设置/数据迁移）与图集选项粘合在
# ui_preferences.gd（经 game.UI_PANELS 复用 _modal_content_shell）。
# Each builder takes the game node: signals bind to game methods and game
# members (fonts, style helpers, progression state) are accessed via game.<x>.

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")


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

# 成就展示已升级为一等页面（page_router._build_achievements），弹窗工厂退役。

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
# 继续是唯一主按钮（实心玫瑰）；其余白卡次按钮——面板读得出主次而非一墙粉。
# 暂停面板按钮表：文案 + 回调 + 主/次样式；主按钮（继续）排首位。
const PAUSE_BUTTONS = [
	{"text": "▶️ 继续游戏 (P)", "action": "_resume_stage", "primary": true},
	{"text": "🔄 重新开始", "action": "_on_restart_current_level"},
	{"text": "🏠 返回第1关", "action": "_on_back_to_first_level"},
	# 首页入口：标题页随时可达（棋盘头部不放按钮，保住棋盘 ≥92% 高度契约）。
	{"text": "🌸 回到首页", "action": "_on_pause_home_pressed"},
]

static func _pause_buttons(game, content):
	for spec in PAUSE_BUTTONS:
		content.add_child(_pause_button(game, spec))
	# Exit special session button (daily / time attack / endless)
	game.pause_exit_button = _pause_button(game, {"text": "🚪 返回关卡模式", "action": "_on_exit_special_pressed"})
	game.pause_exit_button.visible = false
	content.add_child(game.pause_exit_button)

static func _pause_button(game, spec):
	var button = Button.new()
	button.text = str(spec["text"])
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.rect_min_size = Vector2(0, 44)
	button.add_font_override("font", game.game_font)
	button.connect("pressed", game, str(spec["action"]))
	if bool(spec.get("primary", false)):
		UI_STYLE.style_dialog_buttons(button)
	else:
		UI_STYLE.style_secondary_button(button)
	return button



static func _update_modal_panel_sizes(game, viewport_size, is_portrait):
	var max_width = viewport_size.x * 0.92
	var max_height = viewport_size.y * (0.90 if is_portrait else 0.82)

	if game.onboarding_panel:
		game.onboarding_panel.rect_min_size = Vector2(min(320.0, max_width), min(400.0, max_height))
	if game.settings_panel:
		game.settings_panel.rect_min_size = Vector2(min(360.0, max_width), min(320.0, max_height))
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


# 成就展示已升级为一等页面（page_router._build_achievements），弹窗工厂与
# reopen 生命周期（页面每次 route 都重建）一并退役。

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
