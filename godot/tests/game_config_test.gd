extends SceneTree

# Unit tests for scripts/session/game_config.gd — JSON edge cases, tuning
# defaults merge and empty-config fallbacks, driven through a fake game.

const CONFIG = preload("res://scripts/session/game_config.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame:
	const CAMPAIGN_PATH = "res://data/campaign.json"
	const TUNING_PATH = "res://data/tuning.json"
	const ICON_SETS_PATH = "res://data/icon_sets.json"
	const GAME_MODES_PATH = "res://data/game_modes.json"
	var campaign_levels = []
	var tuning = {}
	var icon_sets = []
	var game_mode_configs = {}
	func _load_json_file(path):
		return CONFIG._load_json_file(self, path)
	func _default_campaign_levels():
		return [{"id": 1, "rows": 6, "cols": 6}]
	func _default_icon_sets():
		return [{"id": "sentinel", "icons": ["X"]}]
	func _default_tuning():
		return {
			"base_score": 10,
			"max_combo": 8,
			"time_danger_seconds": 10,
		}

func _init() -> void:
	print("== game_config_test")

	# --- _load_json_file edge cases
	var game = FakeGame.new()
	check(typeof(game._load_json_file(FakeGame.TUNING_PATH)) == TYPE_DICTIONARY, "a real data file parses to a dictionary")
	check(game._load_json_file("res://data/definitely-missing.json") == null, "a missing file parses as null")

	# --- tuning: user config overrides defaults, defaults fill the gaps
	var tuning = CONFIG._load_tuning(game)
	check(int(tuning["max_combo"]) == 8, "defaults survive when the config omits them")
	check(tuning.has("base_score"), "defaults merge into the loaded config")

	# --- empty campaign / icon sets fall back to defaults
	game.campaign_levels = CONFIG._load_campaign_levels(game)
	check(not game.campaign_levels.empty(), "the shipped campaign table loads")
	var empty_config_game = EmptyCampaignGame.new()
	CONFIG._load_config(empty_config_game)
	check(empty_config_game.campaign_levels == [{"id": 1, "rows": 6, "cols": 6}], "an empty campaign falls back to defaults")
	check(empty_config_game.icon_sets == [{"id": "sentinel", "icons": ["X"]}], "empty icon sets fall back to defaults")

	# --- game mode configs normalize whatever the file held
	var mode_configs = CONFIG._load_game_mode_configs(game)
	check(typeof(mode_configs) == TYPE_DICTIONARY, "game mode configs normalize to a dictionary")

	if failures == 0:
		print("game_config_test: ALL PASSED")
		quit(0)
	else:
		print("game_config_test: %d FAILURES" % failures)
		quit(1)

class EmptyCampaignGame extends FakeGame:
	func _load_campaign_levels():
		return []
	func _load_icon_sets():
		return []
	func _load_tuning():
		return {"base_score": 99}
	func _load_game_mode_configs():
		return {}
