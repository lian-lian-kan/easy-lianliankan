extends Node

# Leaderboard Manager - Handles rankings and scores
# Godot 3.5 compatible

const SAVE_PATH = "user://leaderboard_data.json"

# Local leaderboard data (for now, could be expanded to online)
var local_scores = {
	"total_score": [],
	"level_times": {},
	"endless_depth": []
}

var player_best = {
	"total_score": 0,
	"best_combo": 0,
	"endless_level": 0
}

func _ready():
	_load_data()

func _load_data():
	var file = File.new()
	if file.file_exists(SAVE_PATH):
		var err = file.open(SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				local_scores = data.get("scores", local_scores)
				player_best = data.get("best", player_best)
			file.close()

func _save_data():
	var file = File.new()
	var err = file.open(SAVE_PATH, File.WRITE)
	if err == OK:
		var data = {
			"scores": local_scores,
			"best": player_best
		}
		file.store_string(to_json(data))
		file.close()

# Public API - Total Score

func submit_score(player_name, score, level_reached):
	if score > player_best.total_score:
		player_best.total_score = score

	var entry = {
		"name": player_name,
		"score": score,
		"level": level_reached,
		"date": _get_current_date()
	}

	local_scores.total_score.append(entry)
	_sort_scores("total_score")
	_trim_scores("total_score", 100)  # Keep top 100
	_save_data()

func get_top_scores(limit = 10):
	_sort_scores("total_score")
	return local_scores.total_score.slice(0, min(limit, local_scores.total_score.size()))

func get_player_rank(player_name):
	_sort_scores("total_score")
	for i in range(local_scores.total_score.size()):
		if local_scores.total_score[i].name == player_name:
			return i + 1
	return -1

func get_best_score():
	return player_best.total_score

# Public API - Level Times

func submit_level_time(level_id, time_seconds):
	if not local_scores.level_times.has(level_id):
		local_scores.level_times[level_id] = []

	var entry = {
		"time": time_seconds,
		"date": _get_current_date()
	}

	local_scores.level_times[level_id].append(entry)
	_sort_level_times(level_id)
	_trim_level_times(level_id, 50)
	_save_data()

func get_level_best_time(level_id):
	if not local_scores.level_times.has(level_id):
		return -1

	var times = local_scores.level_times[level_id]
	if times.size() == 0:
		return -1

	return times[0].time

func get_level_top_times(level_id, limit = 10):
	if not local_scores.level_times.has(level_id):
		return []

	_sort_level_times(level_id)
	return local_scores.level_times[level_id].slice(0, min(limit, local_scores.level_times[level_id].size()))

# Public API - Endless Mode

func submit_endless_depth(depth, score):
	if depth > player_best.endless_level:
		player_best.endless_level = depth

	var entry = {
		"depth": depth,
		"score": score,
		"date": _get_current_date()
	}

	local_scores.endless_depth.append(entry)
	_sort_endless_depth()
	_trim_scores("endless_depth", 100)
	_save_data()

func get_endless_best_depth():
	return player_best.endless_level

func get_endless_top_depths(limit = 10):
	_sort_endless_depth()
	return local_scores.endless_depth.slice(0, min(limit, local_scores.endless_depth.size()))

# Public API - Combo

func update_best_combo(combo):
	if combo > player_best.best_combo:
		player_best.best_combo = combo
		_save_data()
		return true
	return false

func get_best_combo():
	return player_best.best_combo

# Helper functions

func _sort_scores(category):
	if not local_scores.has(category):
		return

	# Sort by score descending
	local_scores[category].sort_custom(self, "_compare_scores")

func _compare_scores(a, b):
	if a.score > b.score:
		return true
	return false

func _sort_level_times(level_id):
	if not local_scores.level_times.has(level_id):
		return

	# Sort by time ascending (lower is better)
	local_scores.level_times[level_id].sort_custom(self, "_compare_times")

func _compare_times(a, b):
	if a.time < b.time:
		return true
	return false

func _sort_endless_depth():
	# Sort by depth descending, then by score descending
	local_scores.endless_depth.sort_custom(self, "_compare_depths")

func _compare_depths(a, b):
	if a.depth > b.depth:
		return true
	if a.depth == b.depth and a.score > b.score:
		return true
	return false

func _trim_scores(category, max_size):
	if not local_scores.has(category):
		return
	if local_scores[category].size() > max_size:
		local_scores[category].resize(max_size)

func _trim_level_times(level_id, max_size):
	if not local_scores.level_times.has(level_id):
		return
	if local_scores.level_times[level_id].size() > max_size:
		local_scores.level_times[level_id].resize(max_size)

func _get_current_date():
	var datetime = OS.get_datetime()
	return str(datetime.year) + "-" + str(datetime.month) + "-" + str(datetime.day)

# Format time for display
func format_time(seconds):
	var mins = int(seconds / 60)
	var secs = int(seconds) % 60
	return str(mins) + ":" + str(secs).pad_zeros(2)

func format_time_ms(ms):
	return format_time(float(ms) / 1000.0)
