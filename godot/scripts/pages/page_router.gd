extends Reference

# Multi-page shell: bottom navigation + full-screen meta pages layered over
# the home board. Opening a page pauses the running stage through the modal
# lifecycle (ui_panels.open_modal). This file owns the routing shell and the
# flow pages (玩法大厅 / 任务 — 动线闭环的出口); record pages (旅程/图鉴/
# 数据/大树/成就) live in page_records.gd, the events page in page_events.gd,
# and the economy pages (sign-in / shop) in economy.gd.

const UI_PANELS = preload("res://scripts/ui/ui_panels.gd")
const PAGE_UI = preload("res://scripts/pages/page_ui.gd")
const ECONOMY = preload("res://scripts/pages/economy.gd")
const PAGE_RECORDS = preload("res://scripts/pages/page_records.gd")
# 注意：别名不能叫 PAGE_EVENTS——与下面的页面 id 常量 PAGE_EVENTS = "events" 撞名。
const EVENTS_PAGE = preload("res://scripts/pages/page_events.gd")

const PAGE_LEVEL_MAP = "level_map"
const PAGE_COLLECTION = "collection"
const PAGE_SIGNIN = "signin"
const PAGE_SHOP = "shop"
const PAGE_STATS = "stats"
const PAGE_TREE_MAP = "tree_map"
const PAGE_EVENTS = "events"
const PAGE_MODES = "modes"
const PAGE_MISSIONS = "missions"
const PAGE_ACHIEVEMENTS = "achievements"

static func nav_items():
	return [
		["home", "🏠", "主页"],
		[PAGE_MODES, "🎮", "玩法"],
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
		var button = _nav_button(game, item)
		nav.add_child(button)
		game.nav_buttons[item[0]] = button

static func _nav_button(game, item):
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
	return button

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
	var stage_callout = game.get("stage_callout_label")
	if stage_callout:
		stage_callout.visible = false
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
			PAGE_RECORDS._build_level_map(game)
		PAGE_COLLECTION:
			PAGE_RECORDS._build_collection(game)
		PAGE_SIGNIN:
			ECONOMY.build_signin(game)
		PAGE_SHOP:
			ECONOMY.build_shop(game)
		PAGE_STATS:
			PAGE_RECORDS._build_stats(game)
		PAGE_TREE_MAP:
			PAGE_RECORDS._build_tree_map(game)
		PAGE_EVENTS:
			EVENTS_PAGE._build_events(game)
		PAGE_MODES:
			_build_modes_hub(game)
		PAGE_MISSIONS:
			_build_missions(game)
		PAGE_ACHIEVEMENTS:
			PAGE_RECORDS._build_achievements(game)

# Refresh the open page in place (a claim mutating its own page rebuilds it).
static func rebuild_page(game):
	if game.current_page == "" or game.page_content == null:
		return
	_route_page(game, game.current_page)

static func close_page(game):
	UI_PANELS.close_modal(game, game.pages_root)
	# Back to the board-first home: the nav parks again (page-only footer).
	var nav_bar = game.get("nav_bar")
	if nav_bar != null:
		nav_bar.visible = false
	# Resume a settle that was interrupted by opening the page.
	if game.stage_status == game.STATUS_CLEARED and game.pending_level_index >= 0 \
			and game.level_advance_timer:
		game.level_advance_timer.start()
	game.current_page = ""

# 图鉴/数据页共用的图案总数；start_screen 的钱包行也经这里取数。
static func _total_icons(game):
	return PAGE_RECORDS._total_icons(game)

# --- 玩法大厅：每个玩法都是一等模块——全屏分类章节 + 工坊入口，不再是弹框 ---

static func _build_modes_hub(game):
	var page_content = game.page_content
	PAGE_UI.page_frame(game, page_content, "🎮 玩法大厅", "每种玩法都是独立模块 · 点开即玩")
	var box = PAGE_UI.scroll_area(game, page_content)
	box.add_child(_workshop_entry(game))

	var rows_by_id = {}
	for row in game.SPECIAL_MODES_SCRIPT.modes_panel_rows(game.progression_state):
		rows_by_id[row["id"]] = row
	var unlocked_index = int(game.progression_state.get("highest_unlocked_level_index", 0))
	for category in game.SPECIAL_MODES_SCRIPT.mode_categories():
		var header = Label.new()
		header.text = str(category["title"])
		header.add_font_override("font", game._font_at_size(15))
		header.add_color_override("font_color", Color("9c6b7f"))
		box.add_child(header)
		for mode_id in category["modes"]:
			var row = rows_by_id.get(mode_id, null)
			if row == null:
				continue
			var config = game.game_mode_configs.get(mode_id, {})
			var unlocked = game.SPECIAL_MODES_SCRIPT.is_mode_unlocked(mode_id, config, unlocked_index)
			box.add_child(_mode_card(game, mode_id, row, config, unlocked))

# 工坊入口：白卡主按钮样式，合上页面再开编辑器弹窗。
static func _workshop_entry(game):
	var workshop = Button.new()
	workshop.text = "🎨 关卡工坊 · 自制关卡 + 分享码挑战"
	workshop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop.rect_min_size = Vector2(0, 48)
	workshop.add_font_override("font", game.game_font)
	workshop.connect("pressed", game, "_on_modes_hub_workshop_pressed")
	game._style_dialog_buttons(workshop)
	return workshop

# 玩法条目卡：可玩白卡点开即玩；锁定卡灰置并写明解锁条件。
static func _mode_card(game, mode_id, row, config, unlocked):
	var card = Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.rect_min_size = Vector2(0, 56)
	card.add_font_override("font", game.game_font)
	if unlocked:
		card.text = str(row["title"]) + "\n" + str(row["detail"])
		card.connect("pressed", game, "_on_special_mode_pressed", [mode_id])
	else:
		card.text = str(row["title"]) + "\n" + game.SPECIAL_MODES_SCRIPT.unlock_requirement_text(mode_id, config)
		card.disabled = true
	# 白卡玩法条目：大厅读起来是产品清单而非一排默认灰按钮。
	game._style_secondary_button(card)
	return card

# --- 任务页：周任务进度 + 领取 + 前往（任务动线闭环的出口） ---

# 每个任务的去处：闯关类去旅程、特殊类去大厅、对局行为类直接回棋盘开局。
const MISSION_GO_TARGETS = {
	"levels_5": "journey",
	"specials_3": "modes",
	"pairs_30": "board",
	"combo_5": "board",
	"coins_100": "board",
}
const MISSION_GO_LABELS = {
	"journey": "🗺️ 去闯关",
	"modes": "🎮 去玩法",
	"board": "▶ 去开局",
}

static func _build_missions(game):
	var page_content = game.page_content
	var state = game.MISSIONS.active_state(game)
	PAGE_UI.page_frame(game, page_content, "📋 任务", "每周刷新 · 完成后回这里领取樱花币")
	var box = PAGE_UI.scroll_area(game, page_content)

	box.add_child(_missions_reset_hint(game))
	for task_id in game.MISSIONS.MISSIONS:
		box.add_child(_mission_card(game, task_id, state))
	box.add_child(_missions_footer_hint(game))

# 本周剩余时间：滚动周桶的对齐边界倒推天数。
static func _missions_reset_hint(game):
	var seconds_left = int(game.MISSIONS.WEEK_SECONDS) - int(OS.get_unix_time()) % int(game.MISSIONS.WEEK_SECONDS)
	var days_left = int(ceil(seconds_left / 86400.0))
	var reset_hint = Label.new()
	reset_hint.text = "⏳ 本周任务还有 %d 天刷新" % days_left
	reset_hint.add_font_override("font", game._font_at_size(12))
	reset_hint.add_color_override("font_color", Color("b08a9b"))
	return reset_hint

static func _missions_footer_hint(game):
	var hint = Label.new()
	hint.text = "任意玩法都能攒进度 · 达成后横幅会提醒你回来领取"
	hint.add_font_override("font", game._font_at_size(12))
	hint.add_color_override("font_color", Color("b08a9b"))
	hint.autowrap = true
	return hint

static func _mission_card(game, task_id, state):
	var mission: Dictionary = game.MISSIONS.MISSIONS[task_id]
	var progress = game.MISSIONS.progress_of(state, task_id)
	var target = int(mission["target"])
	var claimed = game.MISSIONS.is_claimed(state, task_id)
	var done = progress >= target

	var card = PanelContainer.new()
	game._apply_glass_style(card, Color("ffffff"), 0.92)
	var card_box = VBoxContainer.new()
	card_box.add_constant_override("separation", 6)
	card.add_child(card_box)

	card_box.add_child(_mission_card_top(game, mission))
	card_box.add_child(_mission_card_actions(game, task_id, claimed, done, progress, target))
	return card

# 卡片首行：任务描述居左、樱花奖励居右。
static func _mission_card_top(game, mission):
	var top_row = HBoxContainer.new()
	var desc = Label.new()
	desc.text = str(mission["desc"])
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_font_override("font", game._font_at_size(14))
	desc.add_color_override("font_color", Color("5c3a4d"))
	top_row.add_child(desc)
	var reward = Label.new()
	reward.text = "🌸 %d" % int(mission["reward"])
	reward.add_font_override("font", game._font_at_size(14))
	reward.add_color_override("font_color", Color("d6336c"))
	top_row.add_child(reward)
	return top_row

# 状态行：已领取打勾 / 可领取亮主按钮 / 进行中给「前往」出口（闭环的动线）。
static func _mission_card_actions(game, task_id, claimed, done, progress, target):
	var bottom_row = HBoxContainer.new()
	bottom_row.add_constant_override("separation", 8)
	var status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_font_override("font", game._font_at_size(12))
	bottom_row.add_child(status)
	if claimed:
		status.text = "✓ 已领取"
		status.add_color_override("font_color", Color("0ca678"))
		return bottom_row
	status.text = "%d / %d" % [progress, target]
	status.add_color_override("font_color", Color("d6336c") if done else Color("a85878"))
	bottom_row.add_child(_mission_action_button(game, task_id, done))
	return bottom_row

static func _mission_action_button(game, task_id, done):
	var action = Button.new()
	action.rect_min_size = Vector2(96, 32)
	action.add_font_override("font", game._font_at_size(12))
	if done:
		action.text = "🌸 领取奖励"
		action.connect("pressed", game, "_on_mission_claim_pressed", [task_id])
		game._style_dialog_buttons(action)
	else:
		var go_target = str(MISSION_GO_TARGETS.get(task_id, "board"))
		action.text = str(MISSION_GO_LABELS[go_target])
		action.connect("pressed", game, "_on_mission_go_pressed", [go_target])
		game._style_secondary_button(action)
	return action
