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
				game._apply_tile_style(button, Color("fff5f8"), Color("ffc2d4"), false)
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
	var padding = 4 if is_mobile and is_compact_height else (6 if is_mobile and is_portrait else (10 if is_mobile else 24))
	var board_area = game.board_wrapper.rect_size
	if board_area.x <= 1 or board_area.y <= 1:
		board_area = game.board_wrapper.rect_min_size
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

