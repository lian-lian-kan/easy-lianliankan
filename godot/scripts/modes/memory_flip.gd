extends Reference

# Memory flip core ("翻翻乐"): every card starts face down. Flip two per
# turn — matching patterns are removed, misses flip back after a short
# pause (the game drives flip_back_timer). All pairs cleared = win.

const FLIP_BACK_SECONDS = 0.7

static func new_round(game):
	var cfg = game.special_level
	var pairs = int(cfg.get("pairs", 12))
	var cards := []
	for pattern in range(pairs):
		for _copy in range(2):
			cards.append({"pattern": pattern, "flipped": false, "removed": false})
	for i in range(cards.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	game.flip_state = {"cards": cards, "open": [], "pairs_left": pairs}
	build_view(game)

# Returns "match" on a successful pair, "miss" when they differ (the caller
# must schedule unflip_misses), "cleared" on the final pair, "" otherwise.
static func flip(game, idx) -> String:
	var state = game.flip_state
	var cards: Array = state["cards"]
	if idx < 0 or idx >= cards.size():
		return ""
	var card: Dictionary = cards[idx]
	if card["removed"] or card["flipped"]:
		return ""
	card["flipped"] = true
	var open: Array = state["open"]
	open.append(idx)
	if open.size() < 2:
		build_view(game)
		return ""
	var first: Dictionary = cards[int(open[0])]
	var second: Dictionary = cards[int(open[1])]
	if int(first["pattern"]) == int(second["pattern"]):
		first["removed"] = true
		second["removed"] = true
		state["open"] = []
		state["pairs_left"] = int(state["pairs_left"]) - 1
		if int(state["pairs_left"]) <= 0:
			return "cleared"
		return "match"
	return "miss"

static func unflip_misses(game):
	var state = game.flip_state
	for idx in state["open"]:
		state["cards"][idx]["flipped"] = false
	state["open"] = []
	build_view(game)

static func build_view(game):
	if game.flip_layer == null:
		return
	for child in game.flip_layer.get_children():
		game.flip_layer.remove_child(child)
		child.queue_free()
	var state = game.flip_state
	if state.empty():
		return

	var grid = GridContainer.new()
	grid.columns = int(game._current_level().get("cols", 6))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_constant_override("h_separation", 8)
	grid.add_constant_override("v_separation", 8)
	game.flip_layer.add_child(grid)
	for i in range(state["cards"].size()):
		var card: Dictionary = state["cards"][i]
		var card_button = Button.new()
		card_button.rect_min_size = Vector2(48, 60)
		card_button.add_font_override("font", game._font_at_size(24))
		if card["removed"]:
			card_button.visible = false
		elif card["flipped"]:
			card_button.text = _pattern_glyph(game, int(card["pattern"]))
			game._apply_button_style(card_button, Color("ffffff"), Color("f09ebb"))
			card_button.add_color_override("font_color", Color("5c3a4d"))
		else:
			card_button.text = "❓"
			game._apply_button_style(card_button, Color("f06ba8"), Color("d6336c"))
			card_button.add_color_override("font_color", Color("ffffff"))
		card_button.connect("pressed", game, "_on_flip_card_pressed", [i])
		grid.add_child(card_button)

static func _pattern_glyph(game, pattern) -> String:
	var icons: Array = game.icon_sets[game.icon_set_index].get("icons", [])
	if pattern < icons.size():
		return str(icons[pattern])
	return "?"

static func clear_view(game):
	if game.flip_layer != null:
		for child in game.flip_layer.get_children():
			game.flip_layer.remove_child(child)
			child.queue_free()
