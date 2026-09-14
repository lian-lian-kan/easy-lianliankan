extends SceneTree

# Unit tests for session.gd's clock/move consumption and the husband rescue:
# clockless guards, move exhaustion, once-per-round husband call semantics —
# through a fake game node (audio/voice/input stubbed).

const SESSION = preload("res://scripts/session/session.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubAudio:
	func play_hint():
		pass
	func play_select():
		pass

class StubInput:
	var reveals = 0
	func reveal_hint_pair(_game, _hint):
		reveals += 1
		return true

class StubTimer:
	func stop():
		pass
	func start():
		pass

class FakeGame extends Reference:
	const STATUS_PLAYING = "playing"
	const STATUS_FAILED = "failed"
	const CHEERS = preload("res://scripts/content/cheers.gd")
	var audio = StubAudio.new()
	var husband_called = false
	var stage_status = "playing"
	var time_left = 50
	var moves_left = 0
	var special_mode = ""
	var board = [[1, 0, 0, 1]]
	var hint = {"a": Vector2(0, 0), "b": Vector2(0, 3), "path": []}
	var level = {"time_limit": 60}
	var reshuffles = 0
	var time_ups = 0
	var move_fails = 0
	var messages = []
	var refreshes = 0
	var GAME_INPUT = StubInput.new()
	func _current_level():
		return level
	func _find_any_hint(_board):
		return hint
	func _reshuffle_board(_board):
		reshuffles += 1
	func _show_message(msg, _dur):
		messages.append(msg)
	func _refresh_ui():
		refreshes += 1
	func _on_time_up():
		time_ups += 1
	func _fail_moves_exhausted():
		move_fails += 1
	func _remaining_tiles_count():
		return 8

func _init() -> void:
	print("== session_clock_test")

	# --- _consume_time_cost: clockless modes are a no-op
	var game = FakeGame.new()
	game.level = {"time_limit": 0}
	SESSION._consume_time_cost(game, 5)
	check(int(game.time_left) == 50 and game.time_ups == 0, "clockless modes never drain")

	# --- _consume_time_cost: drains, floors at zero and fires time-up once
	game = FakeGame.new()
	SESSION._consume_time_cost(game, 5)
	check(int(game.time_left) == 45 and game.refreshes == 1, "clock drains by the requested seconds")
	SESSION._consume_time_cost(game, 999)
	check(int(game.time_left) == 0 and game.time_ups == 1, "draining to zero fires time-up exactly once")
	SESSION._consume_time_cost(game, 10)
	check(int(game.time_left) == 0 and game.time_ups == 1, "a spent clock refuses further drains")

	# --- _consume_move: only the moves mode consumes, exhaustion fails once
	game = FakeGame.new()
	game.moves_left = 2
	SESSION._consume_move(game)
	check(int(game.moves_left) == 1 and game.move_fails == 0, "non-moves modes never consume")
	game.special_mode = "moves"
	SESSION._consume_move(game)
	check(int(game.moves_left) == 1, "moves mode consumes the budget")
	SESSION._consume_move(game)
	check(int(game.moves_left) == 0 and game.move_fails == 1, "exhausting the budget fails the stage once")
	SESSION._consume_move(game)
	check(int(game.moves_left) == 0 and game.move_fails == 1, "an exhausted budget refuses further consumption")

	# --- husband rescue: once per round, +15 seconds, free pair reveal
	game = FakeGame.new()
	SESSION.call_husband(game)
	check(game.husband_called == true, "the rescue marks itself as used")
	check(int(game.time_left) == 65, "the rescue grants 15 seconds")
	check(game.GAME_INPUT.reveals == 1, "the rescue reveals a free pair hint")
	var msg: String = game.messages[0] if game.messages.size() > 0 else ""
	check(msg.find("+15") != -1, "the rescue banner announces the bonus seconds")
	SESSION.call_husband(game)
	check(game.GAME_INPUT.reveals == 1, "a second call in the same round is refused")

	# --- husband rescue with a dead board: reshuffles before revealing
	game = FakeGame.new()
	game.hint = {}
	SESSION.call_husband(game)
	check(game.reshuffles == 1, "a dead board reshuffles before revealing")

	if failures == 0:
		print("session_clock_test: ALL PASSED")
		quit(0)
	else:
		print("session_clock_test: %d FAILURES" % failures)
		quit(1)
