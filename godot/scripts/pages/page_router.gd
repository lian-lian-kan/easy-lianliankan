extends Reference

# Multi-page shell: bottom navigation + full-screen meta pages layered over
# the home board. Opening a page pauses the running stage through the modal
# lifecycle (ui_panels.open_modal). Journey-map and collection pages are
# built here; economy pages (sign-in / shop) live in economy.gd.

const UI_PANELS = preload("res://scripts/ui/ui_panels.gd")
const PAGE_UI = preload("res://scripts/pages/page_ui.gd")
const ECONOMY = preload("res://scripts/pages/economy.gd")
const EVENTS = preload("res://scripts/content/events_calendar.gd")

const PAGE_LEVEL_MAP = "level_map"
const PAGE_COLLECTION = "collection"
const PAGE_SIGNIN = "signin"
const PAGE_SHOP = "shop"
const PAGE_STATS = "stats"
const PAGE_TREE_MAP = "tree_map"
const PAGE_EVENTS = "events"

static func nav_items():
	return [
		["home", "🏠", "主页"],
		[PAGE_LEVEL_MAP, "🗺️", "旅程"],
		[PAGE_COLLECTION, "📖", "图鉴"],
		[PAGE_SIGNIN, "🎁", "有礼"],
		[PAGE_EVENTS, "🎉", "活动"],
		[PAGE_SHOP, "🛍️", "小铺"],
	]

static func build_pages(game):
	_build_page_surface(game)
	_build_nav_bar(game)

# Full-screen page surface above the home board: pink panel + margin +
# the shared content box every page renders into.
static func _build_page_surface(game):
	var pages = PanelContainer.new()
	pages.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	pages.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color("fff5f9")
	pages.add_stylebox_override("panel", style)
	game.add_child(pages)
	game.pages_root = pages

	var margin = MarginContainer.new()
	margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	margin.add_constant_override("margin_left", 14)
	margin.add_constant_override("margin_right", 14)
	margin.add_constant_override("margin_top", 12)
	margin.add_constant_override("margin_bottom", 66)
	pages.add_child(margin)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_constant_override("separation", 10)
	margin.add_child(content)
	game.page_content = content

# Bottom nav bar; added after the surface so it stays on top of it.
static func _build_nav_bar(game):
	var nav = HBoxContainer.new()
	nav.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
	nav.margin_top = -54
	nav.margin_bottom = -6
	nav.add_constant_override("separation", 6)
	game.add_child(nav)
	game.nav_bar = nav
	for item in nav_items():
		var button = Button.new()
		button.text = item[1] + "\n" + item[2]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.rect_min_size = Vector2(0, 46)
		button.add_font_override("font", game._font_at_size(12))
		game._apply_button_style(button, Color("f06ba8"), Color("d6336c"))
		button.add_color_override("font_color", Color("ffffff"))
		if item[0] == "home":
			button.connect("pressed", game, "_on_nav_home_pressed")
		else:
			button.connect("pressed", game, "_on_nav_pressed", [item[0]])
		nav.add_child(button)
		game.nav_buttons[item[0]] = button

static func show_page(game, page_id):
	if game.pages_root == null:
		return
	var reopened = game.pages_root.visible and game.current_page == page_id
	UI_PANELS.open_modal(game, game.pages_root)
	# Home-screen floaters sit above the page surface; hide them while a
	# page is open (the stage is paused, so nothing re-raises them).
	if game.stage_panel_label:
		game.stage_panel_label.visible = false
	if game.combo_burst_label:
		game.combo_burst_label.visible = false
	# Freeze the post-clear level advance while browsing: the settle flow
	# resumes when the page closes.
	if game.level_advance_timer:
		game.level_advance_timer.stop()
	game.current_page = page_id
	# Desktop hides the nav on the chrome-free home board; it belongs to
	# pages, so it comes back the moment one opens. get() keeps fakes and
	# partial shells without the member safe.
	var nav_bar = game.get("nav_bar")
	if nav_bar != null:
		nav_bar.visible = true
	if not reopened:
		_route_page(game, page_id)

# Build (or rebuild) the given page's body into the shared content box.
static func _route_page(game, page_id):
	PAGE_UI.clear_page(game, game.page_content)
	match page_id:
		PAGE_LEVEL_MAP:
			_build_level_map(game)
		PAGE_COLLECTION:
			_build_collection(game)
		PAGE_SIGNIN:
			ECONOMY.build_signin(game)
		PAGE_SHOP:
			ECONOMY.build_shop(game)
		PAGE_STATS:
			_build_stats(game)
		PAGE_TREE_MAP:
			_build_tree_map(game)
		PAGE_EVENTS:
			_build_events(game)

# Refresh the open page in place (a claim mutating its own page rebuilds it).
static func rebuild_page(game):
	if game.current_page == "" or game.page_content == null:
		return
	_route_page(game, game.current_page)

static func close_page(game):
	UI_PANELS.close_modal(game, game.pages_root)
	# Back to the board-first home: desktop parks the nav again.
	var nav_bar = game.get("nav_bar")
	if nav_bar != null:
		nav_bar.visible = game._viewport_flags(game.get_viewport_rect().size)["is_mobile"]
	# Resume a settle that was interrupted by opening the page.
	if game.stage_status == game.STATUS_CLEARED and game.pending_level_index >= 0 \
			and game.level_advance_timer:
		game.level_advance_timer.start()
	game.current_page = ""

const CHAPTER_NAMES = ["樱园初语", "花海拾光", "月下奇缘"]

# --- Journey map: 3 chapters x 5 level nodes ---

static func _build_level_map(game):
	var page_content = game.page_content
	PAGE_UI.page_frame(game, page_content, "🗺️ 旅程", "点亮每一座樱园")
	var box = PAGE_UI.scroll_area(game, page_content)
	var chapter_size = int(ceil(game.campaign_levels.size() / float(CHAPTER_NAMES.size())))
	for chapter in range(CHAPTER_NAMES.size()):
		var chapter_label = Label.new()
		var chapter_mark = ["一", "二", "三"][chapter]
		chapter_label.text = "第%s章 · %s" % [chapter_mark, CHAPTER_NAMES[chapter]]
		chapter_label.add_font_override("font", game._font_at_size(15))
		chapter_label.add_color_override("font_color", Color("a85878"))
		box.add_child(chapter_label)
		for slot in range(chapter_size):
			var level_index = chapter * chapter_size + slot
			if level_index >= game.campaign_levels.size():
				break
			box.add_child(_level_node(game, level_index))

static func _level_node(game, level_index):
	var level: Dictionary = game.campaign_levels[level_index]
	var unlocked = game._is_level_unlocked(level_index)
	var is_current = level_index == int(game.level_index) and not game._is_special_session()
	var star_map: Dictionary = game.progression_state.get("level_stars", {})
	var stars = int(star_map.get(str(level_index), 0))
	var star_mark = ""
	for star_i in range(stars):
		star_mark += "⭐"
	var node = Button.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.rect_min_size = Vector2(0, 54)
	node.add_font_override("font", game._font_at_size(14))
	game._apply_button_style(node, Color("f06ba8"), Color("d6336c"))
	if is_current:
		node.text = "▶ 第%d关 · %s %s" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡")), star_mark]
	elif unlocked:
		node.text = "第%d关 · %s %s" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡")), star_mark]
	else:
		node.text = "🔒 第%d关 · %s" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡"))]
	node.add_color_override("font_color", Color("ffffff") if unlocked else Color("e8b8cc"))
	if unlocked:
		node.connect("pressed", game, "_on_map_level_pressed", [level_index])
	else:
		node.connect("pressed", game, "_on_map_locked_pressed")
	return node

# --- Collection: every icon set, caught vs mystery ---

static func _build_collection(game):
	var page_content = game.page_content
	var collected: Array = game.progression_state.get("collected", [])
	PAGE_UI.page_frame(game, page_content, "📖 图鉴", "已收集 %d / %d 个图案" % [collected.size(), _total_icons(game)])
	var box = PAGE_UI.scroll_area(game, page_content)
	var sets = game.icon_sets
	for set_index in range(sets.size()):
		var icon_set: Dictionary = sets[set_index]
		var icons: Array = icon_set.get("icons", [])
		var set_id = str(icon_set.get("id", str(set_index)))
		var colors: Array = icon_set.get("colors", [])
		var caught = 0
		for i in range(icons.size()):
			if collected.has(ECONOMY.collection_key(set_id, i)):
				caught += 1
		var set_panel = PanelContainer.new()
		game._apply_glass_style(set_panel, Color("ffffff"), 0.85)
		box.add_child(set_panel)
		var set_box = VBoxContainer.new()
		set_box.add_constant_override("separation", 6)
		set_panel.add_child(set_box)
		var set_title = Label.new()
		set_title.text = "%s %s（%d/%d）" % ["🌸" if caught == icons.size() else "🌷", str(icon_set.get("name", "图集")), caught, icons.size()]
		set_title.add_font_override("font", game._font_at_size(14))
		set_title.add_color_override("font_color", Color("d6336c"))
		set_box.add_child(set_title)
		var grid = GridContainer.new()
		grid.columns = 5
		grid.add_constant_override("h_separation", 6)
		grid.add_constant_override("v_separation", 6)
		set_box.add_child(grid)
		for i in range(icons.size()):
			grid.add_child(_collection_cell(game, str(icons[i]), colors, i, collected.has(ECONOMY.collection_key(set_id, i))))

static func _collection_cell(game, glyph_text, colors, index, has_it):
	var cell = PanelContainer.new()
	var cell_style = StyleBoxFlat.new()
	cell_style.bg_color = Color(str(colors[index % colors.size()])) if has_it else Color("f3e2ea")
	cell_style.set_corner_radius_all(10)
	cell.add_stylebox_override("panel", cell_style)
	var glyph = Label.new()
	glyph.text = glyph_text if has_it else "❓"
	glyph.align = Label.ALIGN_CENTER
	glyph.rect_min_size = Vector2(52, 44)
	glyph.add_font_override("font", game._font_at_size(22 if has_it else 14))
	glyph.modulate = Color(1, 1, 1) if has_it else Color(1, 1, 1, 0.55)
	cell.add_child(glyph)
	return cell

# --- Stats page: every best, streak and collection number on one page ---

static func _build_stats(game):
	var page_content = game.page_content
	var collected: Array = game.progression_state.get("collected", [])
	var total_icons = _total_icons(game)
	PAGE_UI.page_frame(game, page_content, "📊 数据", "你的连连看足迹")
	var box = PAGE_UI.scroll_area(game, page_content)

	var rows = _stats_rows(game, collected, total_icons)
	for row_data in rows:
		_stats_row_panel(game, box, row_data)

# 统计页 21 行数据（全部读现有 progression 字段）。
static func _stats_rows(game, collected, total_icons) -> Array:
	return [
		["🏆 最佳总分", str(int(game.progression_state.get("best_total_score", 0)))],
		["🔥 最佳连击", "x" + str(int(game.progression_state.get("best_combo", 0)))],
		["🌸 樱花币", str(int(game.progression_state.get("coins", 0)))],
		["📖 图鉴收集", "%d / %d" % [collected.size(), total_icons]],
		["🎁 连续签到", "%d 天" % int(game.progression_state.get("signin_streak", 0))],
		["📅 每日挑战最佳", str(int(game.progression_state.get("daily_challenge", {}).get("best_score", 0)))],
		["∞ 无尽模式", "第%d轮 · %d分" % [int(game.progression_state.get("endless_best", {}).get("round", 0)), int(game.progression_state.get("endless_best", {}).get("score", 0))]],
		["🌳 攀登树", "最佳第%d层" % int(game.progression_state.get("tree_best_height", 0))],
		["⏱️ 限时最佳", str(int(game.progression_state.get("time_attack_best_score", 0)))],
		["🎁 盲盒最佳", str(int(game.progression_state.get("memory_best_score", 0)))],
		["❄️ 冰雪最佳", str(int(game.progression_state.get("frost_best_score", 0)))],
		["🍵 休闲最佳", str(int(game.progression_state.get("zen_best_score", 0)))],
		["🔥 地狱最佳", str(int(game.progression_state.get("hell_best_score", 0)))],
		["🧮 步数最佳", str(int(game.progression_state.get("moves_best_score", 0)))],
		["🤖 竞速最佳", str(int(game.progression_state.get("race_best_score", 0)))],
		["🥞 叠层最佳", str(int(game.progression_state.get("stack_best_score", 0)))],
		["🍎 重力最佳", str(int(game.progression_state.get("gravity_best_score", 0)))],
		["🌫️ 迷雾最佳", str(int(game.progression_state.get("fog_best_score", 0)))],
		["⛓️ 锁链最佳", str(int(game.progression_state.get("chain_best_score", 0)))],
		["🌶️ 狂热最佳", str(int(game.progression_state.get("fever_best_score", 0)))],
		["💎 完美最佳", str(int(game.progression_state.get("perfect_best_score", 0)))],
		["🀄 叠叠消最佳", str(int(game.progression_state.get("tray_best_score", 0)))],
		["🎯 收集挑战最佳", str(int(game.progression_state.get("collect_best_score", 0)))],
		["🃏 翻翻乐最佳", str(int(game.progression_state.get("flip_best_score", 0)))],
		["🪨 障碍最佳", str(int(game.progression_state.get("rock_best_score", 0)))],
		["💣 拆弹最佳", str(int(game.progression_state.get("defuse_best_score", 0)))],
		["✨ 指定连消最佳", str(int(game.progression_state.get("target_best_score", 0)))],
		["🔄 变脸最佳", str(int(game.progression_state.get("shift_best_score", 0)))],
		["🧲 滑移最佳", str(int(game.progression_state.get("slide_best_score", 0)))],
		["🧟 守卫最佳", str(int(game.progression_state.get("defense_best_score", 0)))],
		["🔟 合十最佳", str(int(game.progression_state.get("sum10_best_score", 0)))],
		["👫 同屏对战最佳", str(int(game.progression_state.get("duel_best_score", 0)))],
	]

# 单行白卡：名称居左、数值居右。
static func _stats_row_panel(game, box, row_data):
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color("ffffff")
	row_style.set_corner_radius_all(10)
	row_panel.add_stylebox_override("panel", row_style)
	var hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = row_data[0]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_font_override("font", game._font_at_size(14))
	name_label.add_color_override("font_color", Color("8f6b80"))
	hbox.add_child(name_label)
	var value_label = Label.new()
	value_label.text = row_data[1]
	value_label.add_font_override("font", game._font_at_size(14))
	value_label.add_color_override("font_color", Color("d6336c"))
	hbox.add_child(value_label)
	row_panel.add_child(hbox)
	box.add_child(row_panel)

# 大树页：位置总结卡 + 里程碑刻度自上而下（大到小，像抬头看树冠）。
static func _build_tree_map(game):
	var page_content = game.page_content
	var best = int(game.progression_state.get("tree_best_height", 0))
	var claimed = game.progression_state.get("tree_milestones", [])
	var ladder = game.SPECIAL_MODES_SCRIPT.TREE_LADDER
	PAGE_UI.page_frame(game, page_content, "🌳 攀登大树", "你在第 %d 层 · 里程碑 %d/%d" % [best, ladder.claimed_count(claimed), ladder.MILESTONE_HEIGHTS.size()])
	var box = PAGE_UI.scroll_area(game, page_content)
	_tree_summary_row(game, box, best, ladder.next_milestone(best))
	var heights = ladder.MILESTONE_HEIGHTS
	for i in range(heights.size() - 1, -1, -1):
		_tree_milestone_row(game, box, int(heights[i]), ladder.milestone_reward(int(heights[i])), claimed.has(int(heights[i])), best)
	var hint = Label.new()
	hint.text = "从玩法面板的 🌳 攀登树卡片出发，每层更难，刻度层有樱花奖励"
	hint.add_font_override("font", game._font_at_size(12))
	hint.add_color_override("font_color", Color("b08a9b"))
	hint.autowrap = true
	box.add_child(hint)

# 位置总结卡：当前层数 + 到下一刻度的距离。
static func _tree_summary_row(game, box, best, next_height):
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color("fff0f6")
	row_style.set_corner_radius_all(10)
	row_panel.add_stylebox_override("panel", row_style)
	var label = Label.new()
	if next_height > 0:
		label.text = "📍 你在第 %d 层 · 下一刻度第 %d 层（还差 %d 层）" % [best, next_height, next_height - best]
	else:
		label.text = "📍 你在第 %d 层 · 所有刻度都登完啦" % best
	label.add_font_override("font", game._font_at_size(13))
	label.add_color_override("font_color", Color("d6336c"))
	row_panel.add_child(label)
	box.add_child(row_panel)

# 单个刻度行：登顶过的亮白底+绿勾，未到的灰底+剩余层数。
static func _tree_milestone_row(game, box, height, reward, claimed_flag, best):
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color("ffffff") if claimed_flag else Color("f8f4f6")
	row_style.set_corner_radius_all(10)
	row_panel.add_stylebox_override("panel", row_style)
	var hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "🌸 第 %d 层 · 奖励 %d" % [height, reward]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_font_override("font", game._font_at_size(14))
	name_label.add_color_override("font_color", Color("8f6b80"))
	hbox.add_child(name_label)
	var state_label = Label.new()
	if claimed_flag:
		state_label.text = "✓ 已登顶"
		state_label.add_color_override("font_color", Color("0ca678"))
	elif best > 0:
		state_label.text = "还差 %d 层" % (height - best)
		state_label.add_color_override("font_color", Color("adb5bd"))
	else:
		state_label.text = "未开始"
		state_label.add_color_override("font_color", Color("adb5bd"))
	state_label.add_font_override("font", game._font_at_size(14))
	hbox.add_child(state_label)
	row_panel.add_child(hbox)
	box.add_child(row_panel)

static func _total_icons(game):
	var total = 0
	for icon_set in game.icon_sets:
		total += icon_set.get("icons", []).size()
	return total

# --- 活动日历：周末双倍樱花 + 节日限定奖池（events_calendar.gd 供数） ---

static func _build_events(game):
	var page_content = game.page_content
	PAGE_UI.page_frame(game, page_content, "🎉 活动", "限时活动与限定奖励")
	var box = PAGE_UI.scroll_area(game, page_content)
	var today = OS.get_date()
	_build_events_weekend(game, box, today)
	_build_events_festival(game, box, today)
	_build_events_calendar(game, box, today)

static func _build_events_weekend(game, box, today):
	var weekend_box = _event_card(game, "🌈 周末双倍樱花")
	var weekend_status = Label.new()
	if EVENTS.is_weekend(today):
		weekend_status.text = "进行中！今天所有樱花入账 x2（关卡/玩法/里程碑通用）"
		weekend_status.add_color_override("font_color", Color("2f9e44"))
	else:
		var days = (6 - int(today.weekday)) % 7
		weekend_status.text = "休息中 · %d 天后开启（周六、周日入账 x2）" % days
		weekend_status.add_color_override("font_color", Color("8f6b80"))
	weekend_status.autowrap = true
	weekend_status.add_font_override("font", game._font_at_size(13))
	weekend_box.add_child(weekend_status)
	box.add_child(weekend_box.get_parent())

static func _build_events_festival(game, box, today):
	var festival = EVENTS.festival_for(today)
	if festival.empty():
		var next_days = EVENTS.days_until_next_festival(today)
		var quiet_box = _event_card(game, "🎈 今日限定")
		var quiet_label = Label.new()
		quiet_label.text = "今天没有节日活动" + ("，下一个活动在 %d 天后" % next_days if next_days >= 0 else "")
		quiet_label.autowrap = true
		quiet_label.add_font_override("font", game._font_at_size(13))
		quiet_label.add_color_override("font_color", Color("8f6b80"))
		quiet_box.add_child(quiet_label)
		box.add_child(quiet_box.get_parent())
		return
	var fest_box = _event_card(game, "%s %s · 限定奖池" % [str(festival["emoji"]), str(festival["name"])])
	var fest_label = Label.new()
	fest_label.text = "今日限定礼盒 🌸x%d，每个存档限领一次" % int(festival["chest"])
	fest_label.autowrap = true
	fest_label.add_font_override("font", game._font_at_size(13))
	fest_label.add_color_override("font_color", Color("8f6b80"))
	fest_box.add_child(fest_label)
	if EVENTS.chest_claimed(game.progression_state, festival["id"]):
		var claimed = Label.new()
		claimed.text = "✓ 已领取，明年节日再见"
		claimed.add_font_override("font", game._font_at_size(13))
		claimed.add_color_override("font_color", Color("0ca678"))
		fest_box.add_child(claimed)
	else:
		var claim = Button.new()
		claim.text = "🎁 领取限定礼盒"
		claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim.rect_min_size = Vector2(0, 40)
		claim.add_font_override("font", game.game_font)
		claim.connect("pressed", game, "_on_event_chest_claimed", [str(festival["id"]), int(festival["chest"])])
		fest_box.add_child(claim)
	box.add_child(fest_box.get_parent())

static func _build_events_calendar(game, box, today):
	var upcoming_box = _event_card(game, "📅 节日日历")
	for entry in _upcoming_festivals(today, 3):
		var row = Label.new()
		row.text = "%s %s · %d月%d日（%s）" % [str(entry["emoji"]), str(entry["name"]), int(entry["month"]), int(entry["day"]), entry["when"]]
		row.add_font_override("font", game._font_at_size(13))
		row.add_color_override("font_color", Color("5c3a4d"))
		upcoming_box.add_child(row)
	box.add_child(upcoming_box.get_parent())

static func _event_card(game, title_text):
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("ffffff")
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color("f09ebb")
	card.add_stylebox_override("panel", style)
	var card_box = VBoxContainer.new()
	card_box.add_constant_override("separation", 8)
	card.add_child(card_box)
	var title = Label.new()
	title.text = title_text
	title.add_font_override("font", game._font_at_size(15))
	title.add_color_override("font_color", Color("a85878"))
	card_box.add_child(title)
	return card_box

# Next `count` festivals from today (today inclusive, marked 今日).
static func _upcoming_festivals(today, count):
	var found = []
	var epoch_today = EVENTS._epoch_of(today)
	for offset in range(0, 367):
		var probe = OS.get_datetime_from_unix_time(epoch_today + offset * 86400)
		var festival = EVENTS.festival_for(probe)
		if festival.empty():
			continue
		var entry = festival.duplicate()
		entry["month"] = int(probe.month)
		entry["day"] = int(probe.day)
		entry["when"] = "今天" if offset == 0 else ("%d 天后" % offset)
		found.append(entry)
		if found.size() >= int(count):
			break
	return found
