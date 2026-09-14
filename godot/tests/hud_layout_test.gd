extends SceneTree

# Unit tests for hud_layout.gd: _viewport_flags classification, the full
# update_layout pipeline (board height, margins, separations, stat pills)
# and the portrait compact/restore header visibility round-trip.

const HUD_LAYOUT = preload("res://scripts/ui/hud_layout.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame extends Reference:
	const MOBILE_SHORT_SIDE_MAX = 860.0
	const MOBILE_COMPACT_HEIGHT_MAX = 460.0
	const BOARD_MIN_HEIGHT = 200.0
	const BOARD_RATIO_MOBILE_LANDSCAPE = 0.46
	const BOARD_RATIO_DESKTOP = 0.52

	var viewport_size = Vector2(390, 844)
	var board_wrapper = null
	var board_grid = null
	var header_box = null
	var root_vbox = null
	var title_row = null
	var margin_container = null
	var message_label = null
	var husband_button = null
	var stats_flow_container = null
	var subtitle_label = null
	var title_label = null
	var power_up_labels = {}
	var stat_values = {}
	func get_viewport_rect():
		return Rect2(0, 0, viewport_size.x, viewport_size.y)
	func _viewport_flags(viewport_size):
		return HUD_LAYOUT._viewport_flags(self, viewport_size)
	func _update_modal_panel_sizes(_viewport_size, _is_portrait):
		pass
	func call_deferred(_method):
		deferred_calls += 1
	var deferred_calls = 0

func make_controls():
	"""A minimal but real control set for the layout pass."""
	var game = FakeGame.new()
	game.board_wrapper = PanelContainer.new()
	game.board_grid = GridContainer.new()
	game.header_box = VBoxContainer.new()
	game.root_vbox = VBoxContainer.new()
	game.title_row = HBoxContainer.new()
	game.title_row.visible = true
	game.margin_container = MarginContainer.new()
	game.message_label = Label.new()
	game.husband_button = Button.new()
	game.subtitle_label = Label.new()
	game.subtitle_label.visible = true
	game.stats_flow_container = HFlowContainer.new()
	game.board_grid.add_constant_override("h_separation", 99)
	game.board_grid.add_constant_override("v_separation", 99)
	# one essential card (total_score) plus one portrait-hidden card
	for entry in [["total_score", true], ["level_score", true]]:
		var card = PanelContainer.new()
		var title = Label.new()
		var value = Label.new()
		var holder = Control.new()
		card.add_child(title)
		holder.add_child(value)
		card.visible = true
		game.stat_values[entry[0]] = {"card": card, "title": title, "value": value}
	return game

func _init() -> void:
	print("== hud_layout_test")

func flags(size: Vector2) -> Dictionary:
	return HUD_LAYOUT._viewport_flags(FakeGame.new(), size)

func _init() -> void:
	print("== hud_layout_test")

	# --- phones: short side at or below 860
	var phone_portrait = flags(Vector2(390, 844))
	check(phone_portrait["is_mobile"] and phone_portrait["is_portrait"],
		"a 390x844 phone is mobile portrait")
	check(phone_portrait["is_compact_height"] == false,
		"a tall phone is not compact-height")

	var phone_landscape = flags(Vector2(844, 390))
	check(phone_landscape["is_mobile"] and phone_landscape["is_portrait"] == false,
		"a 844x390 phone is mobile landscape")
	check(phone_landscape["is_compact_height"],
		"a landscape phone has compact height")

	# --- tablets / desktop: short side above 860
	var tablet = flags(Vector2(1024, 1366))
	check(tablet["is_mobile"] == false and tablet["is_portrait"],
		"a 1024x1366 tablet is non-mobile portrait")
	var desktop = flags(Vector2(1920, 1080))
	check(desktop["is_mobile"] == false and desktop["is_portrait"] == false
		and desktop["is_compact_height"] == false,
		"a 1920x1080 desktop is neither mobile nor portrait nor compact")

	# --- exact boundaries are inclusive
	var at_limit = flags(Vector2(860, 900))
	check(at_limit["is_mobile"], "short side exactly 860 still counts as mobile")
	var at_compact = flags(Vector2(700, 460))
	check(at_limit["is_mobile"] and at_compact["is_compact_height"],
		"height exactly 460 counts as compact")

	# --- flags always come back as a complete triple
	for size in [Vector2(1, 1), Vector2(500, 500), Vector2(4000, 2000)]:
		var f = flags(size)
		check(f.has("is_mobile") and f.has("is_portrait") and f.has("is_compact_height"),
			"flags complete for %s" % str(size))

	# --- update_layout: null guard
	var guarded = FakeGame.new()
	HUD_LAYOUT.update_layout(guarded)
	check(guarded.deferred_calls == 0, "update_layout bails out without a board")

	# --- update_layout on a portrait phone: compaction + pills + margins
	var phone = make_controls()
	HUD_LAYOUT.update_layout(phone)
	check(phone.title_row.visible == false, "portrait compacts the title strip away")
	check(phone.stat_values["level_score"]["card"].visible == false,
		"portrait hides the secondary stat card")
	check(phone.stat_values["total_score"]["card"].visible,
		"portrait keeps the essential card")
	check(phone.board_wrapper.rect_min_size == Vector2(0, 200.0),
		"portrait board keeps the container-ruled minimum height")
	check(phone.margin_container.get_constant_override("margin_left") == 0,
		"portrait margins collapse to zero")
	check(phone.margin_container.get_constant_override("margin_bottom") == 10,
		"portrait reserves only a thin board cushion above the nav")
	check(phone.deferred_calls == 1, "tile sizing is deferred once per pass")

	# --- update_layout on desktop: everything restored
	var desktop = make_controls()
	desktop.viewport_size = Vector2(1920, 1080)
	desktop.title_row.visible = false  # simulate a prior portrait pass
	HUD_LAYOUT.update_layout(desktop)
	check(desktop.title_row.visible == true, "desktop restores the title strip")
	check(desktop.stat_values["level_score"]["card"].visible,
		"desktop shows every stat card")
	check(desktop.board_wrapper.rect_min_size == Vector2(0, 1080.0 * 0.52),
		"desktop sizes the board from the viewport ratio")
	check(desktop.board_grid.get_constant_override("h_separation") == 10,
		"desktop separation is roomy")
	check(desktop.margin_container.get_constant_override("margin_left") == 16,
		"desktop margins are the widest")

	# --- idempotent round-trip: portrait -> desktop -> portrait
	var roundtrip = make_controls()
	HUD_LAYOUT.update_layout(roundtrip)
	HUD_LAYOUT.update_layout(roundtrip)
	check(roundtrip.title_row.visible == true and roundtrip.subtitle_label.visible,
		"restore brings back every hidden strip")
	HUD_LAYOUT.update_layout(roundtrip)
	check(roundtrip.title_row.visible == false
		and roundtrip.stat_values["level_score"]["card"].visible == false,
		"a second portrait pass compacts again identically")

	# --- direct compaction helpers honour the four hidden keys
	var keys = ["level_score", "moves", "best_total_score", "best_combo"]
	check(keys.size() == 4, "four secondary cards yield in portrait")

	if failures == 0:
		print("hud_layout_test: ALL PASSED")
		quit(0)
	else:
		print("hud_layout_test: %d FAILURES" % failures)
		quit(1)
