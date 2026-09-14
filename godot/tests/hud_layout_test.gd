extends SceneTree

# Unit tests for hud_layout.gd's _viewport_flags: the phone/tablet/desktop,
# portrait and compact-height classification that drives every layout branch.

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

	if failures == 0:
		print("hud_layout_test: ALL PASSED")
		quit(0)
	else:
		print("hud_layout_test: %d FAILURES" % failures)
		quit(1)
