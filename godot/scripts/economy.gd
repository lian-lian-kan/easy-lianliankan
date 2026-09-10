extends Reference

# Blossom economy: the wallet chip, the daily sign-in page, the theme shop
# and the collect-challenge progress counter. Pure meta-economy; page
# scaffolding comes from page_ui.gd, navigation stays in page_router.gd.

const PAGE_UI = preload("res://scripts/page_ui.gd")
const SPECIAL_MODES_SCRIPT = preload("res://scripts/special_modes.gd")

const SIGNIN_REWARDS = [5, 10, 15, 20, 25, 35, 50]
const SET_PRICE = 30
const COLLECT_REWARD = 2
const THEME_PRICE = 40

# Board ambience themes (light palettes only: body text stays dark).
# id -> {name, price, bg}
const THEMES = {
	"sakura": {"name": "樱花粉", "price": 0, "bg": "fff0f6"},
	"mint": {"name": "薄荷绿", "price": 40, "bg": "eafaf1"},
	"sky": {"name": "晴空蓝", "price": 40, "bg": "e8f4fd"},
	"cream": {"name": "奶油白", "price": 40, "bg": "fdf6ec"},
	"lavender": {"name": "薰衣草", "price": 60, "bg": "f3ecfd"},
}

# --- Wallet ---

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

static func update_coin_label(game):
	if game.coin_label:
		game.coin_label.text = "🌸 " + str(int(game.progression_state.get("coins", 0)))

# --- Collect challenge: target progress + pattern collection ---

static func build_collect_row(game):
	# Target progress strip (visible only during the collect challenge).
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("fff0f6")
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color("f09ebb")
	row.add_stylebox_override("panel", style)
	row.visible = false
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGN_CENTER
	row.add_child(hbox)
	game.collect_row = row
	game.collect_labels = []
	for i in range(3):
		var label = Label.new()
		label.add_font_override("font", game._font_at_size(14))
		label.add_color_override("font_color", Color("d6336c"))
		hbox.add_child(label)
		game.collect_labels.append(label)
	return row

static func update_collect_labels(game):
	var icons: Array = game.icon_sets[game.icon_set_index].get("icons", [])
	for i in range(game.collect_labels.size()):
		var label = game.collect_labels[i]
		if label == null:
			continue
		var pattern_keys = game.collect_targets.keys()
		if i >= pattern_keys.size():
			label.text = ""
			continue
		var pattern = int(pattern_keys[i])
		var glyph = _pattern_glyph(game, pattern)
		label.text = "%s %d/%d" % [glyph, int(game.collect_progress.get(pattern, 0)), int(game.collect_targets[pattern])]

static func collect_pair(game, patterns):
	# Count cleared pairs toward the collect-challenge targets.
	if game.special_mode != "collect" or game.collect_targets.empty():
		return
	var changed = false
	for pattern in patterns:
		if game.collect_targets.has(pattern) and int(game.collect_progress.get(pattern, 0)) < int(game.collect_targets[pattern]):
			game.collect_progress[pattern] = int(game.collect_progress.get(pattern, 0)) + 1
			changed = true
	update_collect_labels(game)
	if not changed:
		return
	var all_done = true
	for pattern in game.collect_targets:
		if int(game.collect_progress.get(pattern, 0)) < int(game.collect_targets[pattern]):
			all_done = false
	if all_done:
		game._resolve_collect_clear()

static func _pattern_glyph(game, pattern) -> String:
	var icons: Array = game.icon_sets[game.icon_set_index].get("icons", [])
	if pattern < icons.size():
		return str(icons[pattern])
	return "?"

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
		var key = collection_key(set_id, i)
		if not collected.has(key):
			fresh_ids.append(key)
	if fresh_ids.size() > 0:
		var reward = COLLECT_REWARD * fresh_ids.size()
		game._patch_progress_state({"collect_many": fresh_ids, "coins_delta": reward})
		game._show_message("图鉴新收集 x%d · 🌸+%d" % [fresh_ids.size(), reward], 1.4)

static func collection_key(set_id, icon_index):
	return "%s:%d" % [str(set_id), int(icon_index)]

# --- Level-clear reward ---

static func level_clear_reward(level) -> int:
	return 8 + 2 * int(level.get("id", 1))

static func award_level_clear(game, level):
	# Pure calculation: the caller folds the reward into its own progress
	# patch so the coins are applied exactly once.
	return level_clear_reward(level)

# --- Sign-in page ---

static func build_signin(game):
	var page_content = game.page_content
	PAGE_UI.page_frame(game, page_content, "🎁 每日有礼", "连续签到，樱花好礼不断档")
	var box = PAGE_UI.scroll_area(game, page_content)
	var today = SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	var yesterday = SPECIAL_MODES_SCRIPT.date_string(yesterday_dict())
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
		grid.add_child(_signin_cell(game, day, signed_today, slot, today, yesterday))

static func _signin_cell(game, day, signed_today, slot, today, yesterday):
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
	return cell

static func yesterday_dict() -> Dictionary:
	var day = OS.get_date()
	var epoch = OS.get_unix_time_from_datetime(day) - 86400
	return OS.get_datetime_from_unix_time(epoch)

static func claim_signin(game, today, yesterday):
	# Double-tap guard: the patch below is a no-op on streaks, but the coin
	# delta must only fire once per day.
	if str(game.progression_state.get("last_signin", "")) == today:
		return
	# The reward slot follows the NEW streak: a broken streak restarts at
	# day 1 (lowest reward), a continuous run advances one slot per day and
	# wraps after day 7.
	var prev_streak = int(game.progression_state.get("signin_streak", 0))
	var prev_last = str(game.progression_state.get("last_signin", ""))
	var new_streak = game.SPECIAL_MODES_SCRIPT.next_daily_streak(prev_last, today, yesterday, prev_streak)
	var slot = (new_streak - 1) % SIGNIN_REWARDS.size()
	var reward = SIGNIN_REWARDS[slot]
	game._patch_progress_state({
		"signin": {"date": today, "yesterday": yesterday},
		"signin_streak": new_streak,
		"last_signin": today,
		"coins_delta": reward,
	})
	game._show_message("签到成功 · 第%d天 · 🌸+%d" % [new_streak, reward], 1.4)
	refresh_economy_page(game)

# --- Theme shop page ---

static func build_shop(game):
	var page_content = game.page_content
	var owned: Array = game.progression_state.get("owned_sets", ["fruit"])
	var current_set = game.icon_sets[game.icon_set_index] if game.icon_sets.size() > 0 else {}
	PAGE_UI.page_frame(game, page_content, "🛍️ 小铺", "樱花币解锁新图集 · 已拥有 %d/%d 套" % [owned.size(), game.icon_sets.size()])
	var box = PAGE_UI.scroll_area(game, page_content)

	# ambience themes section
	var theme_title = Label.new()
	theme_title.text = "🌫️ 氛围主题"
	theme_title.add_font_override("font", game._font_at_size(15))
	theme_title.add_color_override("font_color", Color("a85878"))
	box.add_child(theme_title)
	var theme_grid = GridContainer.new()
	theme_grid.columns = 2
	theme_grid.add_constant_override("h_separation", 8)
	theme_grid.add_constant_override("v_separation", 8)
	box.add_child(theme_grid)
	var owned_themes: Array = game.progression_state.get("owned_themes", ["sakura"])
	var current_theme = str(game.progression_state.get("current_theme", "sakura"))
	for theme_id in THEMES:
		var theme: Dictionary = THEMES[theme_id]
		var theme_owned: bool = owned_themes.has(theme_id)
		var theme_in_use: bool = current_theme == theme_id
		var theme_card = PanelContainer.new()
		game._apply_glass_style(theme_card, Color("ffffff"), 0.88)
		theme_grid.add_child(theme_card)
		var theme_box = VBoxContainer.new()
		theme_box.add_constant_override("separation", 4)
		theme_card.add_child(theme_box)
		var theme_name = Label.new()
		theme_name.text = str(theme["name"])
		theme_name.align = Label.ALIGN_CENTER
		theme_name.add_font_override("font", game._font_at_size(14))
		theme_name.add_color_override("font_color", Color("5c3a4d"))
		theme_box.add_child(theme_name)
		var swatch = ColorRect.new()
		swatch.color = Color(str(theme["bg"]))
		swatch.rect_min_size = Vector2(0, 18)
		theme_box.add_child(swatch)
		var theme_action = Button.new()
		if theme_in_use:
			theme_action.text = "使用中"
		elif theme_owned:
			theme_action.text = "使用"
		else:
			theme_action.text = "🌸%d 解锁" % int(theme["price"])
		theme_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_action.add_font_override("font", game._font_at_size(13))
		game._apply_button_style(theme_action, Color("f06ba8"), Color("d6336c"))
		theme_action.add_color_override("font_color", Color("ffffff"))
		if theme_in_use:
			theme_action.disabled = true
		elif theme_owned:
			theme_action.connect("pressed", game, "_on_theme_use_pressed", [theme_id])
		else:
			theme_action.connect("pressed", game, "_on_theme_buy_pressed", [theme_id])
		theme_box.add_child(theme_action)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("h_separation", 8)
	grid.add_constant_override("v_separation", 8)
	box.add_child(grid)
	for set_index in range(game.icon_sets.size()):
		grid.add_child(_shop_card(game, set_index, owned, current_set))

static func _shop_card(game, set_index, owned, current_set):
	var icon_set: Dictionary = game.icon_sets[set_index]
	var set_id = str(icon_set.get("id", str(set_index)))
	var icons: Array = icon_set.get("icons", [])
	var is_owned = owned.has(set_id)
	var in_use = current_set.get("id", "") == set_id
	var card = PanelContainer.new()
	game._apply_glass_style(card, Color("ffffff"), 0.88)
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
	return card

static func use_icon_set(game, set_index):
	if set_index < 0 or set_index >= game.icon_sets.size():
		return
	game.icon_set_index = set_index
	game._populate_icon_set_options()
	game._refresh_board_visuals()
	var icon_set: Dictionary = game.icon_sets[set_index]
	game._show_message("已启用图集：" + str(icon_set.get("name", "图集")), 1.2)
	refresh_economy_page(game)

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

static func apply_theme(game, theme_id):
	var theme: Dictionary = THEMES.get(theme_id, {})
	if theme.empty() or game.bg_rect == null:
		return
	game.bg_rect.color = Color(str(theme["bg"]))
	game.current_theme_id = theme_id

static func use_theme(game, theme_id):
	if not THEMES.has(theme_id):
		return
	game._patch_progress_state({"current_theme": theme_id})
	apply_theme(game, theme_id)
	game._show_message("已启用氛围：" + str(THEMES[theme_id]["name"]), 1.2)
	refresh_economy_page(game)

static func buy_theme(game, theme_id):
	if not THEMES.has(theme_id):
		return
	var owned_themes: Array = game.progression_state.get("owned_themes", ["sakura"])
	if owned_themes.has(theme_id):
		use_theme(game, theme_id)
		return
	var price = int(THEMES[theme_id]["price"])
	var coins = int(game.progression_state.get("coins", 0))
	if coins < price:
		game._show_message("樱花币不足，还差 %d 🌸" % (price - coins), 1.4)
		return
	game._patch_progress_state({"coins_delta": -price, "unlock_theme": theme_id})
	game._show_message("解锁氛围：" + str(THEMES[theme_id]["name"]) + "！", 1.4)
	use_theme(game, theme_id)

static func refresh_economy_page(game):
	update_coin_label(game)
	match game.current_page:
		"signin":
			build_signin(game)
		"shop":
			build_shop(game)
