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

func _init() -> void:
	print("== page_router_test")

	var items = PAGE_ROUTER.nav_items()

	# --- shape: five entries, each [id, icon, label]
	check(items.size() == 5, "the nav shows exactly five entries")
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
		PAGE_ROUTER.PAGE_SIGNIN, PAGE_ROUTER.PAGE_SHOP],
		"nav order is home, journey, collection, gift, shop")

	# --- home must be the first entry so the nav returns home by default
	check(ids[0] == "home", "home is the first nav entry")

	# --- the stats page stays off the nav (reached from settings)
	var stats_only = PAGE_ROUTER.PAGE_STATS
	check(not ids.has(stats_only),
		"the stats page stays off the nav (reached from settings)")

	if failures == 0:
		print("page_router_test: ALL PASSED")
		quit(0)
	else:
		print("page_router_test: %d FAILURES" % failures)
		quit(1)
