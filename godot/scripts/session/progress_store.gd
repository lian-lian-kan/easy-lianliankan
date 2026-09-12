extends Reference

const MISSIONS = preload("res://scripts/session/missions.gd")

# Progression persistence: load/save/patch of the progression state file.
# Special sessions never persist campaign progress fields.

static func _load_progress_state(game):
	var raw = null
	var file = File.new()
	if file.file_exists(game.PROGRESS_SAVE_PATH):
		var err = file.open(game.PROGRESS_SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			if content.strip_edges() != "":
				raw = parse_json(content)
			file.close()
	game.progression_state = game.PROGRESSION_SCRIPT.normalize_progress(raw, game.campaign_levels.size())

static func _save_progress_state(game):
	var normalized = game.PROGRESSION_SCRIPT.normalize_progress(game.progression_state, game.campaign_levels.size())
	var file = File.new()
	var err = file.open(game.PROGRESS_SAVE_PATH, File.WRITE)
	if err != OK:
		return
	file.store_string(to_json(normalized))
	file.close()
	game.progression_state = normalized

static func _patch_progress_state(game, patch):
	# Special sessions only persist their own records, never campaign progress
	# or the campaign best-score/combo candidates.
	if game._is_special_session():
		var filtered = patch.duplicate()
		filtered.erase("score_candidate")
		filtered.erase("combo_candidate")
		filtered.erase("current_level_index")
		filtered.erase("highest_unlocked_level_index")
		if filtered.empty():
			return
		patch = filtered
	# Every blossom INCOME flows through here (clears, sign-in, collection,
	# mission rewards), so this is the single missions hook for coins_100.
	# The nested record() patch carries no coins_delta — no recursion.
	if int(patch.get("coins_delta", 0)) > 0:
		MISSIONS.record(game, "coins_100", int(patch["coins_delta"]))
	var prev_current = int(game.progression_state.get("current_level_index", 0))
	var prev_unlocked = int(game.progression_state.get("highest_unlocked_level_index", 0))
	var next_state = game.PROGRESSION_SCRIPT.apply_update(game.progression_state, game.campaign_levels.size(), patch)
	if game.PROGRESSION_SCRIPT.same_progress(next_state, game.progression_state, game.campaign_levels.size()):
		game.progression_state = next_state
		return
	var next_current = int(next_state.get("current_level_index", prev_current))
	var next_unlocked = int(next_state.get("highest_unlocked_level_index", prev_unlocked))
	game.progression_state = next_state
	game._save_progress_state()
	if (next_current != prev_current or next_unlocked != prev_unlocked) and game.level_select_option != null:
		game._populate_level_select_options()

