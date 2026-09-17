extends SceneTree

# Unit tests for page_router.gd's pure navigation surface: the nav_items
# table (order, shape, label/icon presence) and the page-id constants it
# must stay in sync with.

const PAGE_ROUTER = preload("res://scripts/pages/page_router.gd")

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
	func _init():
		pages_root.visible = false
		add_child(pages_root)
		pages_root.add_child(page_content)

func _init() -> void:
	print("== page_router_test")

	var items = PAGE_ROUTER.nav_items()

	# --- shape: six entries, each [id, icon, label]
	check(items.size() == 6, "the nav shows exactly six entries")
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
	check(ids == ["home", PAGE_ROUTER.PAGE_LEVEL_MAP, PAGE_ROUTER.PAGE_COLLECTION,
		PAGE_ROUTER.PAGE_SIGNIN, PAGE_ROUTER.PAGE_EVENTS, PAGE_ROUTER.PAGE_SHOP],
		"nav order is home, journey, collection, gift, events, shop")

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
