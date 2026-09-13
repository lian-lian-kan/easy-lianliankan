extends SceneTree

# Unit tests for scripts/session/achievements.gd (catalog + state accessors).

const ACHIEVEMENTS = preload("res://scripts/session/achievements.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== achievements_test")

	# --- catalog integrity
	var defs = ACHIEVEMENTS.get_achievement_definitions()
	check(defs.size() == 34, "catalog exposes 34 achievements")
	var ids = {}
	for definition in defs:
		ids[definition["id"]] = true
		check(definition.has("name") and definition.has("desc"), "achievement %s has name and desc" % definition["id"])
	check(ids.size() == 34, "achievement ids are unique")
	check(ids.has("first_clear") and ids.has("sum10_first"), "catalog spans first_clear..sum10_first")
	defs.append({"id": "mutated", "name": "x", "desc": "x"})
	check(ACHIEVEMENTS.get_achievement_definitions().size() == 34, "get_all returns a duplicate safe to mutate")

	# --- state accessors
	var state = {"achievements": ["first_clear"]}
	check(ACHIEVEMENTS.has_achievement(state, "first_clear"), "has_achievement finds an unlocked id")
	check(not ACHIEVEMENTS.has_achievement(state, "zen_first"), "has_achievement misses locked ids")
	check(ACHIEVEMENTS.get_unlocked_achievements(state) == ["first_clear"], "unlocked list returns a copy")

	check(ACHIEVEMENTS.unlock_achievement(state, "zen_first") == state, "unlock returns the same state")
	check(ACHIEVEMENTS.has_achievement(state, "zen_first"), "unlock appends the id")
	check(ACHIEVEMENTS.unlock_achievement(state, "zen_first") == state, "unlock is idempotent")
	check(ACHIEVEMENTS.get_unlocked_achievements(state) == ["first_clear", "zen_first"], "no duplicate entries after idempotent unlock")

	# --- malformed state is tolerated (older saves may lack the key)
	var empty_state = {}
	check(not ACHIEVEMENTS.has_achievement(empty_state, "first_clear"), "missing key reads as locked")
	ACHIEVEMENTS.unlock_achievement(empty_state, "first_clear")
	check(ACHIEVEMENTS.has_achievement(empty_state, "first_clear"), "unlock creates the key on demand")
	var broken_state = {"achievements": "corrupted"}
	check(not ACHIEVEMENTS.has_achievement(broken_state, "first_clear"), "corrupted type reads as locked")
	check(ACHIEVEMENTS.unlock_achievement(broken_state, "first_clear") == broken_state, "unlock repairs a corrupted list")
	check(ACHIEVEMENTS.get_unlocked_achievements(broken_state) == ["first_clear"], "unlocked list after repair")

	# --- info lookup
	var info = ACHIEVEMENTS.get_achievement_info("first_clear")
	check(info["name"] == "初次通关", "info resolves by id")
	check(ACHIEVEMENTS.get_achievement_info("nope")["id"] == "", "unknown id yields an empty placeholder")

	if failures == 0:
		print("achievements_test: ALL PASSED")
		quit(0)
	else:
		print("achievements_test: %d FAILURES" % failures)
		quit(1)
