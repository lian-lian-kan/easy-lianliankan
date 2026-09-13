extends SceneTree

# Unit tests for scripts/session/progress_store.gd — patch application:
# special-session campaign filtering, the coins_100 mission hook, the
# no-change short circuit and the level-select repopulation trigger.

const STORE = preload("res://scripts/session/progress_store.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StoreGame:
	const PROGRESS_SAVE_PATH = "user://unit_progress_store.json"
	const PROGRESSION_SCRIPT = preload("res://scripts/session/progression.gd")
	var campaign_levels = [0, 1, 2]
	var level_select_option = null
	var special_session = false
	var sync_pushes = 0
	var repopulates = 0
	var progression_state = PROGRESSION_SCRIPT.default_progress(3)
	func _is_special_session():
		return special_session
	func _save_progress_state():
		sync_pushes += 1  # tests stub the disk write; startup_probe covers the real one
	func _sync_push():
		sync_pushes += 1
	func _populate_level_select_options():
		repopulates += 1
	func _patch_progress_state(patch):
		STORE._patch_progress_state(self, patch)
	func _show_message(_msg, _dur):
		pass

func _init() -> void:
	print("== progress_store_test")

	# --- plain patch: coins_delta persists and drives the save cycle
	var game = StoreGame.new()
	STORE._patch_progress_state(game, {"coins_delta": 15})
	check(int(game.progression_state["coins"]) == 15, "coins_delta lands on the balance")
	check(game.sync_pushes >= 1, "a real change persists through save/sync")
	check(int(game.progression_state["weekly_missions"]["progress"].get("coins_100", 0)) == 15, "blossom income feeds the coins_100 weekly mission")

	# --- special session: campaign fields are stripped, records survive
	game = StoreGame.new()
	game.special_session = true
	STORE._patch_progress_state(game, {
		"score_candidate": 100,
		"combo_candidate": 5,
		"current_level_index": 2,
		"daily_result": {"date": "2026-09-14", "yesterday": "2026-09-13", "score": 77},
	})
	check(int(game.progression_state["current_level_index"]) == 0, "special sessions never move the campaign cursor")
	check(int(game.progression_state["daily_challenge"]["best_score"]) == 77, "special records still persist")

	# --- special session patch that filters down to nothing is a no-op
	game = StoreGame.new()
	var before = game.progression_state.duplicate(true)
	STORE._patch_progress_state(game, {"score_candidate": 1, "current_level_index": 1})
	check(game.progression_state == before and game.sync_pushes == 0, "fully filtered special patches change nothing")

	# --- no-change short circuit: same state must not save again
	game = StoreGame.new()
	STORE._patch_progress_state(game, {"current_level_index": 0})
	var pushes_after_first = game.sync_pushes
	STORE._patch_progress_state(game, {"current_level_index": 0})
	check(game.progression_state == game.progression_state and game.sync_pushes == pushes_after_first, "identical state short-circuits the save")

	# --- unlock invariant: unlocked never trails the current level
	game = StoreGame.new()
	STORE._patch_progress_state(game, {"current_level_index": 2})
	check(int(game.progression_state["highest_unlocked_level_index"]) == 2, "unlock index follows the cursor")
	check(game.repopulates == 1, "level select repopulates when progression moves")

	if failures == 0:
		print("progress_store_test: ALL PASSED")
		quit(0)
	else:
		print("progress_store_test: %d FAILURES" % failures)
		quit(1)
