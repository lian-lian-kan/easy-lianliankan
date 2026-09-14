extends SceneTree

# Unit tests for scripts/session/revive.gd — the paid revival guards and
# effects (direct module coverage; session_fail_test exercises the same
# rules through session.gd's shells).

const REVIVE = preload("res://scripts/session/revive.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubButton:
	var visible = false

class StubLabel:
	var text = ""
	var visible = false

class StubTimer:
	func stop():
		pass
	func start():
		pass

class FakeGame extends Reference:
	const STATUS_PLAYING = "playing"
	const STATUS_FAILED = "failed"
	var audio = null
	var stage_status = "failed"
	var revive_cost = 0
	var revive_button = StubButton.new()
	var stage_panel_label = StubLabel.new()
	var second_timer = StubTimer.new()
	var time_left = 0
	var moves_left = 0
	var special_mode = ""
	var level = {"id": 2, "time_limit": 60}
	var progression_state = {"coins": 100}
	var patches = []
	var messages = []
	func _current_level():
		return level
	func _remaining_tiles_count():
		return 8
	func _start_second_timer():
		pass
	func _patch_progress_state(patch):
		patches.append(patch)
		if patch.has("coins_delta"):
			progression_state["coins"] = int(progression_state.get("coins", 0)) + int(patch["coins_delta"])
	func _refresh_ui():
		pass
	func _refresh_board_visuals():
		pass
	func _show_message(msg, _dur):
		messages.append(msg)

func _init() -> void:
	print("== revive_test")

	# --- coins_can_afford: exact balance counts as affordable
	var game = FakeGame.new()
	check(REVIVE.coins_can_afford(game, 100) == true, "an exact balance is affordable")
	check(REVIVE.coins_can_afford(game, 101) == false, "a short balance is not affordable")

	# --- offer: visibility follows affordability, cost is staged
	game = FakeGame.new()
	REVIVE._offer_revive(game, 30)
	check(int(game.revive_cost) == 30 and game.revive_button.visible == true, "an affordable revive is offered")
	game.progression_state = {"coins": 5}
	REVIVE._offer_revive(game, 30)
	check(game.revive_button.visible == false, "an unaffordable revive is hidden")

	# --- revive: wrong stage state refuses without spending
	game = FakeGame.new()
	game.stage_status = "playing"
	drive_revive(game)
	check(game.stage_status == "playing" and game.patches.empty(), "only a failed stage can revive")

	# --- paid revive: deducts, restores the clock, returns to playing
	game = FakeGame.new()
	game.time_left = 0
	game.moves_left = 0
	drive_revive(game)
	check(game.stage_status == "playing", "a paid revive returns to playing")
	check(int(game.progression_state["coins"]) == 70, "the 30-blossom cost is deducted")
	check(int(game.time_left) == 30, "a spent clock is restored to 25% of the limit (min 30)")
	check(game.revive_button.visible == false, "the button hides after reviving")

	# --- revive with moves: budget topped up instead of the clock
	game = FakeGame.new()
	game.level = {"id": 2, "move_budget": 40}
	game.moves_left = 0
	game.time_left = 20
	drive_revive(game)
	check(int(game.moves_left) == 5, "a move-budget stage tops the budget up to 5")
	check(int(game.time_left) == 20, "a move-budget stage keeps its clock")

	if failures == 0:
		print("revive_test: ALL PASSED")
		quit(0)
	else:
		print("revive_test: %d FAILURES" % failures)
		quit(1)

func drive_revive(game):
	REVIVE._revive(game)
