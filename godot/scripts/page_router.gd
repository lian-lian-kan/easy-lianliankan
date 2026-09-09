extends Reference

# Multi-page shell on top of the home board: a persistent bottom navigation
# and full-screen pages (journey map / collection / sign-in / theme shop)
# layered over the game. Opening a page pauses the running stage through the
# modal lifecycle (ui_panels.open_modal) so the clock never runs in menus.

const UI_PANELS = preload("res://scripts/ui_panels.gd")
const SPECIAL_MODES_SCRIPT = preload("res://scripts/special_modes.gd")

const PAGE_LEVEL_MAP = "level_map"
const PAGE_COLLECTION = "collection"
const PAGE_SIGNIN = "signin"
const PAGE_SHOP = "shop"

# Day-1..7 blossom rewards for the daily sign-in streak (loops after 7).
const SIGNIN_REWARDS = [5, 10, 15, 20, 25, 35, 50]
const SET_PRICE = 30
const COLLECT_REWARD = 2

static func nav_items():
	return [
		["home", "🏠", "主页"],
		[PAGE_LEVEL_MAP, "🗺️", "旅程"],
		[PAGE_COLLECTION, "📖", "图鉴"],
		[PAGE_SIGNIN, "🎁", "有礼"],
		[PAGE_SHOP, "🛍️", "小铺"],
	]

# --- Shell construction (called from ui_hud.build_main_ui) ---

static func build_coin_chip(game):
	# Blossom wallet chip shown in the header row; refresh_ui keeps it in sync.
	var coin_chip = PanelContainer.new()
	var coin_style = StyleBoxFlat.new()
	coin_style.bg_color = Color("fff0f6")
	coin_style.set_corner_radius_all(12)
	coin_style.set_border_width_all(1)
	coin_style.border_color = Color("f09ebb")
	coin_chip.add_stylebox_override("panel", coin_style)
	coin_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin_label = Label.new()
	coin_label.text = "🌸 0"
	coin_label.add_font_override("font", game._font_at_size(14))
	coin_label.add_color_override("font_color", Color("d6336c"))
	coin_chip.add_child(coin_label)
	game.coin_label = coin_label
	return coin_chip

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
	nav.margin_top = -60
	nav.margin_bottom = -8
	nav.add_constant_override("separation", 6)
	game.add_child(nav)
	game.nav_bar = nav
	for item in nav_items():
		var button = Button.new()
		button.text = item[1] + "\n" + item[2]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.rect_min_size = Vector2(0, 52)
		button.add_font_override("font", game._font_at_size(12))
		game._apply_button_style(button, Color("f06ba8"), Color("d6336c"))
		if item[0] == "home":
			button.add_color_override("font_color", Color("ffffff"))
			button.connect("pressed", game, "_on_nav_home_pressed")
		else:
			button.add_color_override("font_color", Color("ffffff"))
			button.connect("pressed", game, "_on_nav_pressed", [item[0]])
		nav.add_child(button)
		game.nav_buttons[item[0]] = button

static func update_coin_label(game):
	if game.coin_label:
		game.coin_label.text = "🌸 " + str(int(game.progression_state.get("coins", 0)))

# --- Navigation ---

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
		_clear_page(game)
		match page_id:
			PAGE_LEVEL_MAP:
				_build_level_map(game)
			PAGE_COLLECTION:
				_build_collection(game)
			PAGE_SIGNIN:
				_build_signin(game)
			PAGE_SHOP:
				_build_shop(game)

static func close_page(game):
	UI_PANELS.close_modal(game, game.pages_root)
	# Resume a settle that was interrupted by opening the page.
	if game.stage_status == game.STATUS_CLEARED and game.pending_level_index >= 0 \
			and game.level_advance_timer:
		game.level_advance_timer.start()
	game.current_page = ""

static func _clear_page(game):
	for child in game.page_content.get_children():
		game.page_content.remove_child(child)
		child.queue_free()

static func _page_frame(game, title, subtitle):
	# Common header: back arrow + page title + optional subtitle line.
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.page_content.add_child(header)
	var back = Button.new()
	back.text = "‹ 返回"
	back.rect_min_size = Vector2(72, 34)
	back.add_font_override("font", game._font_at_size(13))
	game._apply_button_style(back, Color("f06ba8"), Color("d6336c"))
	back.add_color_override("font_color", Color("ffffff"))
	back.connect("pressed", game, "_on_nav_home_pressed")
	header.add_child(back)
	var title_label = Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.align = Label.ALIGN_CENTER
	title_label.add_font_override("font", game._font_at_size(18))
	title_label.add_color_override("font_color", Color("d6336c"))
	header.add_child(title_label)
	if subtitle != "":
		var subtitle_label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.align = Label.ALIGN_CENTER
		subtitle_label.add_font_override("font", game._font_at_size(12))
		subtitle_label.add_color_override("font_color", Color("8f6b80"))
		game.page_content.add_child(subtitle_label)

static func _scroll_area(game):
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_horizontal_enabled = false
	game.page_content.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_constant_override("separation", 10)
	scroll.add_child(box)
	return box

# --- Journey map: 3 chapters x 5 level nodes ---

const CHAPTER_NAMES = ["樱园初语", "花海拾光", "月下奇缘"]

static func _build_level_map(game):
	_page_frame(game, "🗺️ 旅程", "点亮每一座樱园")
	var box = _scroll_area(game)
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
			var level: Dictionary = game.campaign_levels[level_index]
			var unlocked = game._is_level_unlocked(level_index)
			var is_current = level_index == int(game.level_index) and game.special_mode == ""
			var node = Button.new()
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.rect_min_size = Vector2(0, 54)
			node.add_font_override("font", game._font_at_size(14))
			game._apply_button_style(node, Color("f06ba8"), Color("d6336c"))
			if is_current:
				node.text = "▶ 第%d关 · %s" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡"))]
			elif unlocked:
				node.text = "第%d关 · %s" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡"))]
			else:
				node.text = "🔒 第%d关 · %s" % [int(level.get("id", level_index + 1)), str(level.get("name", "关卡"))]
			node.add_color_override("font_color", Color("ffffff") if unlocked else Color("e8b8cc"))
			if unlocked:
				node.connect("pressed", game, "_on_map_level_pressed", [level_index])
			else:
				node.connect("pressed", game, "_on_map_locked_pressed")
			box.add_child(node)

static func _collect_page_reward(game, level):
	var reward = 8 + 2 * int(level.get("id", 1))
	return reward

# --- Collection: every icon set, caught vs mystery ---

static func _build_collection(game):
	var collected: Array = game.progression_state.get("collected", [])
	_page_frame(game, "📖 图鉴", "已收集 %d / %d 个图案" % [collected.size(), _total_icons(game)])
	var box = _scroll_area(game)
	var sets = game.icon_sets
	for set_index in range(sets.size()):
		var icon_set: Dictionary = sets[set_index]
		var icons: Array = icon_set.get("icons", [])
		var set_id = str(icon_set.get("id", str(set_index)))
		var caught = 0
		for i in range(icons.size()):
			if collected.has(_collection_key(set_id, i)):
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
			var cell = PanelContainer.new()
			var cell_style = StyleBoxFlat.new()
			var has_it = collected.has(_collection_key(set_id, i))
			cell_style.bg_color = Color(str(icon_set.get("colors", [])[i % icon_set.get("colors", []).size()])) if has_it else Color("f3e2ea")
			cell_style.set_corner_radius_all(10)
			cell.add_stylebox_override("panel", cell_style)
			var glyph = Label.new()
			glyph.text = str(icons[i]) if has_it else "❓"
			glyph.align = Label.ALIGN_CENTER
			glyph.rect_min_size = Vector2(52, 44)
			glyph.add_font_override("font", game._font_at_size(22 if has_it else 14))
			glyph.modulate = Color(1, 1, 1) if has_it else Color(1, 1, 1, 0.55)
			cell.add_child(glyph)
			grid.add_child(cell)

static func _total_icons(game):
	var total = 0
	for icon_set in game.icon_sets:
		total += icon_set.get("icons", []).size()
	return total

static func _collection_key(set_id, icon_index):
	return "%s:%d" % [str(set_id), int(icon_index)]

# --- Sign-in: looping 7-day streak rewards ---

static func _build_signin(game):
	_page_frame(game, "🎁 每日有礼", "连续签到，樱花好礼不断档")
	var box = _scroll_area(game)
	var today = SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	var yesterday = SPECIAL_MODES_SCRIPT.date_string(_yesterday_dict())
	var streak = int(game.progression_state.get("signin_streak", 0))
	var signed_today = str(game.progression_state.get("last_signin", "")) == today
	var slot = streak % SIGNIN_REWARDS.size()

	var status = Label.new()
	if signed_today:
		status.text = "今日已领取（连续 %d 天）明天再来～" % streak
	else:
		status.text = "连续 %d 天 · 今日可领第 %d 天好礼！" % [streak, slot + 1]
	status.align = Label.ALIGN_CENTER
	status.add_font_override("font", game._font_at_size(13))
	status.add_color_override("font_color", Color("8f6b80"))
	box.add_child(status)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_constant_override("h_separation", 8)
	grid.add_constant_override("v_separation", 8)
	box.add_child(grid)
	for day in range(SIGNIN_REWARDS.size()):
		var cell = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(12)
		var claimed = signed_today and day < slot
		var is_today = (not signed_today) and day == slot
		style.bg_color = Color("ffe3ee") if is_today else (Color("f8e7ef") if claimed else Color("fdf3f7"))
		if is_today:
			style.set_border_width_all(2)
			style.border_color = Color("e64980")
		cell.add_stylebox_override("panel", style)
		cell.rect_min_size = Vector2(72, 64)
		var cell_box = VBoxContainer.new()
		cell.add_child(cell_box)
		var day_label = Label.new()
		day_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		day_label.text = ("第%d天" % (day + 1)) + ("\n🌸%d" % SIGNIN_REWARDS[day]) + ("\n✔ 已领" if claimed else ("\n🎁 可领" if is_today else ""))
		day_label.align = Label.ALIGN_CENTER
		day_label.add_font_override("font", game._font_at_size(12))
		day_label.add_color_override("font_color", Color("d6336c") if is_today else Color("a85878"))
		cell_box.add_child(day_label)
		if is_today:
			var claim = Button.new()
			claim.text = "领取"
			claim.rect_min_size = Vector2(56, 24)
			claim.add_font_override("font", game._font_at_size(12))
			game._apply_button_style(claim, Color("f06ba8"), Color("d6336c"))
			claim.add_color_override("font_color", Color("ffffff"))
			claim.connect("pressed", game, "_on_signin_claim_pressed", [today, yesterday])
			cell_box.add_child(claim)
		grid.add_child(cell)

static func _yesterday_dict() -> Dictionary:
	var day = OS.get_date()
	var epoch = OS.get_unix_time_from_datetime(day) - 86400
	return OS.get_datetime_from_unix_time(epoch)

# --- Theme shop: icon sets bought with blossoms ---

static func _build_shop(game):
	var owned: Array = game.progression_state.get("owned_sets", ["fruit"])
	var current_set = game.icon_sets[game.icon_set_index] if game.icon_sets.size() > 0 else {}
	_page_frame(game, "🛍️ 小铺", "樱花币解锁新图集 · 已拥有 %d/%d 套" % [owned.size(), game.icon_sets.size()])
	var box = _scroll_area(game)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("h_separation", 8)
	grid.add_constant_override("v_separation", 8)
	box.add_child(grid)
	for set_index in range(game.icon_sets.size()):
		var icon_set: Dictionary = game.icon_sets[set_index]
		var set_id = str(icon_set.get("id", str(set_index)))
		var icons: Array = icon_set.get("icons", [])
		var is_owned = owned.has(set_id)
		var in_use = current_set.get("id", "") == set_id
		var card = PanelContainer.new()
		game._apply_glass_style(card, Color("ffffff"), 0.88)
		grid.add_child(card)
		var card_box = VBoxContainer.new()
		card_box.add_constant_override("separation", 4)
		card.add_child(card_box)
		var name_label = Label.new()
		name_label.text = str(icon_set.get("name", "图集"))
		name_label.align = Label.ALIGN_CENTER
		name_label.add_font_override("font", game._font_at_size(14))
		name_label.add_color_override("font_color", Color("5c3a4d"))
		card_box.add_child(name_label)
		var preview = Label.new()
		var preview_text = ""
		for i in range(min(3, icons.size())):
			preview_text += str(icons[i]) + " "
		preview.text = preview_text
		preview.align = Label.ALIGN_CENTER
		preview.add_font_override("font", game._font_at_size(18))
		card_box.add_child(preview)
		var action = Button.new()
		if in_use:
			action.text = "使用中"
		elif is_owned:
			action.text = "使用"
		else:
			action.text = "🌸%d 解锁" % SET_PRICE
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.rect_min_size = Vector2(0, 34)
		action.add_font_override("font", game._font_at_size(13))
		game._apply_button_style(action, Color("f06ba8"), Color("d6336c"))
		action.add_color_override("font_color", Color("ffffff"))
		if in_use:
			action.disabled = true
		elif is_owned:
			action.connect("pressed", game, "_on_shop_use_pressed", [set_index])
		else:
			action.connect("pressed", game, "_on_shop_buy_pressed", [set_index])
		card_box.add_child(action)

# --- Page actions ---

static func claim_signin(game, today, yesterday):
	# Double-tap guard: the patch below is a no-op on streaks, but the coin
	# delta must only fire once per day.
	if str(game.progression_state.get("last_signin", "")) == today:
		return
	var streak = int(game.progression_state.get("signin_streak", 0))
	var slot = streak % SIGNIN_REWARDS.size()
	var reward = SIGNIN_REWARDS[slot]
	game._patch_progress_state({
		"signin": {"date": today, "yesterday": yesterday},
		"coins_delta": reward,
	})
	game._show_message("签到成功 · 🌸+%d" % reward, 1.4)
	refresh_current(game)

static func use_icon_set(game, set_index):
	if set_index < 0 or set_index >= game.icon_sets.size():
		return
	game.icon_set_index = set_index
	game._populate_icon_set_options()
	game._refresh_board_visuals()
	var icon_set: Dictionary = game.icon_sets[set_index]
	game._show_message("已启用图集：" + str(icon_set.get("name", "图集")), 1.2)
	refresh_current(game)

static func buy_icon_set(game, set_index):
	if set_index < 0 or set_index >= game.icon_sets.size():
		return
	var icon_set: Dictionary = game.icon_sets[set_index]
	var set_id = str(icon_set.get("id", str(set_index)))
	var owned: Array = game.progression_state.get("owned_sets", ["fruit"])
	if owned.has(set_id):
		use_icon_set(game, set_index)
		return
	var coins = int(game.progression_state.get("coins", 0))
	if coins < SET_PRICE:
		game._show_message("樱花币不足，还差 %d 🌸" % (SET_PRICE - coins), 1.4)
		return
	game._patch_progress_state({"coins_delta": -SET_PRICE, "unlock_set": set_id})
	game._show_message("解锁图集：" + str(icon_set.get("name", "图集")) + "！", 1.4)
	use_icon_set(game, set_index)

static func refresh_current(game):
	update_coin_label(game)
	match game.current_page:
		PAGE_LEVEL_MAP:
			_build_level_map(game)
		PAGE_COLLECTION:
			_build_collection(game)
		PAGE_SIGNIN:
			_build_signin(game)
		PAGE_SHOP:
			_build_shop(game)

# --- Economy hooks (wired through game thin wrappers) ---

static func collect_level_icons(game):
	# A level's icon set marks its patterns as collected when play begins.
	if game.icon_sets.empty():
		return
	var icon_set: Dictionary = game.icon_sets[game.icon_set_index]
	var set_id = str(icon_set.get("id", ""))
	var icons: Array = icon_set.get("icons", [])
	var collected: Array = game.progression_state.get("collected", [])
	var fresh_ids := []
	for i in range(min(int(game._current_level().get("kinds", icons.size())), icons.size())):
		var key = _collection_key(set_id, i)
		if not collected.has(key):
			fresh_ids.append(key)
	if fresh_ids.size() > 0:
		var reward = COLLECT_REWARD * fresh_ids.size()
		game._patch_progress_state({"collect_many": fresh_ids, "coins_delta": reward})
		game._show_message("图鉴新收集 x%d · 🌸+%d" % [fresh_ids.size(), reward], 1.4)

static func _show_collection_toast(game, fresh, coins):
	if fresh > 0:
		game._show_message("图鉴新收集 x%d · 🌸+%d" % [fresh, coins], 1.4)

static func level_clear_reward(level) -> int:
	return 8 + 2 * int(level.get("id", 1))

static func award_level_clear(game, level):
	# Pure calculation: the caller folds the reward into its own progress
	# patch so the coins are applied exactly once.
	return level_clear_reward(level)
