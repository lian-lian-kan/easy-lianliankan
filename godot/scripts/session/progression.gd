extends Reference

const SAVE_VERSION = 1

const SPECIAL_MODES = preload("res://scripts/modes/special_modes.gd")
const ACHIEVEMENTS_SCRIPT = preload("res://scripts/session/achievements.gd")

# ── achievements (catalog + accessors live in session/achievements.gd;
# these shells keep the historical PROGRESSION_SCRIPT call sites stable) ──

static func has_achievement(state, achievement_id: String) :
	return ACHIEVEMENTS_SCRIPT.has_achievement(state, achievement_id)


static func unlock_achievement(state: Dictionary, achievement_id: String) :
	return ACHIEVEMENTS_SCRIPT.unlock_achievement(state, achievement_id)


static func get_achievement_info(achievement_id: String) :
	return ACHIEVEMENTS_SCRIPT.get_achievement_info(achievement_id)


static func get_unlocked_achievements(state) :
	return ACHIEVEMENTS_SCRIPT.get_unlocked_achievements(state)


static func get_all_achievements() :
	return ACHIEVEMENTS_SCRIPT.get_all_achievements()


static func get_achievement_definitions() :
	return ACHIEVEMENTS_SCRIPT.get_achievement_definitions()


# Flat per-mode best-score keys: the single source of truth shared by
# default_progress, _normalize_special_records and same_progress, so a new
# mode is one row here instead of three copy-pasted blocks. The nested
# records (daily_challenge / endless_best) keep their explicit handling.
const FLAT_BEST_KEYS = [
	"time_attack_best_score", "memory_best_score", "frost_best_score",
	"zen_best_score", "hell_best_score", "moves_best_score",
	"race_best_score", "stack_best_score", "gravity_best_score",
	"fog_best_score", "chain_best_score", "tray_best_score",
	"collect_best_score", "flip_best_score", "fever_best_score",
	"perfect_best_score", "rock_best_score", "defuse_best_score",
	"target_best_score", "shift_best_score", "slide_best_score",
	"defense_best_score", "sum10_best_score", "duel_best_score",
]

static func default_progress(level_count: int) :
	var state = {
		"version": SAVE_VERSION,
		"current_level_index": 0,
		"highest_unlocked_level_index": 0,
		"best_total_score": 0,
		"best_combo": 0,
		"achievements": [],
		"onboarding_seen": false,
		"level_best_times": {},  # Level index -> best time in seconds
		"level_stars": {},  # Level index -> best star rating (1..3)
		"daily_challenge": {"last_date": "", "streak": 0, "best_streak": 0, "best_score": 0},
		"endless_best": {"round": 0, "score": 0},
		"coins": 0,
		"collected": [],
		"owned_sets": ["fruit"],
		"owned_themes": ["sakura"],
		"current_theme": "sakura",
		"signin_streak": 0,
		"last_signin": "",
		"weekly_missions": {"week_key": "", "progress": {}, "claimed": []}
	}
	for key in FLAT_BEST_KEYS:
		state[key] = 0
	return state


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
	_normalize_meta_economy(raw, normalized)
	_normalize_missions(raw, normalized)
	_normalize_level_history(raw, normalized)
	_normalize_special_records(raw, normalized)

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


# Meta-economy: coins / collection / themes / sign-in.
static func _normalize_meta_economy(raw, normalized):
	if typeof(raw) != TYPE_DICTIONARY:
		return
	# Load meta-economy state (coins / collection / themes / sign-in)
	normalized["coins"] = max(0, int(raw.get("coins", 0)))
	var raw_collected = raw.get("collected", [])
	if typeof(raw_collected) == TYPE_ARRAY:
		normalized["collected"] = raw_collected.duplicate()
	var raw_owned_sets = raw.get("owned_sets", [])
	if typeof(raw_owned_sets) == TYPE_ARRAY and raw_owned_sets.size() > 0:
		normalized["owned_sets"] = raw_owned_sets.duplicate()
	var raw_owned_themes = raw.get("owned_themes", [])
	if typeof(raw_owned_themes) == TYPE_ARRAY and raw_owned_themes.size() > 0:
		normalized["owned_themes"] = raw_owned_themes.duplicate()
	normalized["current_theme"] = str(raw.get("current_theme", "sakura"))
	normalized["signin_streak"] = max(0, int(raw.get("signin_streak", 0)))
	normalized["last_signin"] = str(raw.get("last_signin", ""))


# Rolling-week missions blob (missions.gd owns its semantics).
static func _normalize_missions(raw, normalized):
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var raw_missions = raw.get("weekly_missions", {})
	if typeof(raw_missions) == TYPE_DICTIONARY:
		var mission_progress = raw_missions.get("progress", {})
		var mission_claimed = raw_missions.get("claimed", [])
		normalized["weekly_missions"] = {
			"week_key": str(raw_missions.get("week_key", "")),
			"progress": mission_progress.duplicate() if typeof(mission_progress) == TYPE_DICTIONARY else {},
			"claimed": mission_claimed.duplicate() if typeof(mission_claimed) == TYPE_ARRAY else []
		}


# Per-level best times and stars.
static func _normalize_level_history(raw, normalized):
	if typeof(raw) != TYPE_DICTIONARY:
		return
	# Load level best times
	var raw_best_times = raw.get("level_best_times", {})
	if typeof(raw_best_times) == TYPE_DICTIONARY:
		normalized["level_best_times"] = raw_best_times.duplicate()
	var raw_level_stars = raw.get("level_stars", {})
	if typeof(raw_level_stars) == TYPE_DICTIONARY:
		normalized["level_stars"] = raw_level_stars.duplicate()


# Special mode records: nested daily/endless plus flat best scores.
static func _normalize_special_records(raw, normalized):
	if typeof(raw) != TYPE_DICTIONARY:
		return
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
	for key in FLAT_BEST_KEYS:
		normalized[key] = max(0, int(raw.get(key, 0)))


static func apply_update(current_state, level_count: int, patch: Dictionary = {}) :
	var max_level_index = max(0, level_count - 1)
	var next_state = normalize_progress(current_state, level_count)

	_apply_level_progress(next_state, patch, max_level_index)
	if patch.has("score_candidate"):
		next_state["best_total_score"] = max(int(next_state["best_total_score"]), max(0, int(patch["score_candidate"])))
	if patch.has("combo_candidate"):
		next_state["best_combo"] = max(int(next_state["best_combo"]), max(0, int(patch["combo_candidate"])))
	if patch.has("onboarding_seen"):
		next_state["onboarding_seen"] = bool(patch["onboarding_seen"])
	_apply_meta_economy(next_state, patch)
	_apply_level_records(next_state, patch)
	_apply_special_records(next_state, patch)
	# Weekly missions: missions.gd owns the rolling-week logic and hands us
	# a complete, already-consistent dictionary to persist.
	if patch.has("weekly_missions"):
		var patch_missions = patch["weekly_missions"]
		if typeof(patch_missions) == TYPE_DICTIONARY and patch_missions.has("week_key"):
			next_state["weekly_missions"] = patch_missions.duplicate(true)
	next_state["version"] = SAVE_VERSION
	return next_state


# Campaign level index/unlock bookkeeping with its consistency invariant.
static func _apply_level_progress(next_state, patch, max_level_index):
	if patch.has("current_level_index"):
		next_state["current_level_index"] = clamp(int(patch["current_level_index"]), 0, max_level_index)
	if patch.has("highest_unlocked_level_index"):
		next_state["highest_unlocked_level_index"] = clamp(int(patch["highest_unlocked_level_index"]), 0, max_level_index)

	if int(next_state["highest_unlocked_level_index"]) < int(next_state["current_level_index"]):
		next_state["highest_unlocked_level_index"] = int(next_state["current_level_index"])


# Meta-economy: coin deltas, collection entries, theme unlocks, sign-in.
static func _apply_meta_economy(next_state, patch):
	# Meta-economy: coin deltas, collection entries, theme unlocks, sign-in.
	if patch.has("coins_delta"):
		next_state["coins"] = max(0, int(next_state["coins"]) + int(patch["coins_delta"]))
	if patch.has("collect"):
		var collected_id = str(patch["collect"])
		if not next_state["collected"].has(collected_id):
			next_state["collected"].append(collected_id)
	if patch.has("collect_many"):
		var collected_ids = patch["collect_many"]
		if typeof(collected_ids) == TYPE_ARRAY:
			for collected_entry in collected_ids:
				var collected_key = str(collected_entry)
				if not next_state["collected"].has(collected_key):
					next_state["collected"].append(collected_key)
	if patch.has("unlock_set"):
		var set_id = str(patch["unlock_set"])
		if not next_state["owned_sets"].has(set_id):
			next_state["owned_sets"].append(set_id)
	if patch.has("unlock_theme"):
		var theme_id = str(patch["unlock_theme"])
		if not next_state["owned_themes"].has(theme_id):
			next_state["owned_themes"].append(theme_id)
	if patch.has("current_theme"):
		next_state["current_theme"] = str(patch["current_theme"])
	if patch.has("signin"):
		var sign_in = patch["signin"]
		if typeof(sign_in) == TYPE_DICTIONARY and sign_in.has("date") and sign_in.has("yesterday"):
			var sign_date = str(sign_in["date"])
			var sign_yesterday = str(sign_in["yesterday"])
			if str(next_state["last_signin"]) != sign_date:
				var sign_streak = SPECIAL_MODES.next_daily_streak(
					str(next_state["last_signin"]), sign_date, sign_yesterday,
					int(next_state["signin_streak"]))
				next_state["last_signin"] = sign_date
				next_state["signin_streak"] = sign_streak


# Per-level best time and star rating.
static func _apply_level_records(next_state, patch):
	# Update level best times if provided
	if patch.has("level_best_time"):
		var time_data = patch["level_best_time"]
		if typeof(time_data) == TYPE_DICTIONARY and time_data.has("level_index") and time_data.has("time"):
			var level_idx = str(time_data["level_index"])
			var new_time = float(time_data["time"])
			var current_best = float(next_state["level_best_times"].get(level_idx, 999999.0))
			if new_time < current_best:
				next_state["level_best_times"][level_idx] = new_time

	# Star ratings: keep the best rating per level index.
	if patch.has("stars"):
		var star_data = patch["stars"]
		if typeof(star_data) == TYPE_DICTIONARY and star_data.has("level_index") and star_data.has("stars"):
			var star_key = str(star_data["level_index"])
			var prev_stars = int(next_state["level_stars"].get(star_key, 0))
			next_state["level_stars"][star_key] = max(prev_stars, max(1, min(3, int(star_data["stars"]))))


# Special mode records: daily streak bridging, endless rounds, per-mode bests.
static func _apply_special_records(next_state, patch):
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
	# Per-mode best scores: <mode>_result -> RECORD_MODES[mode].best_key
	# (mode_meta_test enforces the key convention); time_attack predates
	# the table so it is spelled out.
	for mode_id in SPECIAL_MODES.RECORD_MODES:
		var result_key = str(mode_id) + "_result"
		if patch.has(result_key):
			var best_key = str(SPECIAL_MODES.RECORD_MODES[mode_id]["best_key"])
			next_state[best_key] = max(int(next_state[best_key]), max(0, int(patch[result_key])))
	if patch.has("time_attack_result"):
		next_state["time_attack_best_score"] = max(int(next_state["time_attack_best_score"]), max(0, int(patch["time_attack_result"])))

static func same_progress(a, b, level_count: int) :
	var aa = normalize_progress(a, level_count)
	var bb = normalize_progress(b, level_count)
	# Flat per-mode bests plus the scalar fields, compared key by key.
	for key in FLAT_BEST_KEYS:
		if int(aa.get(key, 0)) != int(bb.get(key, 0)):
			return false
	for key in ["current_level_index", "highest_unlocked_level_index",
			"best_total_score", "best_combo", "coins", "signin_streak"]:
		if int(aa.get(key, 0)) != int(bb.get(key, 0)):
			return false
	if bool(aa.get("onboarding_seen", false)) != bool(bb.get("onboarding_seen", false)):
		return false
	if str(aa.get("current_theme", "")) != str(bb.get("current_theme", "")) \
			or str(aa.get("last_signin", "")) != str(bb.get("last_signin", "")):
		return false
	for key in ["achievements", "collected", "owned_sets", "owned_themes"]:
		if not _arrays_equal(aa.get(key, []), bb.get(key, [])):
			return false
	for key in ["daily_challenge", "endless_best", "level_stars"]:
		if not _dicts_equal(aa.get(key, {}), bb.get(key, {})):
			return false
	return _missions_equal(aa.get("weekly_missions", {}), bb.get("weekly_missions", {}))


static func _dicts_equal(a: Dictionary, b: Dictionary) :
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key) or a[key] != b[key]:
			return false
	return true


# weekly_missions nests containers (progress dict / claimed array); GDScript 3
# compares those by reference with ==, so equality needs per-element walks.
static func _missions_equal(a: Dictionary, b: Dictionary) :
	if str(a.get("week_key", "")) != str(b.get("week_key", "")):
		return false
	var mission_progress_a = a.get("progress", {})
	var mission_progress_b = b.get("progress", {})
	if mission_progress_a.size() != mission_progress_b.size():
		return false
	for task_id in mission_progress_a.keys():
		if not mission_progress_b.has(task_id) or int(mission_progress_a[task_id]) != int(mission_progress_b[task_id]):
			return false
	return _arrays_equal(a.get("claimed", []), b.get("claimed", []))


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

# Best-score/combo accessors over a (normalized) progress state.
static func best_score(state) -> int:
	return int(state.get("best_total_score", 0))

static func best_combo(state) -> int:
	return int(state.get("best_combo", 0))

static func clear_unlocked_ids(state, context) -> Array:
	# Campaign-clear achievement rules (pure): which ids would this clear unlock.
	var ids := []
	if int(context.get("level_index", 0)) == 0 and not has_achievement(state, "first_clear"):
		ids.append("first_clear")
	var combo := int(context.get("combo", 0))
	if combo >= 3 and not has_achievement(state, "combo_novice"):
		ids.append("combo_novice")
	if combo >= 10 and not has_achievement(state, "combo_master"):
		ids.append("combo_master")
	if float(context.get("clear_time", 999999.0)) <= 30.0 and not has_achievement(state, "speed_star"):
		ids.append("speed_star")
	if int(context.get("hints_used", 0)) == 0 and int(context.get("auto_used", 0)) == 0 and not has_achievement(state, "perfect_clear"):
		ids.append("perfect_clear")
	if int(context.get("level_index", 0)) >= int(context.get("level_count", 1)) - 1 and not has_achievement(state, "completionist"):
		ids.append("completionist")
	return ids
