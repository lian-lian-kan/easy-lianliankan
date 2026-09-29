extends SceneTree

# 绘制原语模块测试：程序纹理的像素级不变量（尺寸/圆角透明/中心实心/AA），
# Image 构建与 Texture 包装分离所以无头可测；装饰节点工厂的结构断言。

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

# Godot 3 要求 get_pixel 前 lock()，否则报错并返回未定义值。
func _pixel(img: Image, x: int, y: int) -> Color:
	img.lock()
	var c = img.get_pixel(x, y)
	img.unlock()
	return c

func _init() -> void:
	print("== ui_paint_test")
	var PAINT = load("res://scripts/ui/ui_paint.gd")

	# --- disc image: ring/face split, AA edge, transparent corners ---
	var disc: Image = PAINT.disc_image(20, Color("ff0000"), Color("0000ff"))
	check(disc.get_width() == 20 && disc.get_height() == 20, "disc image has the requested size")
	check(_pixel(disc, 10, 10).is_equal_approx(Color(1, 0, 0, 1)), "disc center is the face color")
	check(_pixel(disc, 0, 0).a == 0.0, "disc corner is fully transparent")
	var ring_pixel = _pixel(disc, 2, 10)
	check(abs(ring_pixel.b - 1.0) < 0.01 and ring_pixel.r < 0.01, "disc outer band is the ring color")
	check(_pixel(disc, 10, 2).a > 0.9, "disc edge stays opaque inside the radius")

	# --- check image: white mark on a rose disc ---
	var mark: Image = PAINT.check_image(22)
	check(mark.get_width() == 22, "check image has the requested size")
	check(_pixel(mark, 0, 0).a == 0.0, "check disc corner is transparent")
	var center = _pixel(mark, 11, 4)
	check(abs(center.r - 0.941) < 0.02 and abs(center.g - 0.4196) < 0.02, "check disc face is rose away from the mark (sampled clear of the AA)")
	check(_pixel(mark, 9, 15).r > 0.8 and _pixel(mark, 9, 15).g > 0.8, "check mark pixels are white")

	# --- pill image: rounded capsule corners ---
	var pill: Image = PAINT.pill_image(26, 10, Color(1, 0, 0, 0.6))
	check(pill.get_width() == 26 && pill.get_height() == 10, "pill image has the requested size")
	check(_pixel(pill, 0, 0).a == 0.0, "pill corner is transparent")
	check(abs(_pixel(pill, 13, 5).a - 0.6) < 0.01, "pill center keeps the requested alpha")

	# --- gradient image: endpoints and mid band ---
	var grad: Image = PAINT.gradient_image(Color("ff0000"), Color("00ff00"), Color("0000ff"))
	check(_pixel(grad, 0, 0).is_equal_approx(Color(1, 0, 0, 1)), "gradient top row is the top color")
	check(_pixel(grad, 0, 255).is_equal_approx(Color(0, 0, 1, 1)), "gradient bottom row is the bottom color")
	var mid = _pixel(grad, 0, 115)
	check(abs(mid.g - 1.0) < 0.02, "gradient mid band is the mid color")

	# --- theme installation: every engineered control gets brand icons ---
	var theme = Theme.new()
	PAINT.init_control_textures(theme)
	for spec in [["grabber", "HSlider"], ["grabber_highlight", "HSlider"], ["grabber_disabled", "HSlider"],
			["checked", "CheckBox"], ["unchecked", "CheckBox"], ["vgrabber", "VScrollBar"], ["hgrabber", "HScrollBar"]]:
		check(theme.get_icon(spec[0], spec[1]) != null, "%s icon installed for %s" % [spec[0], spec[1]])
	check(theme.get_stylebox("scroll", "VScrollBar") is StyleBoxFlat, "vscroll trough styled")
	check(theme.get_stylebox("scroll", "HScrollBar") is StyleBoxFlat, "hscroll trough styled")

	# --- decorative node factories ---
	var disc_node = PAINT.soft_disc(Vector2(4, 6), Vector2(80, 80), Color("ffffff"))
	check(disc_node is Panel && disc_node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "soft disc is an input-transparent panel")
	check(disc_node.get_stylebox("panel").corner_radius_top_left == 40, "soft disc is fully rounded")
	var dots = PAINT.dot_divider()
	check(dots.get_child_count() == 9, "dot divider builds its dots")
	var accent = PAINT.accent_bar()
	check(accent.rect_min_size == Vector2(4, 16), "accent bar has the section-header footprint")

	if failures == 0:
		print("ui_paint_test: ALL PASSED")
		quit(0)
	else:
		print("ui_paint_test: %d FAILURES" % failures)
		quit(1)
