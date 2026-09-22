extends Reference

# 记录陈列页（page_router 的内容分册）：旅程地图 / 图鉴 / 数据汇总 /
# 攀登树 / 成就——都是「陈列进度与收集」的页面，只渲染不承载动线。
# 页面路由与开关在 page_router.gd；经济页（签到/小铺）在 economy.gd。

const PAGE_UI = preload("res://scripts/pages/page_ui.gd")
const ECONOMY = preload("res://scripts/pages/economy.gd")

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
		box.add_child(_collection_set_panel(game, icon_set, icons, colors, set_id, caught, collected))

# 单个图集白卡：标题行（进度）+ 5 列图案网格。
static func _collection_set_panel(game, icon_set, icons, colors, set_id, caught, collected):
	var set_panel = PanelContainer.new()
	game._apply_glass_style(set_panel, Color("ffffff"), 0.85)
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
	return set_panel

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

# 统计页纪录汇总：头部五行通用数据 + 每日/无尽/树三个专属行 + 玩法最佳分行
# 全部由 MODES 注册表派生（旧手写行已漂移：drag/edu 从未上榜）。
static func _stats_rows(game, collected, total_icons) -> Array:
	var rows = [
		["🏆 最佳总分", str(int(game.progression_state.get("best_total_score", 0)))],
		["🔥 最佳连击", "x" + str(int(game.progression_state.get("best_combo", 0)))],
		["🌸 樱花币", str(int(game.progression_state.get("coins", 0)))],
		["📖 图鉴收集", "%d / %d" % [collected.size(), total_icons]],
		["🎁 连续签到", "%d 天" % int(game.progression_state.get("signin_streak", 0))],
		["📅 每日挑战最佳", str(int(game.progression_state.get("daily_challenge", {}).get("best_score", 0)))],
		["∞ 无尽模式", "第%d轮 · %d分" % [int(game.progression_state.get("endless_best", {}).get("round", 0)), int(game.progression_state.get("endless_best", {}).get("score", 0))]],
		["🌳 攀登树", "最佳第%d层" % int(game.progression_state.get("tree_best_height", 0))],
	]
	var records = game.SPECIAL_MODES_SCRIPT.record_modes()
	for mode_id in game.SPECIAL_MODES_SCRIPT.MODES:
		if not records.has(mode_id) and mode_id != "time_attack":
			continue
		var spec = game.SPECIAL_MODES_SCRIPT.MODES[mode_id]
		rows.append([
			str(spec["icon"]) + " " + str(spec["label"]) + "最佳",
			str(int(game.progression_state.get(str(mode_id) + "_best_score", 0)))
		])
	return rows

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
	hbox.add_child(_tree_milestone_state(game, claimed_flag, best, height))
	row_panel.add_child(hbox)
	box.add_child(row_panel)

static func _tree_milestone_state(game, claimed_flag, best, height):
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
	return state_label

static func _total_icons(game):
	var total = 0
	for icon_set in game.icon_sets:
		total += icon_set.get("icons", []).size()
	return total

# --- 成就页：从设置弹窗升级为一等页面（与图鉴对仗的收集面） ---

static func _build_achievements(game):
	var page_content = game.page_content
	var unlocked_count = 0
	var definitions = game.PROGRESSION_SCRIPT.get_achievement_definitions()
	for achievement in definitions:
		if game.PROGRESSION_SCRIPT.has_achievement(game.progression_state, achievement["id"]):
			unlocked_count += 1
	PAGE_UI.page_frame(game, page_content, "🏆 成就图鉴", "已解锁 %d / %d 项成就" % [unlocked_count, definitions.size()])
	var box = PAGE_UI.scroll_area(game, page_content)
	for achievement in definitions:
		box.add_child(_achievement_item(game, achievement))

static func _achievement_item(game, achievement):
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 12)

	var unlocked = game.PROGRESSION_SCRIPT.has_achievement(game.progression_state, achievement["id"])

	var card = PanelContainer.new()
	game._apply_glass_style(card, Color("ffffff"), 0.92 if unlocked else 0.7)
	card.rect_min_size = Vector2(0, 52)
	hbox.add_child(card)
	var row = HBoxContainer.new()
	row.add_constant_override("separation", 12)
	card.add_child(row)

	row.add_child(_achievement_icon(game, unlocked))
	row.add_child(_achievement_texts(game, achievement, unlocked))

	return hbox

static func _achievement_icon(game, unlocked):
	var icon_label = Label.new()
	icon_label.text = "🏆" if unlocked else "🔒"
	icon_label.add_font_override("font", game._font_at_size(18))
	return icon_label

static func _achievement_texts(game, achievement, unlocked):
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_constant_override("separation", 2)

	var name_label = Label.new()
	name_label.text = str(achievement["name"])
	name_label.add_color_override("font_color", Color("059669") if unlocked else Color("94a3b8"))
	name_label.add_font_override("font", game._font_at_size(14))
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = str(achievement["desc"])
	desc_label.add_color_override("font_color", Color("64748b") if unlocked else Color("cbd5e1"))
	desc_label.add_font_override("font", game._font_at_size(12))
	vbox.add_child(desc_label)

	return vbox
