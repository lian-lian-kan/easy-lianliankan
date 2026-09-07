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

# --- Eliminate/combo effects (migrated from game.gd) ---

static func _play_eliminate_effects(game, coords):
	var effect_intensity = float(game._current_level().get("effect_intensity", 1.0))

	# Determine particle color and amount based on combo
	var color = Color("ff7a00")  # Default orange
	var particle_count = int(6 + effect_intensity * 2.0)
	var particle_color = Color("ffffff")  # Default white

	if game.combo >= 10:
		color = Color("ffd700")  # Gold
		particle_color = Color("ffd700")
		particle_count = int(30 * effect_intensity)
	elif game.combo >= 7:
		color = Color("e64980")  # Purple
		particle_color = Color("e64980")
		particle_count = int(24 * effect_intensity)
	elif game.combo >= 5:
		color = Color("e64980")  # Blue
		particle_color = Color("60a5fa")
		particle_count = int(18 * effect_intensity)
	elif game.combo >= 3:
		color = Color("0ca678")  # Green
		particle_color = Color("34d399")
		particle_count = int(12 * effect_intensity)

	for coord in coords:
		var button = game._try_get_tile_button(coord)
		if button == null:
			continue

		game._pulse_tile(coord, 1.14, 0.08, 1)

		var center = game._tile_center_in_effect_layer(coord)
		game._spawn_ring_effect(center, color, 0.24, 14.0 * effect_intensity)
		game._spawn_combo_particle_burst(center, particle_color, particle_count, game.combo)

		var star = Label.new()
		star.text = "✦"
		star.add_font_override("font", game.game_font)
		star.rect_position = center
		star.rect_pivot_offset = Vector2(8, 8)
		star.rect_scale = Vector2.ONE
		star.modulate = color
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.effect_layer.add_child(star)

		# Tween animation for star effect
		var tween = Tween.new()
		game.add_child(tween)
		tween.interpolate_property(star, "rect_position", star.rect_position, star.rect_position + Vector2(0, -18 * effect_intensity), 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.interpolate_property(star, "modulate:a", 1.0, 0.0, 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.interpolate_property(star, "rect_scale", Vector2.ONE, Vector2.ONE * (1.35 * effect_intensity), 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.start()
		tween.connect("tween_all_completed", star, "queue_free")
		tween.connect("tween_all_completed", tween, "queue_free")

static func _tile_center_in_effect_layer(game, coord):
	var button = game._try_get_tile_button(coord)
	if button == null:
		return Vector2.ZERO
	return game.effect_layer.get_global_transform().affine_inverse() * (button.rect_global_position + button.rect_size * 0.5)

static func _spawn_ring_effect(game, center, color, duration, base_size):
	if center == Vector2.ZERO:
		return

	var ring = Panel.new()
	ring.rect_size = Vector2.ONE * base_size
	ring.rect_position = center - ring.rect_size * 0.5
	ring.rect_pivot_offset = ring.rect_size * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(base_size * 0.5))
	ring.add_stylebox_override("panel", style)
	game.effect_layer.add_child(ring)

	var tween = game._make_fx_tween(ring)
	tween.interpolate_property(ring, "rect_scale", Vector2.ONE, Vector2(1.9, 1.9), duration, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(ring, "modulate:a", 1.0, 0.0, duration, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()

static func _spawn_particle_burst(game, center, color, particle_count, intensity):
	var count = int(max(4, particle_count))
	for _i in range(count):
		var particle = Label.new()
		particle.text = "•"
		particle.add_font_override("font", game.game_font)
		particle.rect_position = center
		particle.modulate = color
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.effect_layer.add_child(particle)

		var angle = rand_range(0.0, TAU)
		var distance = rand_range(16.0, 44.0) * intensity
		var target = center + Vector2(cos(angle), sin(angle)) * distance

		var tween = game._make_fx_tween(particle)
		tween.interpolate_property(particle, "rect_position", center, target, 0.3, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(particle, "modulate:a", 1.0, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN)
		tween.start()

static func _spawn_combo_particle_burst(game, center, color, particle_count, combo_level):
	var count = int(max(8, particle_count))
	var shapes = ["•", "✦", "★", "◆"]
	var shape_index = int(min(combo_level / 3, shapes.size() - 1))

	for _i in range(count):
		var particle = Label.new()
		particle.text = shapes[shape_index]
		particle.add_font_override("font", game.game_font)
		particle.rect_position = center
		particle.modulate = color
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.effect_layer.add_child(particle)

		var angle = rand_range(0.0, TAU)
		var distance = rand_range(20.0, 60.0 + combo_level * 3.0)
		var target = center + Vector2(cos(angle), sin(angle)) * distance

		var tween = game._make_fx_tween(particle)
		tween.interpolate_property(particle, "rect_position", center, target, 0.4, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(particle, "modulate:a", 1.0, 0.0, 0.4, Tween.TRANS_LINEAR, Tween.EASE_IN)
		if combo_level >= 7:
			tween.interpolate_property(particle, "rect_rotation", 0.0, rand_range(-180.0, 180.0), 0.4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.start()

static func _spawn_board_particles(game, count, color, intensity):
	var area = game.effect_layer.rect_size
	if area.x <= 0 or area.y <= 0:
		return

	for _i in range(count):
		var sparkle = Label.new()
		sparkle.text = "✦"
		sparkle.add_font_override("font", game.game_font)
		sparkle.rect_position = Vector2(
			rand_range(16.0, max(16.0, area.x - 16.0)),
			rand_range(24.0, max(24.0, area.y - 16.0))
		)
		sparkle.modulate = color
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.effect_layer.add_child(sparkle)

		var drift = Vector2(rand_range(-32.0, 32.0), rand_range(-84.0, -28.0)) * intensity
		var tween = game._make_fx_tween(sparkle)
		tween.interpolate_property(sparkle, "rect_position", sparkle.rect_position, sparkle.rect_position + drift, 0.52, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(sparkle, "modulate:a", 1.0, 0.0, 0.52, Tween.TRANS_LINEAR, Tween.EASE_IN)
		tween.start()

static func _show_combo_burst(game, text):
	# Enhanced combo burst with dynamic styling based on combo level
	var combo_num = game.combo
	var color = Color("e67700")  # Default amber
	var font_size = 18

	if combo_num >= 10:
		color = Color("f06565")
		font_size = 28
	elif combo_num >= 7:
		color = Color("e64980")
		font_size = 24
	elif combo_num >= 5:
		color = Color("e64980")
		font_size = 22
	elif combo_num >= 3:
		color = Color("0ca678")
		font_size = 20

	game.combo_burst_label.add_font_override("font", game._font_at_size(font_size))
	game.combo_burst_label.text = text
	game.combo_burst_label.visible = true
	game.combo_burst_label.modulate = Color(1, 1, 1, 1)
	game.combo_burst_label.margin_top = 88
	game.combo_burst_label.add_color_override("font_color", color)

	var tween = game._make_fx_tween()
	tween.interpolate_property(game.combo_burst_label, "margin_top", 88.0, 68.0, 0.22, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(game.combo_burst_label, "modulate:a", 1.0, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.6)
	tween.start()

