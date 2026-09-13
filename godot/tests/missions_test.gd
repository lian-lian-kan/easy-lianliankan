extends SceneTree

# Unit tests for scripts/session/missions.gd — rolling-week state machine with
# a minimal fake game node (progression_state + patch + message capture).

const MISSIONS = preload("res://scripts/session/missions.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubEconomy:
	func refresh_economy_page(_game):
		pass

class FakeGame:
	var progression_state = {}
	var messages = []
	var ECONOMY = StubEconomy.new()
	func _patch_progress_state(patch):
		for k in patch:
			if k == "coins_delta":
				progression_state["coins"] = int(progression_state.get("coins", 0)) + int(patch[k])
			else:
				progression_state[k] = patch[k]
	func _show_message(msg, _dur):
		messages.append(msg)

func _init() -> void:
	print("== missions_test")

	# --- rolling week buckets
	check(MISSIONS.week_key_for(0) == "W0", "epoch starts bucket W0")
	check(MISSIONS.week_key_for(MISSIONS.WEEK_SECONDS - 1) == "W0", "last second of the week stays in W0")
	check(MISSIONS.week_key_for(MISSIONS.WEEK_SECONDS) == "W1", "first second of next week rolls to W1")
	check(MISSIONS.week_key_for(MISSIONS.WEEK_SECONDS * 5 + 12345) == "W5", "partial weeks floor to their bucket")

	# --- active state resets on week rollover
	var game = FakeGame.new()
	game.progression_state = {"weekly_missions": {"week_key": "W0", "progress": {"pairs_30": 9}, "claimed": ["pairs_30"]}}
	var state = MISSIONS.active_state(game)
	check(str(state["week_key"]) == MISSIONS.current_week_key(game), "stale week resets to the current bucket")
	check(MISSIONS.progress_of(state, "pairs_30") == 0 and not MISSIONS.is_claimed(state, "pairs_30"), "reset clears progress and claims")

	# --- record: additive, capped, max-merge and claimed short-circuits
	game = FakeGame.new()
	var fresh = MISSIONS.active_state(game)
	MISSIONS.record(game, "pairs_30", 10)
	MISSIONS.record(game, "pairs_30", 10)
	check(MISSIONS.progress_of(MISSIONS.active_state(game), "pairs_30") == 20, "additive missions accumulate")
	MISSIONS.record(game, "pairs_30", 999)
	check(MISSIONS.progress_of(MISSIONS.active_state(game), "pairs_30") == 30, "additive progress caps at target")
	MISSIONS.record(game, "combo_5", 3)
	MISSIONS.record(game, "combo_5", 2)
	check(MISSIONS.progress_of(MISSIONS.active_state(game), "combo_5") == 3, "max missions keep the highest seen")
	MISSIONS.record(game, "nope", 5)
	check(MISSIONS.progress_of(MISSIONS.active_state(game), "nope") == 0, "unknown mission ids are ignored")

	# --- completion nudge fires exactly once at the cap
	game = FakeGame.new()
	MISSIONS.active_state(game)
	MISSIONS.record(game, "specials_3", 3)
	var nudges = 0
	for m in game.messages:
		if "周任务达成" in str(m):
			nudges += 1
	MISSIONS.record(game, "specials_3", 1)
	check(nudges == 1, "reaching the target nudges once")

	# --- claim: pays once, gated on completion
	game = FakeGame.new()
	MISSIONS.active_state(game)
	MISSIONS.record(game, "levels_5", 2)
	MISSIONS.claim(game, "levels_5")
	check(int(game.progression_state.get("coins", 0)) == 0, "claiming an incomplete mission pays nothing")
	MISSIONS.record(game, "levels_5", 3)
	MISSIONS.claim(game, "levels_5")
	check(int(game.progression_state.get("coins", 0)) == 20, "claiming pays the mission reward")
	MISSIONS.claim(game, "levels_5")
	check(int(game.progression_state.get("coins", 0)) == 20, "claim is idempotent")
	check(MISSIONS.is_claimed(MISSIONS.active_state(game), "levels_5"), "claimed flag persists")
	MISSIONS.record(game, "levels_5", 5)
	check(MISSIONS.progress_of(MISSIONS.active_state(game), "levels_5") == 5, "claimed missions stop recording progress")

	if failures == 0:
		print("missions_test: ALL PASSED")
		quit(0)
	else:
		print("missions_test: %d FAILURES" % failures)
		quit(1)
