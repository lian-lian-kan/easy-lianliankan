extends Reference

# 首页（启动标题页）：进游戏先见首页，按下「开始游戏」才落到棋盘。
# 全屏覆盖层，走 open_modal 生命周期（打开即暂停计时、关闭只恢复自己造成
# 的暂停），所以棋盘在下面已就绪、时钟却不会偷跑。快捷入口先收起首页再
# open_page——同一帧内一开一关不成对会互相吃掉暂停态，但 close_modal 与
# show_page 的 open_modal 同步连发，中间没有可计时的帧。
#
# 视觉构成（2026-09-21 少女向重设计）：甜系天空渐变 + 底部山丘剪影 + 花
# 瓣星星飘落 + 白圈光晕，内容收进玻璃英雄卡——贴纸描边大标题、药丸徽章、
# 糖果主按钮（白圈描边）、马卡龙色图标快捷卡、花边圆点分隔线。全部用现有
# 字形与纯代码图形，不依赖美术资源。
#
# Round 36（2026-09-30 家界面细节）：首页从「好看」走向「贴心」——
# 快捷卡按存档实况点红点（今天没签到 → 有礼；任务可领 → 任务；大树里程碑
# 可领 → 数据），主按钮呼吸微动，问候语跟时段请安，日期徽章入列，
# ⚙️ 设置常驻右上；宽屏快捷格升 3 列、英雄卡加宽（驱动器逐帧自校正）。

const PAGE_ROUTER = preload("res://scripts/pages/page_router.gd")
const UI_PANELS = preload("res://scripts/ui/ui_panels.gd")
const UI_PAINT = preload("res://scripts/ui/ui_paint.gd")

# 快捷卡的马卡龙底色/描边（同族粉彩轮换）。
const CARD_TINTS = [
	{"bg": Color("fff0f6"), "border": Color("ffd3e5")},
	{"bg": Color("fff7e8"), "border": Color("ffe4bd")},
	{"bg": Color("f3efff"), "border": Color("ddd2f7")},
]

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
	# 入场淡入：背景/花瓣/英雄卡整层浮现，开场不像「直接糊上来」。
	# Tween 挂在 root 之下随其释放——玩家在 0.25s 内点掉首页也不会留下
	# 悬空补间。
	root.modulate = Color(1, 1, 1, 0)
	var intro = Tween.new()
	root.add_child(intro)
	intro.interpolate_property(root, "modulate:a", 0.0, 1.0, 0.25, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	intro.start()
	UI_PANELS.open_modal(game, root)
	# 开局字幕与页面互斥（单例常驻，显隐控制）。
	game._hide_stage_callout()
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

# ── 构图 ──

static func _build(game):
	var root = ColorRect.new()
	root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.color = Color("ffe9f1")
	var driver = PetalDrift.new()
	_build_background(game, root, driver)
	_build_petals(game, root, driver)

	var safe = MarginContainer.new()
	safe.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	safe.add_constant_override("margin_left", 20)
	safe.add_constant_override("margin_right", 20)
	root.add_child(safe)
	var center = CenterContainer.new()
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	safe.add_child(center)
	var hero = _build_hero_card(game, driver)
	center.add_child(hero)
	root.add_child(driver)
	# ⚙️ 圆钮必须最后挂（画在 safe/center 两个全屏容器之上）：提前挂会被
	# 全屏容器盖住点击——按钮看得见却永远收不到事件（浏览器实测踩中）。
	_build_settings(game, root)
	return root

# ⚙️ 设置常驻首页右上（白瓷圆钮）：不用先进棋盘也能调音量与显示。
static func _build_settings(game, root):
	var gear = Button.new()
	gear.text = "⚙️"
	gear.hint_tooltip = "设置"
	gear.rect_min_size = Vector2(44, 44)
	gear.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT)
	gear.margin_left = -60
	gear.margin_right = -16
	gear.margin_top = 16
	gear.margin_bottom = 60
	gear.add_font_override("font", game._font_at_size(18))
	game._apply_button_style(gear, Color("ffffff"), Color("ffd9e8"))
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		gear.get_stylebox(sb_name).set_corner_radius_all(22)
	gear.connect("pressed", game, "_on_title_settings_pressed")
	root.add_child(gear)

# 氛围层：甜系天空渐变 + 标题白圈光晕 + 底部双层山丘剪影。
# 绘制原语（渐变贴图/光晕圆盘/圆点线）在 UI_PAINT（Round 35 抽取）。
static func _build_background(game, root, driver):
	var view = game.get_viewport_rect().size
	var bg = TextureRect.new()
	bg.texture = UI_PAINT.gradient_texture(Color("ffd6e7"), Color("fff0f5"), Color("fff7ec"))
	bg.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	bg.expand = true
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(bg)
	# 标题背后的白圈光晕（画在卡片之下，像背光板）。
	root.add_child(UI_PAINT.soft_disc(Vector2(view.x / 2.0 - 330.0, view.y / 2.0 - 330.0), Vector2(660, 660), Color(1, 1, 1, 0.5)))
	# 底部山丘：两枚半出画的大圆叠出层次，前景山丘更深一档。
	root.add_child(UI_PAINT.soft_disc(Vector2(view.x - 520.0, view.y - 130.0), Vector2(900, 900), Color("fbc9dc"), 130))
	root.add_child(UI_PAINT.soft_disc(Vector2(-260.0, view.y - 60.0), Vector2(760, 760), Color("f8a9c7"), 120))
	_build_sparkles(game, root, driver)

# 闪烁星星：三枚 ✨ 钉在英雄卡两侧卡缘之外（按卡片实际半宽外挂——宽屏
# 卡片加宽后旧坐标会整排被卡盖住），由驱动器做呼吸式明暗；窄屏收到屏内。
static func _build_sparkles(game, root, driver):
	var view = game.get_viewport_rect().size
	var half = min(320.0, max(130.0, (view.x - 40.0) / 2.0))
	var spots = [
		[Vector2(max(34.0, view.x / 2.0 - half - 40.0), view.y / 2.0 - 150.0), 22, 0.0],
		[Vector2(min(view.x - 34.0, view.x / 2.0 + half + 30.0), view.y / 2.0 - 110.0), 16, 1.3],
		[Vector2(min(view.x - 30.0, view.x / 2.0 + half + 16.0), view.y / 2.0 + 160.0), 18, 2.6],
	]
	for spot in spots:
		var star = Label.new()
		star.text = "✨"
		star.add_font_override("font", game._font_at_size(spot[1]))
		star.rect_position = spot[0]
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		driver.sparkles.append({"label": star, "phase": spot[2], "base": 0.45})
		root.add_child(star)

# 花瓣层：花标交给驱动器做落体+摆动。
static func _build_petals(game, root, drift):
	var view = game.get_viewport_rect().size
	var glyphs = ["🌸", "⭐", "🌷", "🌸", "✨", "🌸", "⭐"]
	for i in range(glyphs.size()):
		var petal = Label.new()
		petal.text = glyphs[i]
		petal.add_font_override("font", game._font_at_size(15 + (i * 7) % 16))
		petal.modulate = Color(1, 1, 1, 0.3 + 0.07 * (i % 4))
		petal.rect_rotation = -18 + (i * 9) % 36
		petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var base_x = fmod(view.x * (0.08 + 0.12 * i), max(1.0, view.x - 48)) + 16
		drift.petals.append({
			"label": petal, "base_x": base_x, "speed": 24.0 + (i * 13) % 26,
			"sway": 12.0 + (i * 7) % 16, "phase": float(i) * 1.7,
		})
		petal.rect_position = Vector2(base_x, fmod(i * 173.0, max(1.0, view.y)) - 40)
		root.add_child(petal)

static func _build_hero_card(game, driver):
	var hero = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.set_corner_radius_all(26)
	style.set_border_width_all(2)
	style.border_color = Color("ffd9e8")
	style.shadow_color = Color8(214, 51, 108, 40)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 10)
	hero.add_stylebox_override("panel", style)

	var margins = MarginContainer.new()
	margins.add_constant_override("margin_left", 26)
	margins.add_constant_override("margin_right", 26)
	margins.add_constant_override("margin_top", 26)
	margins.add_constant_override("margin_bottom", 22)
	hero.add_child(margins)

	# 宽屏（≥1100，与快捷格 3 列同一开关）：卡片放宽到 640，两行快捷卡
	# 让英雄卡明显变矮，天空与山丘有更多出镜余地。
	var wide = game.get_viewport_rect().size.x >= 1100.0
	var width = clamp(game.get_viewport_rect().size.x - 40.0, 300.0, 640.0 if wide else 520.0)
	var box = VBoxContainer.new()
	box.add_constant_override("separation", 10)
	box.rect_min_size = Vector2(width - 52, 0)
	margins.add_child(box)
	driver.card_box = box

	_header_block(game, box)
	box.add_child(_spacer(6))
	box.add_child(_info_chips(game, wide))
	box.add_child(_spacer(12))
	var cta = _start_button(game)
	driver.cta = cta
	box.add_child(cta)
	box.add_child(_spacer(10))
	box.add_child(_dot_divider())
	box.add_child(_spacer(10))
	box.add_child(_quick_grid(game, driver))
	box.add_child(_spacer(8))
	box.add_child(_dot_divider())
	box.add_child(_spacer(6))
	box.add_child(_footnote(game))
	return hero

# 标题区：徽标 + 贴纸描边大标题 + 标语。标语跟时段请安（早上好/夜深了），
# 其余时段保持原句——只有字池里已有的汉字才上屏。
static func _header_block(game, box):
	var emblem = Label.new()
	emblem.text = "🌸 🎀 🌸"
	emblem.align = Label.ALIGN_CENTER
	emblem.add_font_override("font", game._font_at_size(36))
	box.add_child(emblem)

	var title = Label.new()
	title.text = "Sophia的连连看"
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", game._font_at_size(32))
	title.add_color_override("font_color", Color("e84a8a"))
	title.add_color_override("font_outline_color", Color("ffffff"))
	title.add_constant_override("outline_size", 6)
	title.add_color_override("font_shadow_color", Color8(214, 51, 108, 70))
	title.add_constant_override("shadow_offset_x", 0)
	title.add_constant_override("shadow_offset_y", 4)
	box.add_child(title)

	var tagline = Label.new()
	tagline.text = _tagline_text()
	tagline.align = Label.ALIGN_CENTER
	tagline.add_font_override("font", game._font_at_size(13))
	tagline.add_color_override("font_color", Color("a85878"))
	box.add_child(tagline)

static func _tagline_text():
	var hour = OS.get_time()["hour"]
	if hour < 11:
		return "早上好 · 今天也要元气满满"
	if hour >= 22:
		return "夜深了 · 注意休息"
	return "和 Sophia 一起消掉所有烦恼吧"

# 存档速览：樱花币 + 图鉴收集度两枚药丸徽章；宽屏再添当日日期。
static func _info_chips(game, wide):
	var collected: Array = game.progression_state.get("collected", [])
	var chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGN_CENTER
	chips.add_constant_override("separation", 10)
	chips.add_child(_chip(game, "🌸 %d" % int(game.progression_state.get("coins", 0))))
	chips.add_child(_chip(game, "📖 %d/%d" % [collected.size(), PAGE_ROUTER._total_icons(game)]))
	if wide:
		chips.add_child(_date_chip(game))
	return chips

# 当日日期徽章：📅 9月30日 星期三（ weekday 0=周日，字池已对拍）。
static func _date_chip(game):
	var d = OS.get_date()
	var week = ["日", "一", "二", "三", "四", "五", "六"][int(d["weekday"])]
	return _chip(game, "📅 %d月%d日 星期%s" % [int(d["month"]), int(d["day"]), week])

static func _chip(game, text):
	var pill = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("fff0f6")
	style.set_corner_radius_all(14)
	style.set_border_width_all(1)
	style.border_color = Color("ffd9e8")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	pill.add_stylebox_override("panel", style)
	var label = Label.new()
	label.text = text
	label.add_font_override("font", game._font_at_size(14))
	label.add_color_override("font_color", Color("8f6b80"))
	pill.add_child(label)
	return pill

# 主按钮：糖果钮——白圈描边 + 玫瑰实心 + 大投影，全页唯一的实心玫瑰。
static func _start_button(game):
	var level_index = clamp(int(game.progression_state.get("current_level_index", 0)), 0, game.campaign_levels.size() - 1)
	var level: Dictionary = game.campaign_levels[level_index]
	var start = Button.new()
	start.text = "▶ 开始游戏 · 第%d关「%s」" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡"))]
	start.rect_min_size = Vector2(0, 68)
	start.add_font_override("font", game._font_at_size(19))
	game._apply_button_style(start, Color("f06ba8"), Color("ffffff"))
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb = start.get_stylebox(sb_name)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(26)
	var normal = start.get_stylebox("normal")
	normal.shadow_size = 14
	normal.shadow_offset = Vector2(0, 6)
	normal.shadow_color = Color8(214, 51, 108, 80)
	start.connect("pressed", game, "_on_start_game_pressed")
	return start

# 花边圆点分隔线：九枚粉色小圆点（绘制原语在 UI_PAINT）。
static func _dot_divider():
	return UI_PAINT.dot_divider()

# 快捷入口 2×3（宽屏 3×2）：白瓷卡——糖边描border、emoji 徽章在上、名字
# 在下。Round 31：马卡龙底整卡填充太甜腻，白面+糖边+彩描边更「瓷」，图标
# 也放大一号当主视觉。Round 36：卡上按存档实况点红点（可领奖励的入口自己
# 会说话，不用玩家先进页面翻一遍）。
static func _quick_grid(game, driver):
	var grid = GridContainer.new()
	grid.columns = 3 if game.get_viewport_rect().size.x >= 1100.0 else 2
	grid.add_constant_override("h_separation", 10)
	grid.add_constant_override("v_separation", 10)
	driver.grid = grid
	var entries = [
		["🎮", "玩法大厅", PAGE_ROUTER.PAGE_MODES],
		["🗺️", "旅程", PAGE_ROUTER.PAGE_LEVEL_MAP],
		["🎁", "有礼", PAGE_ROUTER.PAGE_SIGNIN],
		["📊", "数据", PAGE_ROUTER.PAGE_STATS],
		["📋", "任务", PAGE_ROUTER.PAGE_MISSIONS],
		["🏆", "成就", PAGE_ROUTER.PAGE_ACHIEVEMENTS],
	]
	var badges = {
		PAGE_ROUTER.PAGE_SIGNIN: _has_unsigned_signin(game),
		PAGE_ROUTER.PAGE_STATS: _has_unclaimed_milestone(game),
		PAGE_ROUTER.PAGE_MISSIONS: _has_claimable_mission(game),
	}
	# Button 不会把内嵌 VBox 算进最小尺寸，列宽必须显式给足下限
	# （140≈两列下限 290，适配最窄可用视口），多余宽度由 EXPAND 拉伸；
	# 实际盒宽由驱动器逐帧校正，所以这里不读视口，避免构建期竞态。
	for i in range(entries.size()):
		var tint = CARD_TINTS[i % CARD_TINTS.size()]
		var page_id = entries[i][2]
		grid.add_child(_quick_card(game, entries[i][0], entries[i][1], page_id, tint, badges.get(page_id, false)))
	return grid

# ── 红点状态（全部只读）：构建期不写存档，周任务桶滚动留给任务页自己处理。
static func _has_unsigned_signin(game):
	var today = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	return str(game.progression_state.get("last_signin", "")) != today

static func _has_claimable_mission(game):
	var state = game.progression_state.get("weekly_missions", {})
	if typeof(state) != TYPE_DICTIONARY \
			or str(state.get("week_key", "")) != game.MISSIONS.current_week_key(game):
		return false
	for task_id in game.MISSIONS.MISSIONS:
		if game.MISSIONS.is_complete(state, task_id) and not game.MISSIONS.is_claimed(state, task_id):
			return true
	return false

static func _has_unclaimed_milestone(game):
	var best = int(game.progression_state.get("tree_best_height", 0))
	var claimed = game.progression_state.get("tree_milestones", [])
	for height in game.SPECIAL_MODES_SCRIPT.TREE_LADDER.MILESTONE_HEIGHTS:
		if best >= int(height) and not claimed.has(int(height)):
			return true
	return false

# 红点徽章：12px 玫瑰实心圆 + 白描边（纯代码，无新字形），钉在快捷卡右上。
static func _dot_badge():
	var badge = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("d6336c")
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = Color("ffffff")
	badge.add_stylebox_override("panel", style)
	badge.rect_min_size = Vector2(12, 12)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT)
	badge.margin_left = -22
	badge.margin_right = -10
	badge.margin_top = 10
	badge.margin_bottom = 22
	return badge

static func _quick_card(game, icon_text, name_text, page_id, tint, with_badge = false):
	var button = Button.new()
	button.rect_min_size = Vector2(140, 82)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._apply_button_style(button, Color("ffffff"), tint["border"])
	var layout = VBoxContainer.new()
	layout.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	layout.alignment = BoxContainer.ALIGN_CENTER
	layout.add_constant_override("separation", 2)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon = Label.new()
	icon.text = icon_text
	icon.align = Label.ALIGN_CENTER
	icon.add_font_override("font", game._font_at_size(27))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(icon)
	var name_label = Label.new()
	name_label.text = name_text
	name_label.align = Label.ALIGN_CENTER
	name_label.add_font_override("font", game._font_at_size(13))
	name_label.add_color_override("font_color", Color("8f6b80"))
	name_label.add_color_override("font_outline_color", Color("ffffff"))
	name_label.add_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(name_label)
	button.add_child(layout)
	if with_badge:
		button.add_child(_dot_badge())
	button.connect("pressed", game, "_on_start_open_page", [page_id])
	return button

# 页脚：自动保存提示与版本号。
static func _footnote(game):
	var footnote = Label.new()
	footnote.text = "进度自动保存 · 樱花币与图鉴随时可看 · v%s" % game.GAME_VERSION
	footnote.align = Label.ALIGN_CENTER
	footnote.add_font_override("font", game._font_at_size(11))
	footnote.add_color_override("font_color", Color("c2a3b2"))
	return footnote

static func _spacer(height):
	var spacer = Control.new()
	spacer.rect_min_size = Vector2(0, height)
	return spacer

# 标题驱动器：花瓣飘落 + 星星闪烁 + 英雄卡宽度与快捷格列数逐帧自校正
# （窗口缩放/构建期视口竞态都在这里收敛）+ 主按钮呼吸微动。挂在标题根
# 节点下随其释放。
class PetalDrift extends Node:
	var petals = []
	var sparkles = []
	var card_box = null
	var grid = null
	var cta = null
	var _clock = 0.0

	func _process(delta):
		_clock += delta
		var view = get_tree().root.size
		# 宽屏（≥1100）：3 列快捷格 + 588 盒宽上限；窄屏回到 2 列 468。
		var wide = view.x >= 1100.0
		if grid != null:
			var wanted_columns = 3 if wide else 2
			if grid.columns != wanted_columns:
				grid.columns = wanted_columns
		if card_box != null:
			var target = clamp(view.x - 40.0 - 52.0, 248.0, 588.0 if wide else 468.0)
			if abs(card_box.rect_min_size.x - target) > 1.0:
				card_box.rect_min_size = Vector2(target, 0)
		# 主按钮呼吸：±1.2% 缩放绕中心，眼睛自然落在唯一的实心玫瑰上。
		if cta != null and cta.rect_size.x > 0.0:
			cta.rect_pivot_offset = cta.rect_size / 2.0
			cta.rect_scale = Vector2(1.0 + 0.012 * sin(_clock * 2.4), 1.0 + 0.012 * sin(_clock * 2.4))
		for s in sparkles:
			var label: Label = s.label
			label.modulate = Color(1, 1, 1, s.base + 0.4 * (0.5 + 0.5 * sin(_clock * 2.2 + s.phase)))
		if petals.empty():
			return
		var vsize = petals[0].label.get_viewport_rect().size
		for p in petals:
			var label: Label = p.label
			label.rect_position.y += p.speed * delta
			p.phase += delta
			label.rect_position.x = p.base_x + sin(p.phase * 1.4) * p.sway
			if label.rect_position.y > vsize.y + 48:
				label.rect_position.y = -52
				p.base_x = rand_range(16, max(17.0, vsize.x - 48))
