extends SceneTree

# Unit tests for scripts/pages/economy.gd — collection bookkeeping and
# level-clear rewards (pure rules driven through a fake game node).

const ECONOMY = preload("res://scripts/pages/economy.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame:
	var special_mode = "collect"
	var collect_targets = {0: 2, 1: 1}
	var collect_progress = {}
	var icon_sets = [{"id": "fruit", "icons": ["A", "B", "C"]}]
	var icon_set_index = 0
	var progression_state = {"collected": ["fruit:0"]}
	var cleared = 0
	var patches = []
	var messages = []
	func _current_level():
		return {"kinds": 3}
	func _patch_progress_state(patch):
		patches.append(patch)
		for k in patch:
			if k == "coins_delta":
				progression_state["coins"] = int(progression_state.get("coins", 0)) + int(patch[k])
			elif k == "collect_many":
				for entry in patch[k]:
					if not progression_state["collected"].has(entry):
						progression_state["collected"].append(entry)
			else:
				progression_state[k] = patch[k]
	func update_collect_labels(_game):
		pass
	func _resolve_collect_clear():
		cleared += 1
	func _show_message(msg, _dur):
		messages.append(msg)

func _init() -> void:
	print("== economy_test")

	# --- level-clear reward formula
	check(ECONOMY.level_clear_reward({"id": 1}) == 10, "level 1 pays 8+2")
	check(ECONOMY.level_clear_reward({"id": 5}) == 18, "level 5 pays 8+10")
	check(ECONOMY.level_clear_reward({}) == 8, "missing id defaults to 8")

	# --- collection keys are set-scoped
	check(ECONOMY.collection_key("fruit", 3) == "fruit:3", "collection key is set:index")

	# --- collect challenge: progress caps at target, completion fires once
	var game = FakeGame.new()
	ECONOMY.collect_pair(game, [0, 0, 1])
	check(int(game.collect_progress[0]) == 2 and int(game.collect_progress[1]) == 1, "cleared pairs count toward their targets")
	check(game.cleared == 1, "completing every target resolves the challenge")

	game = FakeGame.new()
	game.collect_targets = {0: 2}
	ECONOMY.collect_pair(game, [0])
	check(game.cleared == 0, "partial progress does not complete the challenge")
	ECONOMY.collect_pair(game, [0])
	check(game.cleared == 1, "reaching every target completes exactly once")
	ECONOMY.collect_pair(game, [0])
	check(game.cleared == 1, "progress capped at the target never re-completes")
	game.special_mode = "zen"
	ECONOMY.collect_pair(game, [0])
	check(game.cleared == 1, "non-collect modes never count pairs")

	# --- collection page: fresh icons pay once, repeats pay nothing
	game = FakeGame.new()
	ECONOMY.collect_level_icons(game)
	check(game.patches.size() == 1, "a fresh icon set pays a collection reward")
	check(int(game.patches[0]["coins_delta"]) == 12, "two fresh icons pay 6 blossoms each")
	check(game.progression_state["collected"] == ["fruit:0", "fruit:1", "fruit:2"], "paid icons are recorded")
	ECONOMY.collect_level_icons(game)
	check(game.patches.size() == 1, "replaying the same set pays nothing")

	if failures == 0:
		print("economy_test: ALL PASSED")
		quit(0)
	else:
		print("economy_test: %d FAILURES" % failures)
		quit(1)
