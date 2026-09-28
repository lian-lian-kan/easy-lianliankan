extends Reference

# Shared control styling for panels, buttons and dialogs. Extracted from
# ui_panels.gd: these helpers are cross-cutting (used by the home screen,
# mode views, the HUD and the panels themselves) and know nothing about
# panels or the game node.
#
# ── 设计令牌（Round 31「蜜糖瓷片」界面重设计）────────────────────────
# 界面用色从这里取：调主题只动这一层。既有 helper 的行为契约被探针钉死
# （ui_style_test / stat_probe / panels_probe 的色彩回归锁），令牌仅供新
# 样式与后续逐步迁移，不改变 helper 签名。

# 品牌玫瑰系
const ROSE = Color("f06ba8")        # 实心主按钮
const ROSE_BRIGHT = Color("ff9ec4") # 主按钮悬停
const ROSE_DEEP = Color("d6336c")   # 描边 / 强调文字
const ROSE_LINE = Color("ffd9e8")   # 卡片细描边
const CREAM = Color("fff0f6")       # 品牌粉白底

# 墨色文字系（梅紫灰，正文可读性比纯灰高）
const INK = Color("5c3a4d")         # 正文
const INK_SOFT = Color("8f6b80")    # 次级文字
const INK_FADE = Color("c2a3b2")    # 弱化文字（页脚/快捷键角标）
const INK_SHADOW = Color(0.361, 0.227, 0.302, 0.141)  # 通用软投影（梅调 instead of 纯黑）

# 糖果边轮换：瓷片底色过浅（近白）时描边从这里按图案序号取，
# 保证任何图集下每张牌都有一条可读的糖边。
const CANDY_RIMS = [
	Color("f7a8c6"), Color("7fd0c0"), Color("92b8f5"), Color("f5c07a"),
	Color("c3a6f2"), Color("f5a0a0"), Color("8fcdea"), Color("a8d894"),
]

# 糖果瓷片配方：近白牌面 + 加深糖边。牌面保留 25% 图标色 so 同类图案
# 一眼成组，emoji 全彩直接贴浅面不再被粉底吃掉。
static func tile_face(base_color):
	return Color(1, 1, 1).linear_interpolate(base_color, 0.25)

static func tile_rim(base_color, value):
	var rim = base_color.darkened(0.24)
	if rim.get_luminance() > 0.82:
		# GDScript 3 的 abs()/max() 返回 float，float % int 是 parse error——先收 int。
		rim = CANDY_RIMS[int(abs(float(value))) % CANDY_RIMS.size()]
	return rim

static func apply_glass_style(panel, bg_color, alpha):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, alpha)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color("ffd9e8")
	style.shadow_color = Color8(0, 0, 0, 32)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_stylebox_override("panel", style)

static func apply_button_style(button, bg_color, border_color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color8(0, 0, 0, 21)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.08)
	hover.border_color = border_color.lightened(0.1)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(12)
	hover.shadow_color = Color8(0, 0, 0, 32)
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
	_apply_button_font_colors(button, bg_color)

# 文字色四态统一：只覆盖 font_color 会让悬停回落到主题默认灰——首页
# 「玩法大厅」悬停发灰就是这么来的。按背景亮度推导：深底白字、浅底粉字。
# 调用方仍可在其后自行覆盖 font_color 系列以指定特殊用色。
static func _apply_button_font_colors(button, bg_color):
	var luminance = 0.299 * bg_color.r + 0.587 * bg_color.g + 0.114 * bg_color.b
	var fg = Color("d6336c") if luminance > 0.7 else Color("ffffff")
	button.add_color_override("font_color", fg)
	button.add_color_override("font_hover_color", fg)
	button.add_color_override("font_pressed_color", fg)
	button.add_color_override("font_focus_color", fg)

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

static func style_secondary_button(button):
	# Quiet companion to style_dialog_buttons: the white-card look for the
	# non-primary actions, so a panel reads as hierarchy instead of a wall
	# of solid pink (same recipe as the start screen's quick entries).
	apply_button_style(button, Color("ffffff"), Color("f09ebb"))
	button.add_color_override("font_color", Color("d6336c"))
	button.add_color_override("font_hover_color", Color("d6336c"))
	button.add_color_override("font_pressed_color", Color("d6336c"))
	button.add_color_override("font_focus_color", Color("d6336c"))
	button.add_color_override("font_disabled_color", Color("c9a5b6"))

static func style_all_secondary_buttons(node):
	# Recursive sweep: every Button under the panel takes the white-card
	# look — for panels whose every action is a companion (settings,
	# achievements). Primaries, where they exist, re-assert style_dialog_buttons.
	if node is Button:
		style_secondary_button(node)
	for child in node.get_children():
		style_all_secondary_buttons(child)
