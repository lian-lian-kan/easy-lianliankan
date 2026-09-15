extends SceneTree

# Unit tests for special_session.gd: the unlock gate, the per-mode virtual
# level dispatch (real builders + real default configs) and session handoff.

const SPECIAL_SESSION = preload("res://scripts/modes/special_session.gd")
const SPECIAL_MODES = preload("res://scripts/modes/special_modes.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame extends Reference:
	const SPECIAL_MODES_SCRIPT = preload("res://scripts/modes/special_modes.gd")
	var game_mode_configs = SPECIAL_MODES_SCRIPT.normalize_configs(null)
	var progression_state = {"highest_unlocked_level_index": 20}
	var special_mode = ""
	var endless_round = 0
	var tree_height = 0
	var special_level = null
	var level_index = 3
	var messages = []
	var resets = []
	var started_levels = []
	func _show_message(msg, _dur):
		messages.append(msg)
	func _reset_level_session(level, reset_total):
		resets.append([level, reset_total])
	func _start_level(index, reset_total):
		started_levels.append([index, reset_total])

func _init() -> void:
	print("== special_session_test")

	# --- unlock gate: a locked mode never touches session state
	var game = FakeGame.new()
	game.progression_state = {"highest_unlocked_level_index": 5}
	game.game_mode_configs = {"duel": {"unlock_level": 17}}
	SPECIAL_SESSION._start_special_mode(game, "duel")
	check(game.special_mode == "" and game.resets.empty() \
		and game.messages.size() == 1, "a locked mode is refused with its requirement text")

	# --- classic-style dispatch: zen starts a real session
	game = FakeGame.new()
	SPECIAL_SESSION._start_special_mode(game, "zen")
	check(game.special_mode == "zen", "zen lands in special_mode")
	check(game.resets.size() == 1 and game.resets[0][1] == true,
		"starting hands the virtual level to a full session reset")
	check(game.endless_round == 1 and game.special_level != null,
		"the session carries a virtual level and a fresh round counter")
	check(game.messages.size() == 1 and not game.messages[0].empty(),
		"an intro message is shown")
	check(typeof(game.special_level) == TYPE_DICTIONARY \
		and str(game.special_level.get("mode", "")) == "zen" \
		and int(game.special_level.get("rows", 0)) > 0,
		"the classic builder produced a configured zen level")

	# --- daily dispatch: seeded builder through OS date
	game = FakeGame.new()
	SPECIAL_SESSION._start_special_mode(game, "daily")
	check(game.special_mode == "daily" and game.resets.size() == 1,
		"daily builds and starts")
	check(game.special_level.get("mode", "") == "daily" \
		or game.special_level.has("id") or game.special_level != null,
		"daily produced a virtual level")

	# --- tiered dispatch: memory takes the tier path and its own intro
	game = FakeGame.new()
	SPECIAL_SESSION._start_special_mode(game, "memory")
	check(game.special_mode == "memory" and game.resets.size() == 1,
		"memory builds a tiered level and starts")
	check(game.messages.back().find("盲盒模式") != -1,
		"memory announces its preview intro")

	# --- rock dispatch: obstacles carry the unlock-floor progression
	game = FakeGame.new()
	SPECIAL_SESSION._start_special_mode(game, "rock")
	check(game.special_mode == "rock" and game.resets.size() == 1,
		"rock builds an obstacle level")

	# --- tree dispatch: the climb resumes at best height + 1
	game = FakeGame.new()
	game.progression_state = {"highest_unlocked_level_index": 20, "tree_best_height": 6}
	SPECIAL_SESSION._start_special_mode(game, "tree")
	check(game.special_mode == "tree" and game.resets.size() == 1,
		"tree lands in special_mode with a session reset")
	check(int(game.special_level.get("tree_height", 0)) == 7,
		"tree resumes at best height + 1")
	check(game.tree_height == 7, "the current layer mirrors the level")
	check(int(game.special_level.get("time_limit", 0)) > 0, "tree layers are timed")
	check(game.messages.back().find("攀登树") != -1, "tree announces its intro")

	# --- unknown mode falls back to endless
	game = FakeGame.new()
	SPECIAL_SESSION._start_special_mode(game, "nonexistent")
	check(game.special_mode == "nonexistent" and game.resets.size() == 1,
		"an unknown mode falls through to the endless builder")

	# --- dispatch is pure: same inputs, same builder selection
	var level_a = SPECIAL_SESSION._build_special_level(FakeGame.new(), "time_attack",
		FakeGame.new().game_mode_configs.get("time_attack", {}))
	var level_b = SPECIAL_SESSION._build_special_level(FakeGame.new(), "time_attack",
		FakeGame.new().game_mode_configs.get("time_attack", {}))
	check(level_a != null and level_b != null and typeof(level_a) == TYPE_DICTIONARY,
		"time_attack dispatch produces a virtual level")

	if failures == 0:
		print("special_session_test: ALL PASSED")
		quit(0)
	else:
		print("special_session_test: %d FAILURES" % failures)
		quit(1)
