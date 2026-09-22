extends SceneTree

# Unit tests for page_router.gd's pure navigation surface: the nav_items
# table (order, shape, label/icon presence) and the page-id constants it
# must stay in sync with.

const PAGE_ROUTER = preload("res://scripts/pages/page_router.gd")
const UI_FONTS = preload("res://scripts/ui/ui_fonts.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubTimer:
	var stopped := 0
	var started := 0
	func stop():
		stopped += 1
	func start():
		started += 1

class FakePageGame extends Node:
	const STATUS_PLAYING = "playing"
	const STATUS_PAUSED = "paused"
	const STATUS_CLEARED = "cleared"
	var pages_root = PanelContainer.new()
	var page_content = VBoxContainer.new()
	var second_timer = StubTimer.new()
	var level_advance_timer = StubTimer.new()
	var stage_panel_label = null
	var combo_burst_label = null
	var stage_status = STATUS_PLAYING
	var pending_level_index = -1
	var current_page = ""
	# Page-content build support: show_page("level_map") runs the real
	# journey-map builder against the fake, so it needs the same surface the
	# real game exposes (fonts, campaign table, unlock predicates).
	var _font_cache := {}
	var progression_state := {}
	var level_index := 0
	var campaign_levels := []
	func _init():
		pages_root.visible = false
		add_child(pages_root)
		pages_root.add_child(page_content)
		for i in range(15):
			campaign_levels.append({"id": i + 1, "name": "第%d关" % (i + 1)})
	func _font_at_size(px):
		return UI_FONTS.font_at_size(self, px)
	func _apply_button_style(_button, _base, _pressed):
		pass
	func _is_level_unlocked(_level_index):
		return true
	func _is_special_session():
		return false

func _count_buttons(node, acc):
	for child in node.get_children():
		if child is Button:
			acc.append(child)
		_count_buttons(child, acc)
	return acc

func _init() -> void:
	print("== page_router_test")

	var items = PAGE_ROUTER.nav_items()

	# --- shape: seven entries, each [id, icon, label]
	check(items.size() == 7, "the nav shows exactly seven entries")
	var well_formed := true
	for item in items:
		if item.size() != 3 or str(item[0]).empty() \
				or str(item[1]).empty() or str(item[2]).empty():
			well_formed = false
	check(well_formed, "every entry is a non-empty [id, icon, label] triple")

	# --- order and identity: home first, then the four meta pages
	var ids = []
	for item in items:
		ids.append(item[0])
	check(ids == ["home", PAGE_ROUTER.PAGE_MODES, PAGE_ROUTER.PAGE_LEVEL_MAP, PAGE_ROUTER.PAGE_COLLECTION,
		PAGE_ROUTER.PAGE_SIGNIN, PAGE_ROUTER.PAGE_EVENTS, PAGE_ROUTER.PAGE_SHOP],
		"nav order is home, modes, journey, collection, gift, events, shop")

	# --- home must be the first entry so the nav returns home by default
	check(ids[0] == "home", "home is the first nav entry")

	# --- the stats page stays off the nav (reached from settings)
	var stats_only = PAGE_ROUTER.PAGE_STATS
	check(not ids.has(stats_only),
		"the stats page stays off the nav (reached from settings)")

	# --- modal lifecycle: opening pauses the stage, closing resumes it
	var game = FakePageGame.new()

	# null guard: no page surface built yet -> the router does nothing
	var early = FakePageGame.new()
	early.pages_root = null
	PAGE_ROUTER.show_page(early, "level_map")
	check(early.current_page == "" and early.pages_root == null,
		"show_page without a page surface is a no-op")

	PAGE_ROUTER.show_page(game, "nonexistent")
	check(game.pages_root.visible == true, "an unknown id still opens the page surface")
	check(game.stage_status == FakePageGame.STATUS_PAUSED,
		"opening a page pauses a playing stage")
	check(game.second_timer.stopped == 1 and game.level_advance_timer.stopped == 1,
		"the heartbeat and the level-advance timers are frozen while browsing")
	check(game.current_page == "nonexistent", "the router records the current page")

	PAGE_ROUTER.close_page(game)
	check(game.pages_root.visible == false and game.current_page == "",
		"closing hides the surface and clears the page id")
	check(game.stage_status == FakePageGame.STATUS_PLAYING,
		"closing a paused stage resumes play")
	check(game.second_timer.started == 1, "the heartbeat restarts on close")

	# --- cleared-stage settle resumes through close, and only when pending
	game = FakePageGame.new()
	game.stage_status = FakePageGame.STATUS_CLEARED
	game.pending_level_index = 7
	PAGE_ROUTER.show_page(game, "level_map")
	# The journey map must actually build: one node per campaign level.
	var map_buttons = _count_buttons(game.page_content, [])
	check(map_buttons.size() >= 15,
		"level_map builds a journey node for every campaign level")
	game.level_advance_timer.started = 0
	PAGE_ROUTER.close_page(game)
	check(game.level_advance_timer.started == 1 and game.pending_level_index == 7,
		"an interrupted settle resumes the advance timer on close")

	game = FakePageGame.new()
	game.stage_status = FakePageGame.STATUS_PLAYING
	game.pending_level_index = -1
	PAGE_ROUTER.show_page(game, "level_map")
	game.level_advance_timer.started = 0
	PAGE_ROUTER.close_page(game)
	check(game.level_advance_timer.started == 0,
		"a playing stage with nothing pending does not restart the timer")

	if failures == 0:
		print("page_router_test: ALL PASSED")
		quit(0)
	else:
		print("page_router_test: %d FAILURES" % failures)
		quit(1)
