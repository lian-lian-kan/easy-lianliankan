extends Reference

# 装饰绘制原语（Round 35 从 ui_style.gd / start_screen.gd 收拢）：
# 逐像素程序纹理（滑杆把手/勾选框/滚动条 grabber——引擎内置图标够不着的
# 主题件）、背景渐变、光晕圆盘、圆点分隔线、区块短棒。全部纯 Image 代码，
# 零美术资源依赖；Image 构建与 Texture 包装分离，无头测试可直接断言像素。

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

# ── 主题控件纹理 ──────────────────────────────────────────────
# 由 ui_fonts.init_theme 装进全局主题一次管全场。

static func init_control_textures(theme):
	# 滑杆把手：玫瑰圆钮+浅玫瑰外环。
	theme.set_icon("grabber", "HSlider", _disc_texture(20, UI_STYLE.ROSE, Color("ffd9e8")))
	theme.set_icon("grabber_highlight", "HSlider", _disc_texture(20, UI_STYLE.ROSE_BRIGHT, Color("ffd9e8")))
	theme.set_icon("grabber_disabled", "HSlider", _disc_texture(20, Color("e8b8cc"), Color("ffd9e8")))
	# 勾选框：勾选=实心玫瑰圆+白对勾，未勾=白圆细玫瑰环。
	var checked = _check_texture(22)
	theme.set_icon("checked", "CheckBox", checked)
	theme.set_icon("radio_checked", "CheckBox", checked)
	var unchecked = _disc_texture(22, Color("ffffff"), Color("e8b8cc"))
	theme.set_icon("unchecked", "CheckBox", unchecked)
	theme.set_icon("radio_unchecked", "CheckBox", unchecked)
	_init_scroll_textures(theme)

# 滚动条：淡玫瑰圆角胶囊把手 + 玫瑰浅槽，替掉默认深灰件。
static func _init_scroll_textures(theme):
	var trough = StyleBoxFlat.new()
	trough.bg_color = Color("ffe9f1")
	trough.set_corner_radius_all(4)
	trough.content_margin_top = 3
	trough.content_margin_bottom = 3
	trough.content_margin_left = 3
	trough.content_margin_right = 3
	var grab = Color(0.941, 0.478, 0.702, 0.6)
	var grab_hot = Color(0.941, 0.478, 0.702, 0.85)
	theme.set_stylebox("scroll", "VScrollBar", trough)
	theme.set_stylebox("scroll_focus", "VScrollBar", trough)
	theme.set_stylebox("scroll", "HScrollBar", trough)
	theme.set_stylebox("scroll_focus", "HScrollBar", trough)
	theme.set_icon("vgrabber", "VScrollBar", _pill_texture(10, 26, grab))
	theme.set_icon("vgrabber_highlight", "VScrollBar", _pill_texture(10, 26, grab_hot))
	theme.set_icon("vgrabber_pressed", "VScrollBar", _pill_texture(10, 26, UI_STYLE.ROSE_DEEP))
	theme.set_icon("hgrabber", "HScrollBar", _pill_texture(26, 10, grab))
	theme.set_icon("hgrabber_highlight", "HScrollBar", _pill_texture(26, 10, grab_hot))
	theme.set_icon("hgrabber_pressed", "HScrollBar", _pill_texture(26, 10, UI_STYLE.ROSE_DEEP))

# ── Image 构建层（无头可测）────────────────────────────────────

# 圆盘：face 圆面 + ring 外环，AA 边缘。
static func disc_image(size, face, ring):
	var img = Image.new()
	img.create(size, size, false, Image.FORMAT_RGBA8)
	# Godot 3 的 create() 不清零内存——跳过的像素必须先铺透明底。
	img.fill(Color(0, 0, 0, 0))
	img.lock()
	var c = (size - 1) / 2.0
	for y in range(size):
		for x in range(size):
			var d = Vector2(x - c, y - c).length()
			if d > c + 0.5:
				continue
			var color = ring if d > c * 0.55 else face
			var aa = clamp(c + 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * aa))
	img.unlock()
	return img

static func _disc_texture(size, face, ring):
	var tex = ImageTexture.new()
	tex.create_from_image(disc_image(size, face, ring))
	return tex

# 实心玫瑰圆 + 白对勾（两段线段的距离场）。
static func check_image(size):
	var img = Image.new()
	img.create(size, size, false, Image.FORMAT_RGBA8)
	# Godot 3 的 create() 不清零内存——跳过的像素必须先铺透明底。
	img.fill(Color(0, 0, 0, 0))
	img.lock()
	var c = (size - 1) / 2.0
	var p0 = Vector2(size * 0.26, size * 0.53)
	var p1 = Vector2(size * 0.44, size * 0.70)
	var p2 = Vector2(size * 0.76, size * 0.33)
	var mark_width = size * 0.10
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var d = pos.distance_to(Vector2(c, c))
			if d > c + 0.5:
				continue
			var aa = clamp(c + 0.5 - d, 0.0, 1.0)
			var mark = clamp(mark_width - min(_seg_distance(pos, p0, p1), _seg_distance(pos, p1, p2)), 0.0, 1.0)
			var color = Color("ffffff").linear_interpolate(UI_STYLE.ROSE, 1.0 - mark)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, aa))
	img.unlock()
	return img

static func _check_texture(size):
	var tex = ImageTexture.new()
	tex.create_from_image(check_image(size))
	return tex

static func _seg_distance(p, a, b):
	var ab = b - a
	var t = clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# 圆角胶囊（滚动条把手）：圆角矩形 SDF。
static func pill_image(width, height, color):
	var img = Image.new()
	img.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.lock()
	var radius = min(width, height) / 2.0
	var half = Vector2(width, height) / 2.0 - Vector2(radius, radius)
	for y in range(height):
		for x in range(width):
			var q = (Vector2(x, y) - Vector2(width, height) / 2.0).abs() - half
			var d = Vector2(max(q.x, 0.0), max(q.y, 0.0)).length() + min(max(q.x, q.y), 0.0) - radius
			var aa = clamp(-d, 0.0, 1.0)
			if aa <= 0.0:
				continue
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * aa))
	img.unlock()
	return img

static func _pill_texture(width, height, color):
	var tex = ImageTexture.new()
	tex.create_from_image(pill_image(width, height, color))
	return tex

# 竖向渐变贴图：Godot 3 的 GradientTexture 只会横向铺，这里直接逐行
# 生成 4x256 像素（顶色→中色→底色两段线性插值）。
static func gradient_image(top, mid, bottom):
	var img = Image.new()
	img.create(4, 256, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in range(256):
		var t = float(y) / 255.0
		var c = top.linear_interpolate(mid, clamp(t / 0.45, 0.0, 1.0)) if t < 0.45 \
				else mid.linear_interpolate(bottom, clamp((t - 0.45) / 0.55, 0.0, 1.0))
		for x in range(4):
			img.set_pixel(x, y, c)
	img.unlock()
	return img

static func gradient_texture(top, mid, bottom):
	var tex = ImageTexture.new()
	tex.create_from_image(gradient_image(top, mid, bottom))
	return tex

# ── 装饰节点工厂 ──────────────────────────────────────────────

# 背景光晕圆盘（首页山丘/背光板）：无输入的纯装饰 Panel。
static func soft_disc(pos, size, fill_or_alpha, tint_alpha = -1):
	var disc = Panel.new()
	disc.rect_position = pos
	disc.rect_size = size
	var style = StyleBoxFlat.new()
	if tint_alpha >= 0:
		style.bg_color = Color(fill_or_alpha.r, fill_or_alpha.g, fill_or_alpha.b, tint_alpha / 255.0)
	else:
		style.bg_color = fill_or_alpha
	style.set_corner_radius_all(int(size.x / 2.0))
	disc.add_stylebox_override("panel", style)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc

# 花边圆点分隔线：粉点排，卡内的「蕾丝边」。
static func dot_divider(dot_count = 9):
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_CENTER
	row.add_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in range(dot_count):
		var dot = Panel.new()
		dot.rect_min_size = Vector2(6, 6)
		var style = StyleBoxFlat.new()
		style.bg_color = Color8(255, 184, 210, 220)
		style.set_corner_radius_all(3)
		dot.add_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	return row

# 区块标题玫瑰短棒（page_ui.section_header 的装饰件）。
static func accent_bar(width = 4, height = 16):
	var accent = Panel.new()
	accent.rect_min_size = Vector2(width, height)
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = UI_STYLE.ROSE
	style.set_corner_radius_all(2)
	accent.add_stylebox_override("panel", style)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return accent
