extends SceneTree

# Unit tests for session.gd's _apply_combo_gain: combo chaining within the
# window, reset after expiry, the max-combo cap, level score multipliers and
# the time-attack/fever time refund — all through a fake game node.

const SESSION = preload("res://scripts/session/session.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeTimer:
	var wait_time = 0.0
	var started = 0
	var stopped = 0
	func stop():
		stopped += 1
	func start():
		started += 1

class FakeGame extends Reference:
	var tuning = {"combo_window_ms": 2600, "max_combo": 8}
	var game_mode_configs = {}
	var special_mode = ""
	var time_left = 60
	var total_score = 0
	var level_score = 0
	var combo = 0
	var combo_expires_ms = 0
	var combo_reset_timer = FakeTimer.new()
	var level = {"score_multiplier": 1.0}
	var progression_state = {}
	var patches = []
	var pair_hooks = 0
	var combo_hooks = []
	var bursts = []
	func _current_level():
		return level
	var messages = []
	func _patch_progress_state(patch):
		patches.append(patch)
	func _show_message(msg, _dur):
		messages.append(msg)
	func _mission_pair_cleared():
		pair_hooks += 1
	func _mission_combo_reached(combo):
		combo_hooks.append(combo)
	func _combo_cheer(_gain):
		return ""
	func _show_combo_burst(cheer):
		bursts.append(cheer)

func _init() -> void:
	print("== session_combo_test")

	# --- first match: combo 1, the 1.5x base multiplier
	var game = FakeGame.new()
	var result = SESSION._apply_combo_gain(game, 10)
	check(int(result["combo"]) == 1 and int(result["gain"]) == 15, "combo 1 pays base x1.5 (10 -> 15)")
	check(int(game.total_score) == 15 and int(game.level_score) == 15, "gain lands on both score totals")
	check(game.combo_reset_timer.started == 1, "the combo window re-arms")
	check(game.patches.size() == 1 and int(game.patches[0]["score_candidate"]) == 15, "the score candidate is pushed to progression")
	check(game.pair_hooks == 1 and game.combo_hooks == [1], "weekly mission hooks fire for the pair and the combo")

	# --- chaining within the window raises the multiplier by +0.5x per level
	result = SESSION._apply_combo_gain(game, 10)
	check(int(result["combo"]) == 2 and int(result["gain"]) == 20, "combo 2 pays base x2.0 (10 -> 20)")

	# --- expiry: once the window lapses the combo restarts at 1
	game.combo_expires_ms = 0
	result = SESSION._apply_combo_gain(game, 10)
	check(int(result["combo"]) == 1, "a lapsed window resets the combo to 1")

	# --- cap: the combo never exceeds max_combo
	game = FakeGame.new()
	game.combo_expires_ms = 999999999
	var gains = []
	for _i in range(12):
		result = SESSION._apply_combo_gain(game, 10)
		gains.append(int(result["gain"]))
	check(int(result["combo"]) == 8, "the combo caps at max_combo")
	check(int(gains[gains.size() - 1]) == 50, "the capped combo pays base x5.0 (10 -> 50)")

	# --- level score multiplier scales the base before the combo multiplier
	game = FakeGame.new()
	game.level = {"score_multiplier": 2.0}
	result = SESSION._apply_combo_gain(game, 10)
	check(int(result["gain"]) == 30, "a x2 level multiplies combo 1 to 10*2*1.5 = 30")

	# --- time attack: fever multiplier + clock refund from combo threshold
	game = FakeGame.new()
	game.special_mode = "time_attack"
	game.game_mode_configs = {
		"time_attack": {"fever_mode_threshold": 2, "fever_multiplier": 2.0,
			"time_bonus_per_match": 3, "combo_time_bonus": 1}
	}
	result = SESSION._apply_combo_gain(game, 10)  # combo 1: below fever, plain refund
	check(int(game.time_left) == 63, "time attack refunds 3 seconds per match below fever")
	result = SESSION._apply_combo_gain(game, 10)  # combo 2: fever ignites
	check(int(game.time_left) == 67, "fever adds the combo time bonus (+4 total refund)")
	check(int(result["gain"]) == 40, "fever doubles the combo-2 gain (10*2.0*2.0 = 40)")
	check(game.messages.size() == 1, "fever ignition announces itself once")

	if failures == 0:
		print("session_combo_test: ALL PASSED")
		quit(0)
	else:
		print("session_combo_test: %d FAILURES" % failures)
		quit(1)
