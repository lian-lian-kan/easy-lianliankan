extends SceneTree

# Unit tests for scripts/session/powerup_loadout.gd — the level grant ladder,
# mode extras and special-session fixed loadouts (pure table resolution).

const LOADOUT = preload("res://scripts/session/powerup_loadout.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== powerup_loadout_test")

	# --- base grants for an early level
	var early = LOADOUT.resolve(1, "classic", false, "")
	check(int(early["time_freeze"]) == 1 and int(early["reshuffle"]) == 1, "every level grants one freeze and one reshuffle")
	check(int(early["bomb"]) == 0 and int(early["magnifier"]) == 0 and int(early["warm_patch"]) == 0, "late-game tools stay locked on level 1")

	# --- ladder thresholds set (never stack) at their boundary
	var mid = LOADOUT.resolve(5, "classic", false, "")
	check(int(mid["auto_match"]) == 1 and int(mid["time_freeze"]) == 2, "level 5 unlocks auto-match and the second freeze")
	check(int(mid["bomb"]) == 0, "bombs wait until level 10")
	var late = LOADOUT.resolve(12, "classic", false, "")
	check(int(late["bomb"]) == 1 and int(late["rainbow"]) == 1 and int(late["time_sand"]) == 1 and int(late["magnifier"]) == 1, "level 12 grants the full late-game toolbelt")

	# --- mode extras add on top of the ladder
	var rush = LOADOUT.resolve(1, "rush", false, "")
	check(int(rush["time_freeze"]) == 2, "rush adds a freeze on top of the base grant")
	var endurance = LOADOUT.resolve(1, "endurance", false, "")
	check(int(endurance["reshuffle"]) == 2, "endurance adds a reshuffle on top of the base grant")
	var rush_late = LOADOUT.resolve(6, "rush", false, "")
	check(int(rush_late["time_freeze"]) == 3, "rush extras stack on the unlocked ladder count")

	# --- special sessions replace the ladder with the fixed loadout
	var special = LOADOUT.resolve(12, "classic", true, "daily")
	check(int(special["time_freeze"]) == 2 and int(special["reshuffle"]) == 2 and int(special["auto_match"]) == 1, "special sessions grant the friendly base loadout")
	check(int(special["bomb"]) == 0 and int(special["rainbow"]) == 0, "the daily override strips click-targeted tools and ignores the ladder")
	check(int(special["magnifier"]) == 1, "tools outside the override tables keep their ladder grants")

	var frost = LOADOUT.resolve(1, "classic", true, "frost")
	check(int(frost["warm_patch"]) == 3, "frost sessions grant three warm patches")

	var hell = LOADOUT.resolve(12, "classic", true, "hell")
	check(int(hell["time_freeze"]) == 1 and int(hell["auto_match"]) == 0 and int(hell["magnifier"]) == 0, "the hell override strips back to freeze and reshuffle")
	check(int(hell["bomb"]) == 0 and int(hell["rainbow"]) == 0 and int(hell["time_sand"]) == 0 and int(hell["warm_patch"]) == 0, "hell zeroes every late-game tool")

	if failures == 0:
		print("powerup_loadout_test: ALL PASSED")
		quit(0)
	else:
		print("powerup_loadout_test: %d FAILURES" % failures)
		quit(1)
