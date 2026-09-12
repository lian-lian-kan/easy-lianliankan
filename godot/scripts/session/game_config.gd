extends Reference

# Config loading: JSON overrides with in-code defaults for the campaign
# table, tuning, icon sets and game-mode configs. Statics take the live game
# node so results land straight on its members.

static func _load_config(game):
	game.campaign_levels = game._load_campaign_levels()
	game.tuning = game._load_tuning()
	game.icon_sets = game._load_icon_sets()
	game.game_mode_configs = game._load_game_mode_configs()

	if game.campaign_levels.empty():
		game.campaign_levels = game._default_campaign_levels()
	if game.icon_sets.empty():
		game.icon_sets = game._default_icon_sets()

static func _load_json_file(game, path: String):
	var file = File.new()
	if not file.file_exists(path):
		return null
	var err = file.open(path, File.READ)
	if err != OK:
		return null
	var content = file.get_as_text()
	file.close()
	if content.strip_edges() == "":
		return null
	var parsed = parse_json(content)
	return parsed

static func _load_campaign_levels(game):
	var root = game._load_json_file(game.CAMPAIGN_PATH)
	if typeof(root) != TYPE_DICTIONARY:
		return []
	var levels: Array = root.get("levels", [])
	return levels

static func _load_tuning(game):
	var root = game._load_json_file(game.TUNING_PATH)
	if typeof(root) != TYPE_DICTIONARY:
		return game._default_tuning()
	var defaults = game._default_tuning()
	for key in defaults.keys():
		if not root.has(key):
			root[key] = defaults[key]
	return root

static func _load_icon_sets(game):
	var root = game._load_json_file(game.ICON_SETS_PATH)
	if typeof(root) != TYPE_DICTIONARY:
		return []
	return root.get("sets", [])

static func _load_game_mode_configs(game):
	return game.SPECIAL_MODES_SCRIPT.normalize_configs(game._load_json_file(game.GAME_MODES_PATH))

static func _default_tuning(game):
	return {
		"base_score": 10,
		"message_timeout_ms": 1000,
		"path_preview_ms": 420,
		"hint_preview_ms": 1400,
		"error_flash_ms": 420,
		"combo_window_ms": 2600,
		"max_combo": 8,
		"combo_burst_ms": 820,
		"level_advance_ms": 1200,
		"time_danger_seconds": 10,
		"hint_time_cost_seconds": 1,
		"auto_eliminate_time_cost_seconds": 2,
		"shuffle_time_cost_seconds": 1
	}

static func _default_icon_sets(game):
	return [
		{
			"id": "fruit",
			"name": "水果",
			"icons": ["🍎", "🍊", "🍌", "🍇", "🍓", "🥝", "🍑", "🍒", "🥭", "🍍", "🥥", "🍉"],
			"colors": ["#fef2f2", "#fff7ed", "#fefce8", "#eff6ff", "#fdf2f8", "#f0fdf4", "#fff1f2", "#fef2f2", "#fffbeb", "#ecfdf5", "#f8fafc", "#f0f9ff"]
		}
	]

