extends Node

# Theme Manager - Handles theme unlocking and selection
# Godot 3.5 compatible

const SAVE_PATH = "user://theme_data.json"
const ICON_SETS_PATH = "res://data/icon_sets.json"

var unlocked_themes = ["fruit"]  # Default unlocked theme
var current_theme = "fruit"
var all_themes = []

func _ready():
	_load_theme_data()
	_load_all_themes()

func _load_all_themes():
	var file = File.new()
	if file.file_exists(ICON_SETS_PATH):
		var err = file.open(ICON_SETS_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				all_themes = data.get("sets", [])
			file.close()

func _load_theme_data():
	var file = File.new()
	if file.file_exists(SAVE_PATH):
		var err = file.open(SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				unlocked_themes = data.get("unlocked", ["fruit"])
				current_theme = data.get("current", "fruit")
			file.close()

func _save_theme_data():
	var file = File.new()
	var err = file.open(SAVE_PATH, File.WRITE)
	if err == OK:
		var data = {
			"unlocked": unlocked_themes,
			"current": current_theme
		}
		file.store_string(to_json(data))
		file.close()

# Public API

func get_all_themes():
	return all_themes

func get_unlocked_themes():
	return unlocked_themes

func get_current_theme():
	return current_theme

func set_current_theme(theme_id):
	if theme_id in unlocked_themes:
		current_theme = theme_id
		_save_theme_data()
		return true
	return false

func is_theme_unlocked(theme_id):
	return theme_id in unlocked_themes

func unlock_theme(theme_id):
	if not theme_id in unlocked_themes:
		unlocked_themes.append(theme_id)
		_save_theme_data()
		return true
	return false

func unlock_random_theme():
	var locked_themes = []
	for theme in all_themes:
		var id = theme.get("id", "")
		if id != "" and not id in unlocked_themes:
			locked_themes.append(id)

	if locked_themes.size() > 0:
		var random_index = randi() % locked_themes.size()
		return unlock_theme(locked_themes[random_index])
	return false

func get_theme_by_id(theme_id):
	for theme in all_themes:
		if theme.get("id", "") == theme_id:
			return theme
	return null

func get_current_theme_data():
	return get_theme_by_id(current_theme)

func get_theme_name(theme_id):
	var theme = get_theme_by_id(theme_id)
	if theme != null:
		return theme.get("name", theme_id)
	return theme_id

func get_theme_icon(theme_id):
	var theme = get_theme_by_id(theme_id)
	if theme != null:
		var icons = theme.get("icons", [])
		if icons.size() > 0:
			return icons[0]
	return "🎨"

func get_unlock_progress():
	var total = all_themes.size()
	if total == 0:
		return {"unlocked": 0, "total": 0, "percent": 0}
	var unlocked = unlocked_themes.size()
	return {
		"unlocked": unlocked,
		"total": total,
		"percent": int(float(unlocked) / float(total) * 100)
	}
