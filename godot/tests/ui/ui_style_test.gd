extends SceneTree

# Unit tests for scripts/ui/ui_style.gd — the shared glass/button/dialog
# styling helpers (pure Control styling, verified by override inspection).

const STYLE = preload("res://scripts/ui/ui_style.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== ui_style_test")

	# --- apply_glass_style: one panel stylebox with the asked tint
	var panel = PanelContainer.new()
	var bg = Color("ffffff")
	STYLE.apply_glass_style(panel, bg, 0.9)
	var sb = panel.get_stylebox("panel")
	check(sb is StyleBoxFlat, "glass style overrides the panel stylebox")
	check(abs(sb.bg_color.a - 0.9) < 0.001 and sb.bg_color.r == bg.r, "glass keeps the tint and alpha")
	check(sb.corner_radius_top_left == 16, "glass rounds the corners")

	# --- apply_button_style: five states, hover lighter, pressed darker
	var button = Button.new()
	var fill = Color("f06ba8")
	STYLE.apply_button_style(button, fill, Color("d6336c"))
	var normal = button.get_stylebox("normal")
	var hover = button.get_stylebox("hover")
	var pressed = button.get_stylebox("pressed")
	check(button.get_stylebox("disabled") == normal, "disabled falls back to the normal style")
	check(normal.bg_color == fill, "normal state keeps the fill")
	check(hover.bg_color == fill.lightened(0.08), "hover lightens the fill")
	check(pressed.bg_color == fill.darkened(0.05), "pressed darkens the fill")
	check(normal.border_color == Color("d6336c"), "normal keeps the border color")
	# 四态文字色：只覆盖 font_color 会让悬停回落主题默认灰。
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		check(button.get_color(state) == Color("ffffff"), "%s is white on a rose fill" % state)
	var white_card = Button.new()
	STYLE.apply_button_style(white_card, Color("ffffff"), Color("f09ebb"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		check(white_card.get_color(state) == Color("d6336c"), "%s is rose on a white fill" % state)
	# 8 位 hex 颜色曾被 Godot 3 错误解析（玫瑰变蓝、阴影变透明）：锁住阴影可见。
	check(normal.shadow_color.a > 0.0, "button shadow keeps its alpha")

	# --- style_dialog_buttons: rose palette, recursive through children
	var dialog = PanelContainer.new()
	var panel_before = dialog.get_stylebox("panel")
	var inner = Button.new()
	var nested = PanelContainer.new()
	var deep_button = Button.new()
	nested.add_child(deep_button)
	dialog.add_child(inner)
	dialog.add_child(nested)
	STYLE.style_dialog_buttons(dialog)
	check(inner.get_color("font_color") == Color("ffffff"), "dialog buttons turn white")
	check(inner.get_stylebox("normal").bg_color == Color("f06ba8"), "dialog buttons take the rose palette")
	check(deep_button.get_color("font_color") == Color("ffffff"), "nested buttons are styled recursively")

	# --- non-button containers are traversed without being repainted
	check(dialog.get_stylebox("panel") == panel_before, "containers keep their own styleboxes")

	for node in [panel, button, dialog]:
		node.free()

	# --- style_secondary_button / style_all_secondary_buttons: the white-card
	# companion look, applied recursively
	var secondary = Button.new()
	STYLE.style_secondary_button(secondary)
	check(secondary.get_stylebox("normal").bg_color == Color("ffffff"), "secondary buttons keep the white card")
	check(secondary.get_color("font_color") == Color("d6336c"), "secondary text is pink on white")
	check(secondary.get_color("font_disabled_color") == Color("c9a5b6"), "disabled secondary text softens")
	var sweep_panel = PanelContainer.new()
	var sweep_box = VBoxContainer.new()
	var deep = Button.new()
	sweep_box.add_child(deep)
	sweep_panel.add_child(sweep_box)
	STYLE.style_all_secondary_buttons(sweep_panel)
	check(deep.get_color("font_color") == Color("d6336c"), "the sweep reaches nested buttons")
	sweep_panel.free()

	if failures == 0:
		print("ui_style_test: ALL PASSED")
		quit(0)
	else:
		print("ui_style_test: %d FAILURES" % failures)
		quit(1)
