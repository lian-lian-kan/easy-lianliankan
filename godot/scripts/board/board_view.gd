extends Reference

# Board presentation: tile sizing, per-tile styling (mode/effect states),
# icon mapping. Statics take the live game node and drive its nodes.

static func _refresh_board_visuals(game):
	if game.board.empty() or game.cell_buttons.empty():
		return

	var rows = game.board.size()
	var cols = game.board[0].size()
	var playing = game.stage_status == game.STATUS_PLAYING

	for r in range(rows):
		for c in range(cols):
			var value = int(game.board[r][c])
			var button = game.cell_buttons[r][c]

			if value == 0:
				button.text = ""
				button.disabled = true
				game._apply_cleared_tile_style(button)
				continue

			var face_down = game._is_memory_mode() and not game.memory_previewing 				and not game.memory_revealed.has(game._memory_key(Vector2(r, c))) 				and not (game.selected.x == r and game.selected.y == c)
			var bg = game._color_for(value)
			var border = Color("ffffff")
			if face_down:
				button.text = "❓"
				bg = Color("ffc2d4")
				border = Color("f09ebb")
			else:
				button.text = game._icon_for(value)
			button.disabled = not playing

			var is_selected = (game.selected.x == r and game.selected.y == c)
			var frozen = game._is_frost_mode() and r < game.board_armor.size() \
					and c < game.board_armor[r].size() and int(game.board_armor[r][c]) > 0
			var fogged = game._is_fogged(Vector2(r, c))
			var chained = game._is_chain_mode() and r < game.board_chain.size() \
					and c < game.board_chain[r].size() and int(game.board_chain[r][c]) > 0
			var stacked = game._is_stack_mode() and r < game.board_lower.size() \
					and c < game.board_lower[r].size() and int(game.board_lower[r][c]) > 0
			if frozen:
				# Ice sheet: cool white-blue face with a frost border.
				bg = bg.linear_interpolate(Color("e7f5ff"), 0.72)
				border = Color("a5d8ff")
			var has_effect = false

			if game._contains_coord(game.error_tiles, Vector2(r, c)):
				bg = Color("ffe3e3")
				border = Color("ff8787")
				has_effect = true
			elif game._contains_coord(game.hint_tiles, Vector2(r, c)):
				bg = Color("d0ebff")
				border = Color("3b82f6")
				has_effect = true
			elif frozen:
				has_effect = true
			elif fogged:
				# Fog hides the icon entirely until the rings recede.
				button.text = "❓"
				bg = Color("e9ecef")
				border = Color("adb5bd")
			elif chained:
				border = Color("868e96")
				bg = bg.linear_interpolate(Color("e9ecef"), 0.35)
				has_effect = true
			elif stacked:
				border = Color("9775fa")
				has_effect = true
			elif game.bomb_pending:
				# Armed bomb: warm glow on every tile invites the pick.
				bg = bg.linear_interpolate(Color("fff3bf"), 0.45)
				border = Color("ffd43b")
				has_effect = true
			elif game.rainbow_pending:
				# Armed rainbow: violet shimmer while choosing two tiles.
				bg = bg.linear_interpolate(Color("f3d9fa"), 0.4)
				border = Color("da77f2")
				has_effect = true

			if is_selected:
				border = Color("ff8fab")
				has_effect = true

			game._apply_tile_style(button, bg, border, has_effect or is_selected)
			# Cool tint sells the frost at a glance, even on tiny tiles.
			button.modulate = Color(0.86, 0.95, 1.1) if frozen else Color(1, 1, 1)

static func _update_tile_sizes(game):
	if game.board.empty() or game.cell_buttons.empty():
		return

	var rows = game.board.size()
	var cols = game.board[0].size()
	var h_sep = game.board_grid.get_constant("h_separation")
	var v_sep = game.board_grid.get_constant("v_separation")

	# Get available board area and keep a minimum usable size.
	var viewport_size = game.get_viewport_rect().size
	var flags = game._viewport_flags(viewport_size)
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]
	var padding = 4 if is_mobile and is_compact_height else (4 if is_mobile and is_portrait else (10 if is_mobile else 24))
	var board_area = game.board_wrapper.rect_size
	var wanted_area = game.board_wrapper.rect_min_size
	# Early in boot the VBox has not re-laid-out yet, so rect_size still
	# carries the stale (small) frame and every tile would be computed from
	# it and stay tiny forever. The min_size is the size we just ordered,
	# so prefer it whenever the live frame has not caught up.
	if board_area.y < wanted_area.y - 4:
		board_area.y = wanted_area.y
	if board_area.x <= 1 or board_area.x < wanted_area.x - 4:
		board_area.x = wanted_area.x
	var available = board_area - Vector2(padding * 2, padding * 2)
	available.x = max(available.x, 120.0)
	available.y = max(available.y, 120.0)

	# Calculate tile size to fit all tiles.
	var by_width = int(floor((available.x - float(cols - 1) * h_sep) / max(1, cols)))
	var by_height = int(floor((available.y - float(rows - 1) * v_sep) / max(1, rows)))

	# Clamp tile size: portrait mobile gets larger minimum tiles for readability.
	var min_tile = 34 if is_mobile and is_portrait else (30 if is_mobile else 34)
	var max_tile = 90 if is_mobile and is_portrait else (76 if is_mobile else 110)
	var tile = clamp(min(by_width, by_height), min_tile, max_tile)

	var tile_font = game._font_at_size(int(clamp(float(tile) * 0.52, 14.0, 44.0)))
	for r in range(rows):
		for c in range(cols):
			var button = game.cell_buttons[r][c]
			button.rect_min_size = Vector2(tile, tile)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.add_font_override("font", tile_font)

# Cleared cells vanish entirely: a visible empty tile keeps pulling the
# player's eye long after the pair is gone. The button must keep its place
# in the GridContainer (hiding it would reflow the whole board), so it is
# painted fully transparent instead.
static func _apply_cleared_tile_style(game, button):
	var clear_style = StyleBoxFlat.new()
	clear_style.bg_color = Color(1, 1, 1, 0)
	clear_style.set_border_width_all(0)
	clear_style.set_corner_radius_all(14)
	clear_style.shadow_size = 0
	button.add_stylebox_override("normal", clear_style)
	button.add_stylebox_override("pressed", clear_style)
	button.add_stylebox_override("focus", clear_style)
	button.add_stylebox_override("hover", clear_style)
	button.add_stylebox_override("disabled", clear_style)


static func _apply_tile_style(game, button, bg_color, border_color, highlight):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)

	if highlight:
		normal.shadow_color = border_color
		normal.shadow_size = 6
		normal.shadow_offset = Vector2(0, 2)
	else:
		normal.shadow_color = Color("00000010")
		normal.shadow_size = 3
		normal.shadow_offset = Vector2(0, 2)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.06)
	hover.border_color = border_color.lightened(0.05)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	hover.shadow_color = Color("00000020")
	hover.shadow_size = 5
	hover.shadow_offset = Vector2(0, 3)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.08)
	pressed.border_color = border_color.darkened(0.05)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("disabled", normal)

static func _icon_for(game, value):
	if game.icon_sets.empty():
		return str(value)

	var icon_set: Dictionary = game.icon_sets[game.icon_set_index]
	var icons: Array = icon_set.get("icons", [])
	var index = value - 1
	if index >= 0 and index < icons.size():
		return str(icons[index])
	return str(value)


static func _animate_board_spawn(game):
	if game.board.empty():
		return

	var rows = game.board.size()
	var cols = game.board[0].size()
	var center_r = float(rows - 1) * 0.5
	var center_c = float(cols - 1) * 0.5

	for r in range(rows):
		for c in range(cols):
			if int(game.board[r][c]) == 0:
				continue
			var button = game._try_get_tile_button(Vector2(r, c))
			if button == null:
				continue

			button.rect_pivot_offset = button.rect_size * 0.5
			button.rect_scale = Vector2(0.72, 0.72)
			button.modulate.a = 0.0

			var dist = abs(float(r) - center_r) + abs(float(c) - center_c)
			var delay = dist * 0.025
			var tween = game._make_fx_tween()
			tween.interpolate_property(button, "modulate:a", 0.0, 1.0, 0.09, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
			tween.interpolate_property(button, "rect_scale", Vector2(0.72, 0.72), Vector2.ONE, 0.09, Tween.TRANS_BACK, Tween.EASE_OUT, delay)
			tween.start()


static func _animate_shuffle_wave(game):
	if game.board.empty():
		return

	var rows = game.board.size()
	var cols = game.board[0].size()
	for r in range(rows):
		for c in range(cols):
			if int(game.board[r][c]) == 0:
				continue
			var button = game._try_get_tile_button(Vector2(r, c))
			if button == null:
				continue

			button.rect_pivot_offset = button.rect_size * 0.5
			var delay = float(r + c) * 0.012 + rand_range(0.0, 0.03)

			var tween = game._make_fx_tween()
			tween.interpolate_property(button, "rect_scale", Vector2.ONE, Vector2(0.82, 0.82), 0.07, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
			tween.interpolate_property(button, "rect_scale", Vector2(0.82, 0.82), Vector2(1.08, 1.08), 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay + 0.07)
			tween.interpolate_property(button, "rect_scale", Vector2(1.08, 1.08), Vector2.ONE, 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay + 0.15)
			tween.start()


static func _render_board(game):
	for child in game.board_grid.get_children():
		child.queue_free()
	game.cell_buttons.clear()

	if game.board.empty():
		return

	var rows = game.board.size()
	var cols = game.board[0].size()
	game.board_grid.columns = cols

	for r in range(rows):
		var row_buttons = []
		for c in range(cols):
			var button = Button.new()
			button.text = ""
			button.rect_min_size = Vector2(52, 52)
			button.add_font_override("font", game.game_font)
			button.focus_mode = Control.FOCUS_NONE
			button.set_meta("row", r)
			button.set_meta("col", c)
			button.connect("pressed", game, "_on_tile_pressed", [button])
			game.board_grid.add_child(button)
			row_buttons.append(button)
		game.cell_buttons.append(row_buttons)

	game._update_tile_sizes()
	game._refresh_board_visuals()


# --- Tile animations (de-coroutined: single tweens, no yield) ---

static func _shake_tile(game, coord):
	var button = game._try_get_tile_button(coord)
	if button == null:
		return
	button.rect_pivot_offset = button.rect_size * 0.5
	button.rect_scale = Vector2(1.04, 1.04)
	var tween = game._make_fx_tween()
	tween.interpolate_property(button, "rect_rotation", 0.0, -6.0, 0.04, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.0)
	tween.interpolate_property(button, "rect_rotation", -6.0, 6.0, 0.06, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.04)
	tween.interpolate_property(button, "rect_rotation", 6.0, -4.0, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.10)
	tween.interpolate_property(button, "rect_rotation", -4.0, 0.0, 0.06, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.15)
	tween.interpolate_property(button, "rect_scale", Vector2(1.04, 1.04), Vector2.ONE, 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.15)
	tween.start()


static func _pulse_tile(game, coord, peak_scale, half_duration, loops = 1):
	var button = game._try_get_tile_button(coord)
	if button == null:
		return
	button.rect_pivot_offset = button.rect_size * 0.5
	# One tween chains every up/down pulse step, so no coroutine is needed.
	var tween = Tween.new()
	game.add_child(tween)
	var delay = 0.0
	for _i in range(max(1, loops)):
		tween.interpolate_property(button, "rect_scale", button.rect_scale, Vector2.ONE * peak_scale, half_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
		delay += half_duration
		tween.interpolate_property(button, "rect_scale", Vector2.ONE * peak_scale, Vector2.ONE, half_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
		delay += half_duration
	tween.start()


static func _animate_select(game, coord):
	var button = game._try_get_tile_button(coord)
	if button == null:
		return
	button.rect_pivot_offset = button.rect_size * 0.5
	var tween = Tween.new()
	game.add_child(tween)
	tween.interpolate_property(button, "rect_scale", button.rect_scale, Vector2(1.08, 1.08), 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property(button, "rect_scale", Vector2(1.08, 1.08), Vector2.ONE, 0.12, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.08)
	var center = game._tile_center_in_effect_layer(coord)
	tween.connect("tween_all_completed", game, "_spawn_ring_effect", [center, Color("ff6f9c"), 0.18, 12.0])
	tween.start()



static func color_for(game, value):
	if game.icon_sets.empty():
		return Color("ffffff")

	var icon_set: Dictionary = game.icon_sets[game.icon_set_index]
	var colors: Array = icon_set.get("colors", [])
	var index = value - 1
	if index >= 0 and index < colors.size():
		return Color(str(colors[index]))
	return Color("ffffff")


static func tile_button_at(game, coord):
	if coord.x < 0 or coord.x >= game.cell_buttons.size():
		return null
	var row_buttons: Array = game.cell_buttons[coord.x]
	if coord.y < 0 or coord.y >= row_buttons.size():
		return null
	return row_buttons[coord.y]
