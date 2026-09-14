extends SceneTree

# Unit tests for hud_timers.gd: the timer inventory (specs match real
# callbacks), the second-tick heartbeat across every mode mechanic (defuse
# bomb tick, shift face swap, defense creep), race AI ticks and all the
# generic timeout callbacks.

const HUD_TIMERS = preload("res://scripts/session/hud_timers.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubSession:
	var fails := []
	func _fail_stage(_game, message):
		fails.append(message)

class StubEngine:
	var swaps := 0
	func swap_random_faces(_board):
		swaps += 1
		return true

class StubMechanics:
	var bomb_ticks := 0
	func tick_bombs(_game):
		bomb_ticks += 1

class StubAudio:
	var events := []
	func play_shuffle():
		events.append("shuffle")
	func play_select():
		events.append("select")

class FakeTimerGame extends Node:
	const STATUS_PLAYING = "playing"
	const STATUS_CLEARED = "cleared"
	const LEVEL_NORMAL_COLOR = Color("ffffff")
	var audio = StubAudio.new()
	var BOARD_ENGINE = StubEngine.new()
	var BOARD_MECHANICS = StubMechanics.new()
	var SESSION = StubSession.new()
	var stage_status = "playing"
	var special_mode = ""
	var time_frozen = false
	var time_left = 30
	var level = {"time_limit": 90}
	var board = [[1]]
	var board_bomb = {}
	var shift_countdown = 0
	var defense_countdown = 0
	var defense_distance = 3
	var race_elapsed = 0
	var race_ai_pairs = 0
	var race_total_pairs = 3
	var pending_level_index = -1
	var special_level = {"id": "endless"}
	var error_tiles = [Vector2(0, 0)]
	var message_label = Label.new()
	var level_select_option = null
	var second_timer = null
	var refreshes = 0
	var board_refreshes = 0
	var time_ups = 0
	var combo_resets = 0
	var level_resets = []
	var started_levels = []
	var second_ticks = 0
	func _on_second_tick():
		second_ticks += 1
	func _on_message_timeout():
		pass
	func _on_error_timeout():
		pass
	func _on_combo_reset_timeout():
		pass
	func _on_level_highlight_timeout():
		pass
	func _on_level_advance_timeout():
		pass
	func _on_time_freeze_timeout():
		pass
	func _on_memory_preview_timeout():
		pass
	func _on_memory_hide_timeout():
		pass
	func _on_flip_back_timeout():
		pass
	func _on_race_tick():
		pass
	func _current_level():
		return level
	func _refresh_ui():
		refreshes += 1
	func _refresh_board_visuals():
		board_refreshes += 1
	func _show_message(msg, _dur):
		pass
	func _on_time_up():
		time_ups += 1
	func _reset_combo():
		combo_resets += 1
	func _fail_race_lost():
		time_ups += 100  # marker distinct from time-ups
	func _reset_level_session(level, reset_total):
		level_resets.append([level, reset_total])
	func _start_level(index, reset_total):
		started_levels.append([index, reset_total])

func _init() -> void:
	print("== hud_timers_test")

	# --- inventory: every spec points at a real method; waits are honoured
	for timer_name in HUD_TIMERS.TIMER_SPECS:
		var spec = HUD_TIMERS.TIMER_SPECS[timer_name]
		check(FakeTimerGame.new().has_method(spec["callback"]),
			"spec %s targets a real method" % timer_name)
	check(HUD_TIMERS.TIMER_SPECS["flip_back_timer"]["wait"] == 0.7,
		"flip-back keeps its 0.7s wait")

	# --- build: one Timer per spec, wired and stored on the game
	var builder = FakeTimerGame.new()
	HUD_TIMERS._build_timers(builder)
	check(builder.second_timer != null and builder.second_timer is Timer,
		"build stores a Timer under each spec name")
	check(builder.second_timer.wait_time == 1.0 and builder.second_timer.one_shot == false,
		"the heartbeat repeats every second")
	check(builder.flip_back_timer.wait_time == 0.7 and builder.flip_back_timer.one_shot,
		"the flip-back timer is one-shot at 0.7s")

	# --- second tick: gates
	var game = FakeTimerGame.new()
	game.stage_status = "paused"
	HUD_TIMERS._on_second_tick(game)
	check(game.time_left == 30 and game.refreshes == 0, "a paused stage never ticks")
	game.stage_status = "playing"
	game.time_frozen = true
	HUD_TIMERS._on_second_tick(game)
	check(game.time_left == 30, "a frozen clock never ticks")
	game.time_frozen = false
	game.special_mode = "endless"
	HUD_TIMERS._on_second_tick(game)
	check(game.time_left == 30, "endless has no countdown clock")
	game.special_mode = ""
	game.level = {"time_limit": 0}
	HUD_TIMERS._on_second_tick(game)
	check(game.time_left == 30, "a zero time limit means no countdown")

	# --- second tick: normal decrement, floor and time-up
	game = FakeTimerGame.new()
	game.level = {"time_limit": 90}
	HUD_TIMERS._on_second_tick(game)
	check(game.time_left == 29 and game.refreshes == 1, "a live clock ticks one second")
	game.time_left = 0
	game.refreshes = 0
	HUD_TIMERS._on_second_tick(game)
	check(game.time_left == 0 and game.time_ups == 1, "hitting zero fires time-up once")

	# --- defuse: bombs tick while any are on the board
	game = FakeTimerGame.new()
	game.special_mode = "defuse"
	game.board_bomb = {"0_0": {"fuse": 3}}
	HUD_TIMERS._on_second_tick(game)
	check(game.BOARD_MECHANICS.bomb_ticks == 1, "defuse ticks every bomb each second")

	# --- shift: countdown resets and faces swap on zero
	game = FakeTimerGame.new()
	game.special_mode = "shift"
	game.level = {"time_limit": 90, "shift_interval": 2}
	game.shift_countdown = 2
	HUD_TIMERS._on_second_tick(game)
	check(game.shift_countdown == 1 and game.BOARD_ENGINE.swaps == 0,
		"shift counts down silently until zero")
	game.shift_countdown = 1
	HUD_TIMERS._on_second_tick(game)
	check(game.shift_countdown == 2 and game.BOARD_ENGINE.swaps == 1,
		"shift zero resets the interval and swaps faces")

	# --- defense: creep every interval, lose at distance zero
	game = FakeTimerGame.new()
	game.special_mode = "defense"
	game.level = {"time_limit": 90, "defense_step": 3}
	game.defense_countdown = 1
	game.defense_distance = 2
	HUD_TIMERS._on_second_tick(game)
	check(game.defense_distance == 1 and game.defense_countdown == 3,
		"defense creep resets the step and closes one distance")
	game.defense_countdown = 1
	game.defense_distance = 1
	HUD_TIMERS._on_second_tick(game)
	check(game.SESSION.fails.size() == 1, "distance zero loses the run")

	# --- race AI tick
	game = FakeTimerGame.new()
	game.special_mode = "race"
	game.level = {"ai_interval": 2}
	HUD_TIMERS._on_race_tick(game)
	check(game.race_ai_pairs == 0 and game.race_elapsed == 1,
		"the AI waits out its interval")
	HUD_TIMERS._on_race_tick(game)
	check(game.race_ai_pairs == 1 and game.race_elapsed == 0,
		"interval elapsed: the AI clears one pair")
	game.race_total_pairs = 1
	game.race_elapsed = 1
	HUD_TIMERS._on_race_tick(game)
	check(game.time_ups == 100, "AI finishing the board loses the run")

	# --- generic timeouts
	game = FakeTimerGame.new()
	game.message_label = Label.new()
	game.message_label.visible = true
	HUD_TIMERS._on_message_timeout(game)
	check(game.message_label.visible == false, "message timeout hides the banner")
	game.error_tiles = [Vector2(0, 0)]
	HUD_TIMERS._on_error_timeout(game)
	check(game.error_tiles.empty() and game.board_refreshes == 1,
		"error timeout clears flashes")
	HUD_TIMERS._on_combo_reset_timeout(game)
	check(game.combo_resets == 1, "combo timeout resets the streak")

	game = FakeTimerGame.new()
	game.level_select_option = Label.new()
	game.level_select_option.modulate = Color(1, 0, 0)
	HUD_TIMERS._on_level_highlight_timeout(game)
	check(game.level_select_option.modulate == Color("ffffff"),
		"highlight timeout restores the picker color")
	game.level_select_option = null
	HUD_TIMERS._on_level_highlight_timeout(game)
	check(true, "highlight timeout is null-safe")

	game = FakeTimerGame.new()
	game.stage_status = "playing"
	game.pending_level_index = 5
	HUD_TIMERS._on_level_advance_timeout(game)
	check(game.started_levels.empty(), "advance only fires from the cleared state")
	game.stage_status = "cleared"
	HUD_TIMERS._on_level_advance_timeout(game)
	check(game.started_levels == [[5, false]], "cleared advance starts the pending level")
	game = FakeTimerGame.new()
	game.stage_status = "cleared"
	game.pending_level_index = -1
	HUD_TIMERS._on_level_advance_timeout(game)
	check(game.started_levels.empty(), "no pending level means no advance")

	game = FakeTimerGame.new()
	game.stage_status = "cleared"
	game.pending_level_index = 4
	game.special_mode = "endless"
	HUD_TIMERS._on_level_advance_timeout(game)
	check(game.level_resets == [[game.special_level, false]],
		"endless advance rolls the next round instead of starting a level")

	game = FakeTimerGame.new()
	game.time_frozen = true
	HUD_TIMERS._on_time_freeze_timeout(game)
	check(game.time_frozen == false, "freeze timeout thaws the clock")

	if failures == 0:
		print("hud_timers_test: ALL PASSED")
		quit(0)
	else:
		print("hud_timers_test: %d FAILURES" % failures)
		quit(1)
