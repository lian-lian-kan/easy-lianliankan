extends Reference

const SAVE_VERSION = 1

# Achievement definitions
const ACHIEVEMENTS = [
	{"id": "first_clear", "name": "初次通关", "desc": "完成第1关"},
	{"id": "combo_novice", "name": "连击新手", "desc": "达成3连击"},
	{"id": "combo_master", "name": "连击大师", "desc": "达成10连击"},
	{"id": "speed_star", "name": "速度之星", "desc": "在30秒内完成一关"},
	{"id": "perfect_clear", "name": "完美通关", "desc": "不使用提示和自动消除完成一关"},
	{"id": "completionist", "name": "通关达人", "desc": "完成所有关卡"}
]


static func default_progress(level_count: int) :
	return {
		"version": SAVE_VERSION,
		"current_level_index": 0,
		"highest_unlocked_level_index": 0,
		"best_total_score": 0,
		"best_combo": 0,
		"achievements": [],
		"onboarding_seen": false,
		"level_best_times": {}  # Level index -> best time in seconds
	}


static func normalize_progress(raw, level_count: int) :
	var max_level_index = max(0, level_count - 1)
	var normalized = default_progress(level_count)
	if typeof(raw) == TYPE_DICTIONARY:
		normalized["current_level_index"] = int(raw.get("current_level_index", normalized["current_level_index"]))
		normalized["highest_unlocked_level_index"] = int(raw.get("highest_unlocked_level_index", normalized["highest_unlocked_level_index"]))
		normalized["best_total_score"] = int(raw.get("best_total_score", normalized["best_total_score"]))
		normalized["best_combo"] = int(raw.get("best_combo", normalized["best_combo"]))
		# Load achievements
		var raw_achievements = raw.get("achievements", [])
		if typeof(raw_achievements) == TYPE_ARRAY:
			normalized["achievements"] = raw_achievements.duplicate()
		# Load onboarding seen
		normalized["onboarding_seen"] = bool(raw.get("onboarding_seen", false))
		# Load level best times
		var raw_best_times = raw.get("level_best_times", {})
		if typeof(raw_best_times) == TYPE_DICTIONARY:
			normalized["level_best_times"] = raw_best_times.duplicate()

	normalized["current_level_index"] = clamp(int(normalized["current_level_index"]), 0, max_level_index)
	normalized["highest_unlocked_level_index"] = clamp(int(normalized["highest_unlocked_level_index"]), 0, max_level_index)
	normalized["best_total_score"] = max(0, int(normalized["best_total_score"]))
	normalized["best_combo"] = max(0, int(normalized["best_combo"]))
	if typeof(normalized["achievements"]) != TYPE_ARRAY:
		normalized["achievements"] = []
	if int(normalized["highest_unlocked_level_index"]) < int(normalized["current_level_index"]):
		normalized["highest_unlocked_level_index"] = int(normalized["current_level_index"])
	normalized["version"] = SAVE_VERSION
	return normalized


static func apply_update(current_state, level_count: int, patch: Dictionary = {}) :
	var max_level_index = max(0, level_count - 1)
	var next_state = normalize_progress(current_state, level_count)

	if patch.has("current_level_index"):
		next_state["current_level_index"] = clamp(int(patch["current_level_index"]), 0, max_level_index)
	if patch.has("highest_unlocked_level_index"):
		next_state["highest_unlocked_level_index"] = clamp(int(patch["highest_unlocked_level_index"]), 0, max_level_index)

	if int(next_state["highest_unlocked_level_index"]) < int(next_state["current_level_index"]):
		next_state["highest_unlocked_level_index"] = int(next_state["current_level_index"])

	if patch.has("score_candidate"):
		next_state["best_total_score"] = max(int(next_state["best_total_score"]), max(0, int(patch["score_candidate"])))
	if patch.has("combo_candidate"):
		next_state["best_combo"] = max(int(next_state["best_combo"]), max(0, int(patch["combo_candidate"])))
	# Update level best times if provided
	if patch.has("level_best_time"):
		var time_data = patch["level_best_time"]
		if typeof(time_data) == TYPE_DICTIONARY and time_data.has("level_index") and time_data.has("time"):
			var level_idx = str(time_data["level_index"])
			var new_time = float(time_data["time"])
			var current_best = float(next_state["level_best_times"].get(level_idx, 999999.0))
			if new_time < current_best:
				next_state["level_best_times"][level_idx] = new_time

	next_state["version"] = SAVE_VERSION
	return next_state


static func same_progress(a, b, level_count: int) :
	var aa = normalize_progress(a, level_count)
	var bb = normalize_progress(b, level_count)
	return int(aa["current_level_index"]) == int(bb["current_level_index"]) \
		and int(aa["highest_unlocked_level_index"]) == int(bb["highest_unlocked_level_index"]) \
		and int(aa["best_total_score"]) == int(bb["best_total_score"]) \
		and int(aa["best_combo"]) == int(bb["best_combo"]) \
		and _arrays_equal(aa.get("achievements", []), bb.get("achievements", []))


static func _arrays_equal(a: Array, b: Array) :
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


static func is_level_unlocked(state, level_index: int, level_count: int) :
	var normalized = normalize_progress(state, level_count)
	var target = clamp(level_index, 0, max(0, level_count - 1))
	return target <= int(normalized["highest_unlocked_level_index"])


static func find_next_unlocked(state, from_index: int, step: int, level_count: int) :
	var normalized = normalize_progress(state, level_count)
	var max_index = max(0, level_count - 1)
	if max_index <= 0:
		return 0
	var unlocked_max = int(normalized["highest_unlocked_level_index"])
	if unlocked_max <= 0:
		return 0
	var direction = -1 if step < 0 else 1
	var current = clamp(from_index, 0, max_index)
	for _i in range(level_count):
		current = wrapi(current + direction, 0, level_count)
		if current <= unlocked_max:
			return current
	return clamp(from_index, 0, unlocked_max)


# Achievement system functions

static func has_achievement(state, achievement_id: String) :
	var achievements = state.get("achievements", [])
	if typeof(achievements) != TYPE_ARRAY:
		return false
	return achievement_id in achievements


static func unlock_achievement(state: Dictionary, achievement_id: String) :
	if has_achievement(state, achievement_id):
		return state
	var achievements = state.get("achievements", [])
	if typeof(achievements) != TYPE_ARRAY:
		achievements = []
	achievements.append(achievement_id)
	state["achievements"] = achievements
	return state


static func get_achievement_info(achievement_id: String) :
	for achievement in ACHIEVEMENTS:
		if achievement["id"] == achievement_id:
			return achievement
	return {"id": "", "name": "", "desc": ""}


static func get_unlocked_achievements(state) :
	var achievements = state.get("achievements", [])
	if typeof(achievements) != TYPE_ARRAY:
		return []
	return achievements.duplicate()


static func get_all_achievements() :
	return ACHIEVEMENTS.duplicate()
