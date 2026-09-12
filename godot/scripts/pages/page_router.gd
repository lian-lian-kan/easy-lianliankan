extends Reference

# Multi-page shell: bottom navigation + full-screen meta pages layered over
# the home board. Opening a page pauses the running stage through the modal
# lifecycle (ui_panels.open_modal). Journey-map and collection pages are
# built here; economy pages (sign-in / shop) live in economy.gd.

const UI_PANELS = preload("res://scripts/ui/ui_panels.gd")
const PAGE_UI = preload("res://scripts/pages/page_ui.gd")
const ECONOMY = preload("res://scripts/pages/economy.gd")

const PAGE_LEVEL_MAP = "level_map"
const PAGE_COLLECTION = "collection"
const PAGE_SIGNIN = "signin"
const PAGE_SHOP = "shop"
const PAGE_STATS = "stats"

static func nav_items():
	return [
		["home", "🏠", "主页"],
		[PAGE_LEVEL_MAP, "🗺️", "旅程"],
		[PAGE_COLLECTION, "📖", "图鉴"],
		[PAGE_SIGNIN, "🎁", "有礼"],
		[PAGE_SHOP, "🛍️", "小铺"],
	]

static func build_pages(game):
	# Full-screen page surface above the home board; the nav bar is added
	# after it so it stays on top.
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
	if not reopened:
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

static func close_page(game):
	UI_PANELS.close_modal(game, game.pages_root)
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

	var rows := [
		["🏆 最佳总分", str(int(game.progression_state.get("best_total_score", 0)))],
		["🔥 最佳连击", "x" + str(int(game.progression_state.get("best_combo", 0)))],
		["🌸 樱花币", str(int(game.progression_state.get("coins", 0)))],
		["📖 图鉴收集", "%d / %d" % [collected.size(), total_icons]],
		["🎁 连续签到", "%d 天" % int(game.progression_state.get("signin_streak", 0))],
		["📅 每日挑战最佳", str(int(game.progression_state.get("daily_challenge", {}).get("best_score", 0)))],
		["∞ 无尽模式", "第%d轮 · %d分" % [int(game.progression_state.get("endless_best", {}).get("round", 0)), int(game.progression_state.get("endless_best", {}).get("score", 0))]],
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
	]
	for row_data in rows:
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

static func _total_icons(game):
	var total = 0
	for icon_set in game.icon_sets:
		total += icon_set.get("icons", []).size()
	return total
