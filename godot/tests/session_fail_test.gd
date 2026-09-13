extends SceneTree

# Unit tests for the fail/revive flow in session.gd: time-up on campaign vs
# special sessions, the revive offer gate and a successful paid revival.

const SESSION = preload("res://scripts/session/session.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubAudio:
	func play_fail():
		pass
	func play_hint():
		pass
	func play_voice_path(_p):
		pass

class StubVoice:
	func play(_game, _key):
		pass

class StubButton:
	var visible = false

class StubLabel:
	var text = ""
	var visible = false

class StubTimer:
	var wait_time = 0.0
	func stop():
		pass
	func start():
		pass

class FakeGame extends Reference:
	const PROGRESSION_SCRIPT = preload("res://scripts/session/progression.gd")
	const STATUS_PLAYING = "playing"
	const STATUS_PAUSED = "paused"
	const STATUS_CLEARED = "cleared"
	const STATUS_FAILED = "failed"
	const STATUS_COMPLETED = "completed"
	var audio = StubAudio.new()
	var VOICE_LINES = StubVoice.new()
	var stage_status = "playing"
	var second_timer = StubTimer.new()
	var stage_panel_label = StubLabel.new()
	var revive_button = StubButton.new()
	var revive_cost = 0
	var time_left = 0
	var moves_left = 0
	var total_score = 120
	var combo = 3
	var level_index = 0
	var campaign_levels = [0, 1, 2]
	var special_mode = ""
	var progression_state = {"coins": 100}
	var selected = Vector2(-1, -1)
	var hint_tiles = []
	var error_tiles = []
	var messages = []
	var patches = []
	func _is_special_session():
		return special_mode != ""
	func _current_level():
		return {"id": 1, "time_limit": 60}
	func _remaining_tiles_count():
		return 8
	func _reset_combo():
		combo = 0
	func _refresh_ui():
		pass
	func _refresh_board_visuals():
		pass
	func _start_second_timer():
		pass
	func _patch_progress_state(patch):
		patches.append(patch)
		if patch.has("coins_delta"):
			progression_state["coins"] = int(progression_state.get("coins", 0)) + int(patch["coins_delta"])
		if patch.has("current_level_index"):
			level_index = int(patch["current_level_index"])
	func _show_message(msg, _dur):
		messages.append(msg)

func _init() -> void:
	print("== session_fail_test")

	# --- campaign time-up: keeps progress, offers the 30-blossom revive
	var game = FakeGame.new()
	SESSION._on_time_up(game)
	check(game.stage_status == "failed", "time-up fails the stage")
	check(game.patches.size() == 1 and int(game.patches[0]["current_level_index"]) == 0, "campaign time-up keeps the level cursor")
	check(int(game.revive_cost) == 30, "campaign time-up offers the standard 30 revive")
	check(game.revive_button.visible == true, "the revive button shows when affordable")
	check(game.audio != null and game.messages.size() >= 1, "the failure announces itself")

	# --- special session time-up: no revival offered
	game = FakeGame.new()
	game.special_mode = "hell"
	SESSION._on_time_up(game)
	check(game.stage_status == "failed" and int(game.revive_cost) == 0, "special sessions fail without a revive offer")

	# --- revive guards: wrong state or empty wallet refuse
	game = FakeGame.new()
	game.stage_status = "failed"
	game.revive_cost = 30
	game.revive_button.visible = true
	SESSION._revive(game)
	check(game.stage_status == "failed", "reviving without coins keeps the stage failed")

	# --- paid revive: coins deducted, clock restored, back to playing
	game = FakeGame.new()
	game.stage_status = "failed"
	game.revive_cost = 30
	game.time_left = 0
	game.moves_left = 0
	SESSION._revive(game)
	check(game.stage_status == "playing", "a paid revive returns to playing")
	check(int(game.progression_state["coins"]) == 70, "the revive cost is deducted")
	check(int(game.time_left) == 30, "the clock is restored to at least 30 seconds")
	check(game.revive_button.visible == false, "the revive button hides after use")

	if failures == 0:
		print("session_fail_test: ALL PASSED")
		quit(0)
	else:
		print("session_fail_test: %d FAILURES" % failures)
		quit(1)
