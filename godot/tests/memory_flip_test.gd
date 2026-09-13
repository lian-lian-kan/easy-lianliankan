extends SceneTree

# Unit tests for scripts/modes/memory_flip.gd — the 翻翻乐 state machine.

const FLIP = preload("res://scripts/modes/memory_flip.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame:
	var special_level = {"pairs": 2}
	var flip_state = null
	var flip_layer = null  # null keeps build_view a no-op in headless tests

func layout(game, patterns):
	var cards = []
	for p in patterns:
		cards.append({"pattern": p, "flipped": false, "removed": false})
	game.flip_state["cards"] = cards

func _init() -> void:
	print("== memory_flip_test")

	# --- new_round deals pairs * 2 face-down cards
	var game = FakeGame.new()
	FLIP.new_round(game)
	check(game.flip_state["cards"].size() == 4 and game.flip_state["pairs_left"] == 2, "new_round deals two copies of each pattern")
	var all_down = true
	for c in game.flip_state["cards"]:
		if c["flipped"] or c["removed"]:
			all_down = false
	check(all_down, "every card starts face down and on the board")

	# --- deterministic layout: 0, 1, 0, 1
	layout(game, [0, 1, 0, 1])
	check(FLIP.flip(game, -1) == "", "out-of-range flips are ignored")
	check(FLIP.flip(game, 9) == "", "beyond-range flips are ignored")
	check(FLIP.flip(game, 0) == "", "first flip of a turn returns empty")
	check(FLIP.flip(game, 0) == "", "re-flipping the open card is ignored")
	check(FLIP.flip(game, 1) == "miss", "two different patterns miss")
	FLIP.unflip_misses(game)
	check(game.flip_state["open"].empty(), "unflip clears the open pair")

	# --- matching removes the pair; last pair clears
	check(FLIP.flip(game, 2) == "", "first half of the real pair opens")
	check(FLIP.flip(game, 0) == "match", "matching patterns clear as a pair")
	check(game.flip_state["pairs_left"] == 1, "pairs_left counts down")
	check(game.flip_state["cards"][2]["removed"] and game.flip_state["cards"][0]["removed"], "matched cards leave the board")
	check(FLIP.flip(game, 0) == "", "removed cards cannot flip again")
	check(FLIP.flip(game, 1) == "", "second card of the final pair opens")
	check(FLIP.flip(game, 3) == "cleared", "final pair reports cleared")
	check(game.flip_state["pairs_left"] == 0, "all pairs are gone")

	# --- mismatch keeps cards on the board until unflip_misses
	layout(game, [0, 1, 0, 1])
	FLIP.flip(game, 0)
	FLIP.flip(game, 1)
	check(game.flip_state["cards"][0]["removed"] == false, "a miss never removes cards")
	check(game.flip_state["open"] == [0, 1], "the missed pair stays open for the pause window")

	if failures == 0:
		print("memory_flip_test: ALL PASSED")
		quit(0)
	else:
		print("memory_flip_test: %d FAILURES" % failures)
		quit(1)
