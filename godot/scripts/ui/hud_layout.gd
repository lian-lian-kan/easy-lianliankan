extends Reference

# Screen adaptation: viewport classification and the responsive layout pass
# (board height, margins, grid separation, stat/control sizing, portrait
# header compaction). Extracted from ui_hud.gd so the main-screen module
# stays build/refresh only.
static func update_layout(game):
	if game.board_wrapper == null or game.board_grid == null:
		return
	# Get viewport size for responsive layout
	var viewport_size = game.get_viewport_rect().size
	var flags = game._viewport_flags(viewport_size)
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]
	_apply_board_height(game, viewport_size, flags)
	_apply_margins(game, flags)
	_apply_header_visibility(game, flags)
	_apply_separations(game, flags)
	_apply_stat_card_sizes(game, flags)
	_apply_control_sizes(game, flags)
	_apply_header_compaction(game, flags)
	_apply_nav_visibility(game, flags)
	game._update_modal_panel_sizes(viewport_size, flags["is_portrait"])
	# Tile sizing depends on the wrapper frame above; re-run once the
	# container has actually applied it, or tiles stay at the boot-time size.
	game.call_deferred("_update_tile_sizes")


# Board-first contract: the canvas is guaranteed >=90% of the viewport
# height in EVERY viewport class. The wrapper is EXPAND_FILL with stretch
# ratio 1.0, so it absorbs whatever the one-line header leaves; the min
# below is the hard floor the container honors on top of that.
static func _apply_board_height(game, viewport_size, flags):
	var wanted = max(game.BOARD_MIN_HEIGHT, viewport_size.y * game.BOARD_RATIO_MIN)
	game.board_wrapper.rect_min_size = Vector2(0, wanted)


# page margins: thin everywhere, the board is the product. Floating banners
# park just above where the nav bar sits while it is visible.
static func _apply_margins(game, flags):
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]
	# Portrait phones keep their zero side rails; everything else gets a
	# 4px hairline so tiles can run nearly edge to edge.
	var margin_value = 0 if (is_mobile and is_portrait) else 4
	# The nav is a page-only footer now, so on the board view these floats
	# park just above the thin bottom cushion.
	var nav_strip = 40 if is_mobile else 64
	var board_bottom_reserve = 6
	# Keep the floating message banner parked just above the navigation bar.
	if game.message_label:
		game.message_label.margin_bottom = -(nav_strip + 4)
	if game.husband_button:
		game.husband_button.margin_bottom = -(nav_strip + 42)
	if game.margin_container:
		game.margin_container.add_constant_override("margin_left", margin_value)
		game.margin_container.add_constant_override("margin_right", margin_value)
		game.margin_container.add_constant_override("margin_top", margin_value)
		game.margin_container.add_constant_override("margin_bottom", margin_value + board_bottom_reserve)


# header visibility that follows the viewport class.
static func _apply_header_visibility(game, flags):
	var is_mobile = flags["is_mobile"]
	# Adjust header font sizes
	if game.title_label:
		pass
	if game.subtitle_label:
		pass
	if game.desc_label:
		game.desc_label.visible = not is_mobile

	# Power-up shortcut chips only make sense with a keyboard.
	for power_up_id in game.power_up_labels:
		var labels = game.power_up_labels[power_up_id]
		if labels.has("shortcut") and labels["shortcut"] != null:
			labels["shortcut"].visible = not is_mobile


# grid/flow separations per viewport class.
static func _apply_separations(game, flags):
	var is_mobile = flags["is_mobile"]
	var is_compact_height = flags["is_compact_height"]
	# Tight grid gaps on every class: the freed pixels go to the tiles.
	if is_mobile and is_compact_height:
		game.board_grid.add_constant_override("h_separation", 2)
		game.board_grid.add_constant_override("v_separation", 2)
	elif is_mobile:
		game.board_grid.add_constant_override("h_separation", 2)
		game.board_grid.add_constant_override("v_separation", 2)
	else:
		game.board_grid.add_constant_override("h_separation", 6)
		game.board_grid.add_constant_override("v_separation", 6)

	if game.stats_flow_container:
		game.stats_flow_container.add_constant_override("h_separation", 4 if is_mobile else 6)
		game.stats_flow_container.add_constant_override("v_separation", 6 if is_mobile else 6)


# stat cards: value-only pills on every class — the board owns the pixels.
static func _apply_stat_card_sizes(game, flags):
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var stat_card_size = Vector2(60, 24) if is_mobile else Vector2(72, 26)
	var stat_value_size = 14 if is_mobile else 16
	var stat_title_size = 10 if is_mobile else 11
	for key in game.stat_values.keys():
		var card = game.stat_values[key]["card"]
		var title_small = game.stat_values[key]["title"]
		var value_label = game.stat_values[key]["value"]
		card.rect_min_size = stat_card_size
		# Cards are value-only pills: the title row yields to the board (the
		# four survivors — 总分/剩余/倒计时/连击 — read clearly from context),
		# and the clipped value holder shrinks to match.
		title_small.visible = false
		var value_holder = value_label.get_parent()
		value_holder.rect_min_size = Vector2(56 if is_mobile else 64, stat_value_size + 8)
		title_small.rect_min_size = Vector2(0, stat_title_size + 4)
		value_label.rect_min_size = Vector2(0, stat_value_size + 6)


# control buttons sizing (portrait/compact 44x26, desktop 72x32 — one HUD
# line on every class; dropdowns/jump/clear live in panels and pages).
static func _apply_control_sizes(game, flags):
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]
	var control_min = Vector2(44, 26) if is_mobile else Vector2(72, 32)
	for button in [game.hint_button, game.auto_button, game.shuffle_button, game.pause_button, game.reset_button, game.jump_level_button, game.clear_progress_button, game.modes_button]:
		if button:
			button.rect_min_size = control_min
			button.add_font_override("font", game._font_at_size(12 if is_mobile else 14))
	if game.settings_button:
		game.settings_button.rect_min_size = control_min
		game.settings_button.add_font_override("font", game._font_at_size(12 if is_mobile else 14))

	if game.controls_flow_container:
		game.controls_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		game.controls_flow_container.add_constant_override("v_separation", 4 if is_mobile else 6)
		# Narrow phones wrap the HUD line; centered rows read tidy there.
		game.controls_flow_container.alignment = BoxContainer.ALIGN_CENTER if (is_mobile and is_portrait) else BoxContainer.ALIGN_BEGIN


# every class compresses the header to the single HUD line; the board owns
# the screen (update_layout re-runs idempotently on resize).
static func _apply_header_compaction(game, flags):
	_compact_header(game)
	_hide_header_extras(game)


# hide every strip that is not the board or the one HUD line.
static func _compact_header(game):
	if game.root_vbox:
		game.root_vbox.add_constant_override("separation", 2)
	if game.header_box:
		game.header_box.add_constant_override("separation", 2)
	# The board is the product: the whole title strip (name / wallet chip)
	# yields its row — the wallet stays visible on the shop & gift pages.
	if game.title_row:
		game.title_row.visible = false
	# Progress bars are meta feedback; the journey page owns progress.
	if game.level_progress_bar:
		game.level_progress_bar.visible = false
	# Power-up counts are passive read-outs; the tray HUD and tiles carry
	# the state — the row yields to the board as well.
	if game.power_ups_container:
		game.power_ups_container.visible = false
	# Title column extras: status/meta chips are noise.
	if game.subtitle_label:
		game.subtitle_label.visible = false
	if game.desc_label:
		game.desc_label.visible = false
	if game.status_chip_label:
		game.status_chip_label.visible = false
	if game.mode_chip_label:
		game.mode_chip_label.visible = false
	if game.kinds_chip_label:
		game.kinds_chip_label.visible = false
	if game.level_progress_caption_label:
		game.level_progress_caption_label.visible = false
	if game.combo_progress_bar:
		game.combo_progress_bar.visible = false
	if game.jump_level_button:
		game.jump_level_button.visible = false
	if game.clear_progress_button:
		game.clear_progress_button.visible = false


# dropdowns and secondary stat cards yield on every class: set picking
# lives in the shop page, level picking in the journey map.
static func _hide_header_extras(game):
	if game.icon_set_option:
		game.icon_set_option.visible = false
	if game.level_select_option:
		game.level_select_option.visible = false
	if game.level_select_label:
		game.level_select_label.visible = false
	# The four essential cards (总分/剩余/倒计时/连击) stay in the HUD line.
	for hidden_key in ["level_score", "moves", "best_total_score", "best_combo"]:
		if game.stat_values.has(hidden_key) and game.stat_values[hidden_key].has("card"):
			game.stat_values[hidden_key]["card"].visible = false


# The nav bar is a page-switcher: touch screens keep it (their only entry
# to the meta pages); desktop shows it only while a page is open, so the
# home board plays chrome-free. get() keeps partial fakes without the
# members safe.
# The nav is a page-only footer now: the board view keeps zero bottom chrome
# (all controls live in the single top toolbar), and the bar reappears while
# a meta page is open. get() keeps partial fakes without the members safe.
static func _apply_nav_visibility(game, flags):
	var nav_bar = game.get("nav_bar")
	if nav_bar == null:
		return
	var pages_root = game.get("pages_root")
	var pages_open = pages_root != null and pages_root.visible
	nav_bar.visible = pages_open


static func _viewport_flags(game, viewport_size):
	var short_side = min(viewport_size.x, viewport_size.y)
	var is_mobile = short_side <= game.MOBILE_SHORT_SIDE_MAX
	var is_portrait = viewport_size.y >= viewport_size.x
	var is_compact_height = viewport_size.y <= game.MOBILE_COMPACT_HEIGHT_MAX
	return {
		"is_mobile": is_mobile,
		"is_portrait": is_portrait,
		"is_compact_height": is_compact_height
	}
