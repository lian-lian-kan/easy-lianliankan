extends SceneTree

# Unit tests for session.gd's _settle_campaign_rewards: the time bonus,
# star rating by remaining-time ratio, unlock/cursor progression and the
# final-level wrap-around — pure settlement math via a fake game node.

const SESSION = preload("res://scripts/session/session.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame extends Reference:
	var campaign_levels = [{"id": 1}, {"id": 2}, {"id": 3}]
	var level_index = 0
	var time_left = 40
	var total_score = 100
	var level_score = 20
	var combo = 4
	var progression_state = {}
	var level = {
		"id": 1,
		"time_limit": 60,
		"time_bonus_multiplier": 2.0,
	}
	var patches = []
	func _current_level():
		return level

	func _patch_progress_state(patch):
		patches.append(patch)
		if patch.has("current_level_index"):
			level_index = int(patch["current_level_index"])
		if patch.has("coins_delta"):
			progression_state["coins"] = int(progression_state.get("coins", 0)) + int(patch["coins_delta"])

func stars_for_ratio(ratio: float) -> int:
	return 3 if ratio >= 0.5 else (2 if ratio >= 0.25 else 1)

func _init() -> void:
	print("== session_settle_test")

	# --- intermediate clear: bonus, stars, cursor and unlock advance
	var game = FakeGame.new()
	var reward = SESSION._settle_campaign_rewards(game)
	check(int(reward["time_bonus"]) == 80, "40s left at x2.0 pays an 80 point time bonus")
	check(int(reward["stars"]) == 3, "finishing with 2/3 of the clock earns 3 stars")
	check(int(reward["coin_reward"]) == 10, "level 1 pays the 8+2 coin reward")
	check(int(game.total_score) == 180 and int(game.level_score) == 100, "the time bonus lands on both score totals")
	check(game.patches.size() == 1, "settlement pushes exactly one progression patch")
	var patch = game.patches[0]
	check(int(patch["current_level_index"]) == 1 and int(patch["highest_unlocked_level_index"]) == 1, "an intermediate clear advances cursor and unlock together")
	check(int(patch["score_candidate"]) == 180 and int(patch["combo_candidate"]) == 4, "settlement records the best-score candidates")
	check(int(patch["stars"]["stars"]) == 3, "the star rating persists for the level")

	# --- star tiers by remaining-time ratio
	game = FakeGame.new()
	game.time_left = 15  # ratio 0.25
	reward = SESSION._settle_campaign_rewards(game)
	check(int(reward["stars"]) == 2, "a quarter of the clock earns 2 stars")
	game = FakeGame.new()
	game.time_left = 5  # ratio ~0.08
	reward = SESSION._settle_campaign_rewards(game)
	check(int(reward["stars"]) == 1, "a sliver of the clock earns 1 star")

	# --- clockless level: stars default to 1
	game = FakeGame.new()
	game.level = {"id": 1, "time_limit": 0}
	reward = SESSION._settle_campaign_rewards(game)
	check(int(reward["stars"]) == 1, "clockless levels keep 1 star")
	check(int(reward["time_bonus"]) == 80, "clockless levels still apply the multiplier to the remaining clock value")

	# --- final clear: wrap the cursor, unlock everything
	game = FakeGame.new()
	game.level_index = 2  # last of three
	game.level = {"id": 3, "time_limit": 60, "time_bonus_multiplier": 2.0}
	reward = SESSION._settle_campaign_rewards(game)
	check(bool(reward["is_final"]), "the last level settles as final")
	check(int(game.level_index) == 0, "the final clear wraps the cursor to level 1")
	check(game.patches[0]["highest_unlocked_level_index"] == 2, "the final clear unlocks every level")

	if failures == 0:
		print("session_settle_test: ALL PASSED")
		quit(0)
	else:
		print("session_settle_test: %d FAILURES" % failures)
		quit(1)
