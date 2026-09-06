extends Reference

# 樱花飘落与撒花特效的纯发射逻辑（从 game.gd 抽出）。
# game 提供 _petal_layer（特效层）、_font_at_size（字体）、_make_fx_tween（补间）
# 与 is_inside_tree；所有特效节点都挂在 game._petal_layer 下并自行清理。

const PETAL_ICONS = ["🌸", "🌸", "🌸", "🌺", "💗", "✨"]

static func build_petals(game):
	game._petal_timer = Timer.new()
	game._petal_timer.wait_time = 1.1
	game._petal_timer.one_shot = false
	game._petal_timer.connect("timeout", game, "_on_petal_tick")
	game.add_child(game._petal_timer)
	game._petal_timer.start()
	# A few petals already mid-fall so the scene never starts empty.
	for _i in range(4):
		spawn_petal(game, true)

static func petal_tick(game):
	if game._petal_layer == null or not game.is_inside_tree():
		return
	if game._petal_layer.get_child_count() < 12:
		spawn_petal(game, false)

static func spawn_petal(game, start_mid_fall):
	var petal = Label.new()
	petal.text = PETAL_ICONS[randi() % PETAL_ICONS.size()]
	petal.add_font_override("font", game._font_at_size(int(12 + randi() % 14)))
	petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	petal.modulate = Color(1, 1, 1, 0.0)
	game._petal_layer.add_child(petal)

	var view_size = game._petal_layer.rect_size
	if view_size.x <= 0.0:
		view_size = Vector2(360, 640)
	var x = randf() * max(1.0, view_size.x - 24.0)
	var start_y = rand_range(-140.0, -30.0)
	if start_mid_fall:
		start_y = rand_range(-140.0, view_size.y * 0.5)
	var duration = rand_range(7.0, 13.0)
	petal.rect_position = Vector2(x, start_y)

	var fall = game._make_fx_tween(petal)
	fall.interpolate_property(petal, "modulate:a", 0.0, rand_range(0.45, 0.8), 0.8, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	fall.interpolate_property(petal, "rect_position:y", start_y, view_size.y + 50.0, duration, Tween.TRANS_LINEAR, Tween.EASE_IN)
	fall.interpolate_property(petal, "rect_position:x", x, x + rand_range(-46.0, 46.0), duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	fall.interpolate_property(petal, "rect_rotation", 0.0, rand_range(-160.0, 160.0), duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	fall.start()

static func spawn_confetti(game, count):
	if game._petal_layer == null or not game.is_inside_tree():
		return
	var icons = ["🎉", "🎊", "🌸", "💖", "✨", "🌟"]
	var view_size = game._petal_layer.rect_size
	if view_size.x <= 0.0:
		view_size = Vector2(360, 640)
	for _i in range(count):
		var piece = Label.new()
		piece.text = icons[randi() % icons.size()]
		piece.add_font_override("font", game._font_at_size(int(14 + randi() % 16)))
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.rect_position = Vector2(randf() * max(1.0, view_size.x - 20.0), rand_range(-90.0, -20.0))
		game._petal_layer.add_child(piece)
		var duration = rand_range(1.6, 3.2)
		var tween = game._make_fx_tween(piece)
		var from_x = piece.rect_position.x
		tween.interpolate_property(piece, "rect_position:y", piece.rect_position.y, view_size.y + 40.0, duration, Tween.TRANS_QUAD, Tween.EASE_IN)
		tween.interpolate_property(piece, "rect_position:x", from_x, from_x + rand_range(-90.0, 90.0), duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		tween.interpolate_property(piece, "rect_rotation", 0.0, rand_range(-220.0, 220.0), duration, Tween.TRANS_LINEAR)
		tween.interpolate_property(piece, "modulate:a", 1.0, 0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, max(0.1, duration - 0.5))
		tween.start()
