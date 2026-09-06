extends Reference

const SAVE_VERSION = 1

const SPECIAL_MODES = preload("res://scripts/special_modes.gd")

# Achievement definitions
const ACHIEVEMENTS = [
	{"id": "first_clear", "name": "初次通关", "desc": "完成第1关"},
	{"id": "combo_novice", "name": "连击新手", "desc": "达成3连击"},
	{"id": "combo_master", "name": "连击大师", "desc": "达成10连击"},
	{"id": "speed_star", "name": "速度之星", "desc": "在30秒内完成一关"},
	{"id": "perfect_clear", "name": "完美通关", "desc": "不使用提示和自动消除完成一关"},
	{"id": "completionist", "name": "通关达人", "desc": "完成所有关卡"},
	{"id": "memory_first", "name": "盲盒初体验", "desc": "完成一局盲盒模式"},
	{"id": "daily_streak_7", "name": "七日之约", "desc": "每日挑战连胜达到7天"},
	{"id": "endless_round_5", "name": "无尽探索者", "desc": "无尽模式达到第5轮"},
	{"id": "time_attack_1000", "name": "限时高手", "desc": "限时挑战得分达到1000"},
	{"id": "frost_first", "name": "冰雪初融", "desc": "完成一局冰雪挑战"},
	{"id": "frost_no_power", "name": "寒冰骑士", "desc": "不使用暖宝宝完成一局冰雪挑战"},
	{"id": "zen_first", "name": "闲云野鹤", "desc": "完成一局休闲模式"},
	{"id": "hell_first", "name": "地狱行者", "desc": "通关一次地狱模式"},
	{"id": "moves_first", "name": "精打细算", "desc": "完成一局步数挑战"},
	{"id": "moves_saver", "name": "节步大师", "desc": "步数挑战中保留20%以上步数通关"},
	{"id": "race_first", "name": "初胜机器人", "desc": "竞速对战中击败机器人"},
	{"id": "stack_first", "name": "叠层达人", "desc": "完成一局叠层模式"},
	{"id": "gravity_first", "name": "引力达人", "desc": "完成一局重力模式"},
	{"id": "fog_first", "name": "拨云见日", "desc": "完成一局迷雾模式"},
	{"id": "chain_first", "name": "斩断锁链", "desc": "完成一局锁链模式"}
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
		"level_best_times": {},  # Level index -> best time in seconds
		"daily_challenge": {"last_date": "", "streak": 0, "best_streak": 0, "best_score": 0},
		"endless_best": {"round": 0, "score": 0},
		"time_attack_best_score": 0,
		"memory_best_score": 0,
		"frost_best_score": 0,
		"zen_best_score": 0,
		"hell_best_score": 0,
		"moves_best_score": 0,
		"race_best_score": 0,
		"stack_best_score": 0,
		"gravity_best_score": 0,
		"fog_best_score": 0,
		"chain_best_score": 0
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
		# Load special mode records
		var raw_daily = raw.get("daily_challenge", {})
		if typeof(raw_daily) == TYPE_DICTIONARY:
			normalized["daily_challenge"] = {
				"last_date": str(raw_daily.get("last_date", "")),
				"streak": max(0, int(raw_daily.get("streak", 0))),
				"best_streak": max(0, int(raw_daily.get("best_streak", 0))),
				"best_score": max(0, int(raw_daily.get("best_score", 0)))
			}
		var raw_endless = raw.get("endless_best", {})
		if typeof(raw_endless) == TYPE_DICTIONARY:
			normalized["endless_best"] = {
				"round": max(0, int(raw_endless.get("round", 0))),
				"score": max(0, int(raw_endless.get("score", 0)))
			}
		normalized["time_attack_best_score"] = max(0, int(raw.get("time_attack_best_score", 0)))
		normalized["memory_best_score"] = max(0, int(raw.get("memory_best_score", 0)))
		normalized["frost_best_score"] = max(0, int(raw.get("frost_best_score", 0)))
		normalized["zen_best_score"] = max(0, int(raw.get("zen_best_score", 0)))
		normalized["hell_best_score"] = max(0, int(raw.get("hell_best_score", 0)))
		normalized["moves_best_score"] = max(0, int(raw.get("moves_best_score", 0)))
		normalized["race_best_score"] = max(0, int(raw.get("race_best_score", 0)))
		normalized["stack_best_score"] = max(0, int(raw.get("stack_best_score", 0)))
		normalized["gravity_best_score"] = max(0, int(raw.get("gravity_best_score", 0)))
		normalized["fog_best_score"] = max(0, int(raw.get("fog_best_score", 0)))
		normalized["chain_best_score"] = max(0, int(raw.get("chain_best_score", 0)))

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

	# Special mode records. A daily result carries the date context so the
	# streak can bridge month/year boundaries correctly.
	if patch.has("daily_result"):
		var daily = patch["daily_result"]
		if typeof(daily) == TYPE_DICTIONARY and daily.has("date") and daily.has("yesterday"):
			var date = str(daily["date"])
			var yesterday = str(daily["yesterday"])
			var streak = SPECIAL_MODES.next_daily_streak(
				str(next_state["daily_challenge"]["last_date"]), date, yesterday,
				int(next_state["daily_challenge"]["streak"]))
			next_state["daily_challenge"]["last_date"] = date
			next_state["daily_challenge"]["streak"] = streak
			next_state["daily_challenge"]["best_streak"] = max(int(next_state["daily_challenge"]["best_streak"]), streak)
			next_state["daily_challenge"]["best_score"] = max(int(next_state["daily_challenge"]["best_score"]), max(0, int(daily.get("score", 0))))
	if patch.has("endless_result"):
		var endless = patch["endless_result"]
		if typeof(endless) == TYPE_DICTIONARY:
			next_state["endless_best"]["round"] = max(int(next_state["endless_best"]["round"]), max(0, int(endless.get("round", 0))))
			next_state["endless_best"]["score"] = max(int(next_state["endless_best"]["score"]), max(0, int(endless.get("score", 0))))
	if patch.has("time_attack_result"):
		next_state["time_attack_best_score"] = max(int(next_state["time_attack_best_score"]), max(0, int(patch["time_attack_result"])))
	if patch.has("memory_result"):
		next_state["memory_best_score"] = max(int(next_state["memory_best_score"]), max(0, int(patch["memory_result"])))
	if patch.has("frost_result"):
		next_state["frost_best_score"] = max(int(next_state["frost_best_score"]), max(0, int(patch["frost_result"])))
	if patch.has("zen_result"):
		next_state["zen_best_score"] = max(int(next_state["zen_best_score"]), max(0, int(patch["zen_result"])))
	if patch.has("hell_result"):
		next_state["hell_best_score"] = max(int(next_state["hell_best_score"]), max(0, int(patch["hell_result"])))
	if patch.has("moves_result"):
		next_state["moves_best_score"] = max(int(next_state["moves_best_score"]), max(0, int(patch["moves_result"])))
	if patch.has("race_result"):
		next_state["race_best_score"] = max(int(next_state["race_best_score"]), max(0, int(patch["race_result"])))
	if patch.has("stack_result"):
		next_state["stack_best_score"] = max(int(next_state["stack_best_score"]), max(0, int(patch["stack_result"])))
	if patch.has("gravity_result"):
		next_state["gravity_best_score"] = max(int(next_state["gravity_best_score"]), max(0, int(patch["gravity_result"])))
	if patch.has("fog_result"):
		next_state["fog_best_score"] = max(int(next_state["fog_best_score"]), max(0, int(patch["fog_result"])))
	if patch.has("chain_result"):
		next_state["chain_best_score"] = max(int(next_state["chain_best_score"]), max(0, int(patch["chain_result"])))

	next_state["version"] = SAVE_VERSION
	return next_state


static func same_progress(a, b, level_count: int) :
	var aa = normalize_progress(a, level_count)
	var bb = normalize_progress(b, level_count)
	return int(aa["current_level_index"]) == int(bb["current_level_index"]) \
		and int(aa["highest_unlocked_level_index"]) == int(bb["highest_unlocked_level_index"]) \
		and int(aa["best_total_score"]) == int(bb["best_total_score"]) \
		and int(aa["best_combo"]) == int(bb["best_combo"]) \
		and _arrays_equal(aa.get("achievements", []), bb.get("achievements", [])) \
		and _dicts_equal(aa.get("daily_challenge", {}), bb.get("daily_challenge", {})) \
		and _dicts_equal(aa.get("endless_best", {}), bb.get("endless_best", {})) \
		and int(aa.get("time_attack_best_score", 0)) == int(bb.get("time_attack_best_score", 0)) \
		and int(aa.get("memory_best_score", 0)) == int(bb.get("memory_best_score", 0)) \
		and int(aa.get("frost_best_score", 0)) == int(bb.get("frost_best_score", 0)) \
		and int(aa.get("zen_best_score", 0)) == int(bb.get("zen_best_score", 0)) \
		and int(aa.get("hell_best_score", 0)) == int(bb.get("hell_best_score", 0)) \
		and int(aa.get("moves_best_score", 0)) == int(bb.get("moves_best_score", 0)) \
		and int(aa.get("race_best_score", 0)) == int(bb.get("race_best_score", 0)) \
		and int(aa.get("stack_best_score", 0)) == int(bb.get("stack_best_score", 0)) \
		and int(aa.get("gravity_best_score", 0)) == int(bb.get("gravity_best_score", 0)) \
		and int(aa.get("fog_best_score", 0)) == int(bb.get("fog_best_score", 0)) \
		and int(aa.get("chain_best_score", 0)) == int(bb.get("chain_best_score", 0))


static func _dicts_equal(a: Dictionary, b: Dictionary) :
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key) or a[key] != b[key]:
			return false
	return true


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
