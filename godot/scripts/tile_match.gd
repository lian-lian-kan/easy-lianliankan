extends Reference

# Tray-match core ("叠叠消"): stacked tile piles, tap uncovered tiles into a
# 7-slot tray, three of a kind clear. Tray full = loss; pile empty = win.
# Pure state machine (generate / is_covered / pick / undo / shuffle) so the
# rules run headless in tests; view building takes the game node.

const TILE_SIZE = Vector2(56, 56)
const STEP = Vector2(34, 30)
const LAYER_OFFSET = Vector2(7, 7)
const CLEAR_SCORE = 30

# --- Pure state machine ---

static func generate(cfg) -> Dictionary:
	var layers = int(cfg.get("layers", 4))
	var rows = int(cfg.get("layer_rows", 5))
	var cols = int(cfg.get("layer_cols", 6))
	var kinds = int(cfg.get("kinds", 10))
	var total = layers * rows * cols
	# Every pattern appears a multiple of 3 times so the pile can fully clear.
	var patterns := []
	var p := 0
	while patterns.size() < total:
		patterns.append(p % kinds)
		if patterns.size() % 3 == 0:
			p += 1
	for i in range(patterns.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = patterns[i]
		patterns[i] = patterns[j]
		patterns[j] = tmp
	var tiles := []
	var idx := 0
	for layer in range(layers):
		for row in range(rows):
			for col in range(cols):
				tiles.append({"pattern": patterns[idx], "layer": layer, "row": row, "col": col, "removed": false})
				idx += 1
	return {
		"tiles": tiles,
		"tray": [],
		"undo_left": 1,
		"shuffle_left": 1,
		"layers": layers,
		"rows": rows,
		"cols": cols,
		"capacity": int(cfg.get("tray_capacity", 7))
	}

static func is_covered(state, tile) -> bool:
	for other in state["tiles"]:
		if other["removed"] or other["layer"] <= tile["layer"]:
			continue
		if abs(int(other["row"]) - int(tile["row"])) <= 1 and abs(int(other["col"]) - int(tile["col"])) <= 1:
			return true
	return false

# Returns "cleared" when the pile emptied, "lost" when the tray jammed full,
# "match" when a triple cleared, "" for a normal pickup.
static func pick(state, tile_index) -> String:
	var tiles: Array = state["tiles"]
	if tile_index < 0 or tile_index >= tiles.size():
		return ""
	var tile: Dictionary = tiles[tile_index]
	if tile["removed"] or is_covered(state, tile):
		return ""
	tile["removed"] = true
	var tray: Array = state["tray"]
	var insert_at = tray.size()
	var pattern = int(tile["pattern"])
	for i in range(tray.size()):
		if int(tray[i]) == pattern:
			insert_at = i + 1
	tray.insert(insert_at, pattern)

	# Clear any run of three equal patterns.
	var run_start = -1
	var run_len = 0
	for i in range(tray.size()):
		if i > 0 and int(tray[i]) == int(tray[i - 1]):
			run_len += 1
		else:
			run_start = i
			run_len = 1
		if run_len == 3:
			for k in range(3):
				tray.remove(run_start)
			return _after_change(state)
	return _after_change(state)

static func _after_change(state) -> String:
	var pile_left = 0
	for t in state["tiles"]:
		if not t["removed"]:
			pile_left += 1
	if pile_left == 0:
		return "cleared"
	if state["tray"].size() >= int(state["capacity"]):
		return "lost"
	return ""

static func undo(state) -> bool:
	if state["undo_left"] <= 0 or state["tray"].empty():
		return false
	var pattern = int(state["tray"].back())
	state["tray"].pop_back()
	# Restore the most recently removed tile of that pattern.
	var restore = -1
	for i in range(state["tiles"].size()):
		var t = state["tiles"][i]
		if t["removed"] and int(t["pattern"]) == pattern:
			restore = i
	if restore >= 0:
		state["tiles"][restore]["removed"] = false
	state["undo_left"] -= 1
	return true

static func shuffle(state) -> bool:
	if state["shuffle_left"] <= 0:
		return false
	# Collect the live pile's patterns and deal them back over the same slots.
	var live := []
	for t in state["tiles"]:
		if not t["removed"]:
			live.append(t)
	var patterns := []
	for t in live:
		patterns.append(int(t["pattern"]))
	for i in range(patterns.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = patterns[i]
		patterns[i] = patterns[j]
		patterns[j] = tmp
	for i in range(live.size()):
		live[i]["pattern"] = patterns[i]
	state["shuffle_left"] -= 1
	return true

static func score_for(state) -> int:
	# Score = 30 per cleared triple.
	var picks = 0
	for t in state["tiles"]:
		if t["removed"]:
			picks += 1
	return (picks / 3) * CLEAR_SCORE

# --- View (rebuilt wholesale on every state change) ---

static func build_view(game):
	if game.tray_layer == null:
		return
	for child in game.tray_layer.get_children():
		game.tray_layer.remove_child(child)
		child.queue_free()

	var state = game.tray_state
	if state.empty():
		return

	var pile = Control.new()
	pile.position = Vector2(20, 10)
	game.tray_layer.add_child(pile)
	for i in range(state["tiles"].size()):
		var tile: Dictionary = state["tiles"][i]
		if tile["removed"]:
			continue
		var tile_button = Button.new()
		tile_button.text = _pattern_glyph(game, int(tile["pattern"]))
		tile_button.position = Vector2(
			int(tile["col"]) * STEP.x + int(tile["layer"]) * LAYER_OFFSET.x,
			int(tile["row"]) * STEP.y + int(tile["layer"]) * LAYER_OFFSET.y)
		tile_button.rect_size = TILE_SIZE
		tile_button.add_font_override("font", game._font_at_size(24))
		var covered = is_covered(state, tile)
		tile_button.modulate = Color(1, 1, 1, 0.55) if covered else Color(1, 1, 1, 1)
		tile_button.connect("pressed", game, "_on_tray_tile_pressed", [i])
		pile.add_child(tile_button)

	var tray_row = HBoxContainer.new()
	tray_row.position = Vector2(20, 250)
	tray_row.add_constant_override("separation", 6)
	game.tray_layer.add_child(tray_row)
	for slot in range(int(state["capacity"])):
		var slot_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffffff")
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color("f09ebb")
		slot_panel.add_stylebox_override("panel", style)
		slot_panel.rect_min_size = Vector2(46, 46)
		var glyph = Label.new()
		if slot < state["tray"].size():
			glyph.text = _pattern_glyph(game, int(state["tray"][slot]))
		glyph.align = Label.ALIGN_CENTER
		glyph.valign = Label.VALIGN_CENTER
		glyph.add_font_override("font", game._font_at_size(22))
		slot_panel.add_child(glyph)
		tray_row.add_child(slot_panel)

	var tools = HBoxContainer.new()
	tools.position = Vector2(20, 306)
	tools.add_constant_override("separation", 10)
	game.tray_layer.add_child(tools)
	var undo_button = Button.new()
	undo_button.text = "撤销 (%d)" % int(state["undo_left"])
	undo_button.rect_min_size = Vector2(90, 34)
	undo_button.add_font_override("font", game._font_at_size(13))
	game._apply_button_style(undo_button, Color("f06ba8"), Color("d6336c"))
	undo_button.add_color_override("font_color", Color("ffffff"))
	undo_button.connect("pressed", game, "_on_tray_undo_pressed")
	tools.add_child(undo_button)
	var shuffle_button = Button.new()
	shuffle_button.text = "洗牌 (%d)" % int(state["shuffle_left"])
	shuffle_button.rect_min_size = Vector2(90, 34)
	shuffle_button.add_font_override("font", game._font_at_size(13))
	game._apply_button_style(shuffle_button, Color("f06ba8"), Color("d6336c"))
	shuffle_button.add_color_override("font_color", Color("ffffff"))
	shuffle_button.connect("pressed", game, "_on_tray_shuffle_pressed")
	tools.add_child(shuffle_button)

static func _pattern_glyph(game, pattern) -> String:
	var icons: Array = game.icon_sets[game.icon_set_index].get("icons", [])
	if pattern < icons.size():
		return str(icons[pattern])
	return "?"

static func clear_view(game):
	if game.tray_layer != null:
		for child in game.tray_layer.get_children():
			game.tray_layer.remove_child(child)
			child.queue_free()
