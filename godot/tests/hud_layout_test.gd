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
	const BOARD_RATIO_MIN = 0.92

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
	var desc_label = null
	var status_chip_label = null
	var mode_chip_label = null
	var kinds_chip_label = null
	var level_progress_bar = null
	var level_progress_caption_label = null
	var jump_level_button = null
	var clear_progress_button = null
	var icon_set_option = null
	var level_select_option = null
	var level_select_label = null
	var combo_progress_bar = null
	var power_ups_container = null
	var controls_flow_container = null
	var hint_button = null
	var auto_button = null
	var shuffle_button = null
	var reset_button = null
	var pause_button = null
	var modes_button = null
	var settings_button = null
	var jump_level_label = null
	var power_up_labels = {}
	var stat_values = {}
	var nav_bar = null
	var pages_root = null
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

	# --- update_layout on a portrait phone: board-first canvas + HUD line
	var phone = make_controls()
	phone.nav_bar = HBoxContainer.new()
	phone.nav_bar.visible = true
	HUD_LAYOUT.update_layout(phone)
	check(phone.title_row.visible == false, "portrait compacts the title strip away")
	check(phone.stat_values["level_score"]["card"].visible == false,
		"portrait hides the secondary stat card")
	check(phone.stat_values["total_score"]["card"].visible,
		"portrait keeps the essential card")
	check(abs(float(phone.board_wrapper.rect_min_size.y) - 844.0 * 0.92) < 0.01,
		"portrait board floor is 90% of the viewport height")
	check(phone.margin_container.get_constant("margin_left") == 0,
		"portrait margins collapse to zero")
	check(phone.margin_container.get_constant("margin_bottom") == 6,
		"portrait reserves only a thin board cushion at the bottom")
	check(phone.nav_bar.visible == false, "portrait parks the nav on the board view (page-only footer)")
	check(phone.deferred_calls == 1, "tile sizing is deferred once per pass")

	# --- update_layout on desktop: the SAME board-first contract
	var desktop_case = make_controls()
	desktop_case.viewport_size = Vector2(1920, 1080)
	desktop_case.title_row.visible = true  # simulate a prior pass
	desktop_case.nav_bar = HBoxContainer.new()
	desktop_case.nav_bar.visible = true
	desktop_case.pages_root = PanelContainer.new()
	desktop_case.pages_root.visible = false
	HUD_LAYOUT.update_layout(desktop_case)
	check(desktop_case.title_row.visible == false,
		"desktop compacts the title strip too (board-first everywhere)")
	check(desktop_case.stat_values["level_score"]["card"].visible == false,
		"desktop hides the secondary stat cards too")
	check(abs(float(desktop_case.board_wrapper.rect_min_size.y) - 1080.0 * 0.92) < 0.01,
		"desktop board floor is 90% of the viewport height")
	check(desktop_case.board_grid.get_constant("h_separation") == 6,
		"desktop separation is tight so tiles fill the canvas")
	check(desktop_case.margin_container.get_constant("margin_left") == 4,
		"desktop margins are a hairline")
	check(desktop_case.nav_bar.visible == false,
		"desktop parks the nav on the chrome-free home board")
	# the nav belongs to pages: it comes back the moment one opens
	desktop_case.pages_root.visible = true
	HUD_LAYOUT.update_layout(desktop_case)
	check(desktop_case.nav_bar.visible, "desktop shows the nav while a page is open")
	desktop_case.pages_root.visible = false
	HUD_LAYOUT.update_layout(desktop_case)
	check(desktop_case.nav_bar.visible == false, "closing the page parks the nav again")

	# --- landscape phone: same floor, compact single-line budget
	var landscape = make_controls()
	landscape.viewport_size = Vector2(844, 390)
	HUD_LAYOUT.update_layout(landscape)
	check(abs(float(landscape.board_wrapper.rect_min_size.y) - 390.0 * 0.92) < 0.01,
		"landscape board floor is 90% of the viewport height")
	check(landscape.title_row.visible == false,
		"landscape compacts the header to the HUD line")
	check(landscape.margin_container.get_constant("margin_left") == 4,
		"landscape margins are a hairline")

	# --- idempotent round-trip: portrait -> desktop -> portrait stays compact
	var roundtrip = make_controls()
	roundtrip.nav_bar = HBoxContainer.new()
	roundtrip.pages_root = PanelContainer.new()
	roundtrip.pages_root.visible = false
	HUD_LAYOUT.update_layout(roundtrip)
	check(roundtrip.title_row.visible == false, "the portrait pass compacts the header")
	roundtrip.viewport_size = Vector2(1920, 1080)
	HUD_LAYOUT.update_layout(roundtrip)
	check(roundtrip.title_row.visible == false
		and roundtrip.stat_values["level_score"]["card"].visible == false,
		"a desktop pass keeps the same board-first compaction")
	roundtrip.viewport_size = Vector2(390, 844)
	HUD_LAYOUT.update_layout(roundtrip)
	check(roundtrip.title_row.visible == false
		and roundtrip.stat_values["level_score"]["card"].visible == false,
		"a second portrait pass compacts again identically")

	# --- the compaction is unconditional: no class restores the full header
	var keys = ["level_score", "moves", "best_total_score", "best_combo"]
	check(keys.size() == 4, "four secondary cards yield on every class")

	if failures == 0:
		print("hud_layout_test: ALL PASSED")
		quit(0)
	else:
		print("hud_layout_test: %d FAILURES" % failures)
		quit(1)
