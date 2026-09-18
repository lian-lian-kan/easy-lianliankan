extends Reference

# 首页（启动标题页）：进游戏先见首页，按下「开始游戏」才落到棋盘。
# 全屏覆盖层，走 open_modal 生命周期（打开即暂停计时、关闭只恢复自己造成
# 的暂停），所以棋盘在下面已就绪、时钟却不会偷跑。快捷入口先收起首页再
# open_page——同一帧内一开一关不成对会互相吃掉暂停态，但 close_modal 与
# show_page 的 open_modal 同步连发，中间没有可计时的帧。

const PAGE_ROUTER = preload("res://scripts/pages/page_router.gd")
const UI_PANELS = preload("res://scripts/ui/ui_panels.gd")

# -s 探针把 Main.tscn 手动 add_child，current_scene 永远为空；真实启动由
# Main::start 在首帧前设 current_scene——以此为「非测试启动」判据，探针
# 无需逐个声明旁路。web 壳在 ?diag=1 / ?nostart=1 时置 LLK_SKIP_START。
static func should_autoshow(game):
	if game.get_tree().current_scene != game:
		return false
	if OS.has_feature("HTML5"):
		var skip = JavaScript.eval("!!(window.LLK_SKIP_START)")
		if skip == true:
			return false
	return true

# 每次显示都重建：樱花币/关卡/图鉴数字永远反映当下存档。
static func show_start_screen(game):
	dispose(game)
	var root = _build(game)
	game.add_child(root)
	game.start_screen_root = root
	game.start_screen_open = true
	UI_PANELS.open_modal(game, root)
	# 开局结算尚未跳关时进入首页，冻结推进，关闭时按 close_page 同款恢复。
	if game.level_advance_timer:
		game.level_advance_timer.stop()

static func dismiss_start_screen(game):
	if not game.start_screen_open or game.start_screen_root == null:
		return
	UI_PANELS.close_modal(game, game.start_screen_root)
	game.start_screen_open = false
	if game.stage_status == game.STATUS_CLEARED and game.pending_level_index >= 0 \
			and game.level_advance_timer:
		game.level_advance_timer.start()

# 首页上的快捷入口：收起首页再开页面，关页后按既有惯例落回棋盘。
static func open_page_from_start(game, page_id):
	dismiss_start_screen(game)
	PAGE_ROUTER.show_page(game, page_id)

static func dispose(game):
	if game.start_screen_root == null:
		return
	game.start_screen_root.queue_free()
	game.start_screen_root = null

static func _build(game):
	var root = ColorRect.new()
	root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.color = Color("ffe9f1")

	var center = CenterContainer.new()
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.add_child(center)

	var box = VBoxContainer.new()
	box.add_constant_override("separation", 14)
	box.rect_min_size = Vector2(300, 0)
	center.add_child(box)

	var emblem = Label.new()
	emblem.text = "🌸 🎀 🌸"
	emblem.align = Label.ALIGN_CENTER
	emblem.add_font_override("font", game._font_at_size(34))
	box.add_child(emblem)

	var title = Label.new()
	title.text = "Sophia的连连看"
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", game._font_at_size(30))
	title.add_color_override("font_color", Color("d6336c"))
	box.add_child(title)

	var tagline = Label.new()
	tagline.text = "和 Sophia 一起消掉所有烦恼吧"
	tagline.align = Label.ALIGN_CENTER
	tagline.add_font_override("font", game._font_at_size(13))
	tagline.add_color_override("font_color", Color("a85878"))
	box.add_child(tagline)

	box.add_child(_spacer(6))
	box.add_child(_info_line(game))
	box.add_child(_spacer(4))
	box.add_child(_start_button(game))
	box.add_child(_spacer(2))
	box.add_child(_quick_grid(game))
	box.add_child(_spacer(2))

	var footnote = Label.new()
	footnote.text = "进度自动保存 · 樱花币与图鉴随时可看"
	footnote.align = Label.ALIGN_CENTER
	footnote.add_font_override("font", game._font_at_size(11))
	footnote.add_color_override("font_color", Color("c2a3b2"))
	box.add_child(footnote)
	return root

static func _spacer(height):
	var spacer = Control.new()
	spacer.rect_min_size = Vector2(0, height)
	return spacer

# 存档速览：樱花币 + 图鉴收集度。
static func _info_line(game):
	var collected: Array = game.progression_state.get("collected", [])
	var info = Label.new()
	info.text = "🌸 %d · 📖 %d/%d" % [int(game.progression_state.get("coins", 0)), collected.size(), PAGE_ROUTER._total_icons(game)]
	info.align = Label.ALIGN_CENTER
	info.add_font_override("font", game._font_at_size(15))
	info.add_color_override("font_color", Color("8f6b80"))
	return info

# 主按钮：接着上次进度进棋盘。
static func _start_button(game):
	var level_index = clamp(int(game.progression_state.get("current_level_index", 0)), 0, game.campaign_levels.size() - 1)
	var level: Dictionary = game.campaign_levels[level_index]
	var start = Button.new()
	start.text = "▶ 开始游戏 · 第%d关「%s」" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡"))]
	start.rect_min_size = Vector2(0, 62)
	start.add_font_override("font", game._font_at_size(18))
	game._apply_button_style(start, Color("f06ba8"), Color("d6336c"))
	start.add_color_override("font_color", Color("ffffff"))
	start.connect("pressed", game, "_on_start_game_pressed")
	return start

# 快捷入口 2×2：直达四个高频页面，免得首页只有一枚孤零零的按钮。
static func _quick_grid(game):
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("h_separation", 10)
	grid.add_constant_override("v_separation", 10)
	var entries = [
		["🎮 玩法大厅", PAGE_ROUTER.PAGE_MODES],
		["🗺️ 旅程", PAGE_ROUTER.PAGE_LEVEL_MAP],
		["🎁 有礼", PAGE_ROUTER.PAGE_SIGNIN],
		["📊 数据", PAGE_ROUTER.PAGE_STATS],
	]
	for entry in entries:
		var button = Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.rect_min_size = Vector2(0, 52)
		button.add_font_override("font", game._font_at_size(15))
		game._apply_button_style(button, Color("ffffff"), Color("f09ebb"))
		button.add_color_override("font_color", Color("d6336c"))
		button.connect("pressed", game, "_on_start_open_page", [entry[1]])
		grid.add_child(button)
	return grid
