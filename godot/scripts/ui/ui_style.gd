extends Reference

# Shared control styling for panels, buttons and dialogs. Extracted from
# ui_panels.gd: these helpers are cross-cutting (used by the home screen,
# mode views, the HUD and the panels themselves) and know nothing about
# panels or the game node.

static func apply_glass_style(panel, bg_color, alpha):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, alpha)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color("ffd9e8")
	style.shadow_color = Color("00000020")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_stylebox_override("panel", style)

static func apply_button_style(button, bg_color, border_color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color("00000015")
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.08)
	hover.border_color = border_color.lightened(0.1)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(12)
	hover.shadow_color = Color("00000020")
	hover.shadow_size = 6
	hover.shadow_offset = Vector2(0, 3)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.05)
	pressed.border_color = border_color.darkened(0.05)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(16)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("disabled", normal)

static func style_dialog_buttons(node):
	# Dialog buttons join the rose palette instead of the default gray.
	if node is Button:
		apply_button_style(node, Color("f06ba8"), Color("d6336c"))
		node.add_color_override("font_color", Color("ffffff"))
		node.add_color_override("font_hover_color", Color("ffffff"))
		node.add_color_override("font_pressed_color", Color("ffffff"))
		node.add_color_override("font_focus_color", Color("ffffff"))
	for child in node.get_children():
		style_dialog_buttons(child)
