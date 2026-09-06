extends Reference

# Pure logic for the special game modes (daily challenge / time attack /
# endless). Kept free of scene-tree dependencies so it can run headless in
# tests; game.gd owns all presentation.

const DEFAULT_CONFIGS = {
	"time_attack": {
		"mode_id": "time_attack",
		"name": "限时挑战",
		"description": "与时间赛跑，消除得时间",
		"initial_time": 60,
		"time_bonus_per_match": 3,
		"combo_time_bonus": 1,
		"fever_mode_threshold": 5,
		"fever_multiplier": 1.5,
		"unlock_level": 5,
		"rows": 10,
		"cols": 8,
		"kinds": 8
	},
	"endless": {
		"mode_id": "endless",
		"name": "无尽模式",
		"description": "挑战极限，看你能走多远",
		"base_kinds": 6,
		"kinds_increment_every": 1,
		"board_expansion_every": 3,
		"max_rows": 16,
		"max_cols": 14,
		"max_kinds": 20,
		"unlock_level": 8,
		"base_rows": 10,
		"base_cols": 8
	},
	"daily": {
		"mode_id": "daily",
		"name": "每日挑战",
		"description": "每天一副棋盘，全网相同",
		"unlock_level": 1
	},
	"memory": {
		"mode_id": "memory",
		"name": "盲盒模式",
		"description": "先记忆，再盲配",
		"preview_seconds": 5.0,
		"face_up_duration": 1.0,
		"unlock_level": 10,
		"rows": 8,
		"cols": 8,
		"kinds": 8,
		"time_base": 60,
		"time_per_tile": 1.5
	},
	"frost": {
		"mode_id": "frost",
		"name": "冰雪挑战",
		"description": "冰冻方块要消除两次",
		"unlock_level": 13,
		"rows": 10,
		"cols": 8,
		"kinds": 9,
		"time_base": 110,
		"time_per_tile": 1.0,
		"frost_ratio": 0.3,
		"difficulty_tiers": [
			{"level_range": [1, 5], "frost_ratio": 0.22, "rows": 8, "cols": 8, "kinds": 8, "time_base": 110},
			{"level_range": [6, 10], "frost_ratio": 0.3, "rows": 10, "cols": 8, "kinds": 9, "time_base": 130},
			{"level_range": [11, 999], "frost_ratio": 0.38, "rows": 10, "cols": 9, "kinds": 11, "time_base": 150}
		]
	}
}


static func default_configs():
	var configs = {}
	for key in DEFAULT_CONFIGS.keys():
		configs[key] = DEFAULT_CONFIGS[key].duplicate()
	return configs


# Merge data/game_modes.json over the defaults so the JSON stays optional.
static func normalize_configs(raw):
	var configs = default_configs()
	if typeof(raw) == TYPE_DICTIONARY and raw.has("game_modes"):
		var modes = raw["game_modes"]
		if typeof(modes) == TYPE_DICTIONARY:
			for key in configs.keys():
				if modes.has(key) and typeof(modes[key]) == TYPE_DICTIONARY:
					for field in modes[key].keys():
						configs[key][field] = modes[key][field]
	return configs


static func date_string(date) :
	# date: OS.get_date() shape -> {year, month, day}
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]


static func yesterday_string(date) :
	# Walk back one day via the epoch so month/year boundaries stay correct.
	var d = {
		"year": int(date.year), "month": int(date.month), "day": int(date.day),
		"weekday": 0, "hour": 12, "minute": 0, "second": 0
	}
	var epoch = int(OS.get_unix_time_from_datetime(d)) - 86400
	return date_string(OS.get_datetime_from_unix_time(epoch))


# Streak rule for a completed daily: consecutive days extend the streak,
# a gap resets it to 1, and a same-day re-record keeps the stored streak.
static func next_daily_streak(last_date: String, today: String, yesterday: String, current_streak: int) :
	if last_date == today:
		return max(1, int(current_streak))
	if last_date == yesterday:
		return max(1, int(current_streak)) + 1
	return 1


# Deterministic per-day seed. Same day -> same board for every player.
static func seed_for_day(day: String) :
	return hash("lianliankan-daily-" + day)


static func build_daily_level(day: String) :
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_for_day(day)
	# Rows are always even so the board never leaves a leftover hole tile.
	var rows = [10, 12, 14][rng.randi() % 3]
	var cols = [8, 9][rng.randi() % 2]
	var kinds = 8 + rng.randi() % 5                # 8-12
	var time_limit = 150 + 10 * (rng.randi() % 4)  # 150-180s
	return {
		"id": 1,
		"name": day,
		"mode": "daily",
		"rows": rows,
		"cols": cols,
		"kinds": kinds,
		"time_limit": time_limit
	}


static func build_time_attack_level(config):
	return {
		"id": 1,
		"name": str(config.get("name", "限时挑战")),
		"mode": "time_attack",
		"rows": int(config.get("rows", 10)),
		"cols": int(config.get("cols", 8)),
		"kinds": int(config.get("kinds", 8)),
		"time_limit": int(config.get("initial_time", 60))
	}


static func build_endless_level(config, round_index: int):
	var rows = int(config.get("base_rows", 10))
	var cols = int(config.get("base_cols", 8))
	var kinds = int(config.get("base_kinds", 6))
	var expansion_every = max(1, int(config.get("board_expansion_every", 3)))
	var extra_rounds = max(0, round_index - 1)
	return {
		"id": 1,
		"name": "第" + str(round_index) + "轮",
		"mode": "endless",
		"rows": min(rows + 2 * int(extra_rounds / expansion_every), int(config.get("max_rows", 16))),
		"cols": min(cols + 2 * int(extra_rounds / expansion_every), int(config.get("max_cols", 14))),
		"kinds": min(kinds + extra_rounds * int(config.get("kinds_increment_every", 1)), int(config.get("max_kinds", 20))),
		"time_limit": 0,
		"round_index": round_index
	}


# Pick the memory difficulty tier whose level_range covers the player's
# campaign progress (1-based); falls back to the config defaults.
static func memory_tier(config, progress_level: int) -> Dictionary:
	var tiers = config.get("difficulty_tiers", [])
	if typeof(tiers) == TYPE_ARRAY:
		for tier in tiers:
			if typeof(tier) != TYPE_DICTIONARY or not tier.has("level_range"):
				continue
			var range_data = tier["level_range"]
			if typeof(range_data) != TYPE_ARRAY or range_data.size() < 2:
				continue
			if int(progress_level) >= int(range_data[0]) and int(progress_level) <= int(range_data[1]):
				return {
					"preview": float(tier.get("preview", config.get("preview_seconds", 5.0))),
					"face_up": float(tier.get("face_up", config.get("face_up_duration", 1.0)))
				}
	return {
		"preview": float(config.get("preview_seconds", 5.0)),
		"face_up": float(config.get("face_up_duration", 1.0))
	}


static func build_memory_level(config, tier: Dictionary):
	var rows = int(config.get("rows", 8))
	var cols = int(config.get("cols", 8))
	var kinds = int(config.get("kinds", 8))
	# Clock is generous: it only punishes dithering, not thinking.
	var time_limit = int(config.get("time_base", 60)) + int(rows * cols * float(config.get("time_per_tile", 1.5)))
	return {
		"id": 1,
		"name": str(config.get("name", "盲盒模式")),
		"mode": "memory",
		"rows": rows,
		"cols": cols,
		"kinds": kinds,
		"time_limit": time_limit,
		"memory_preview": float(tier.get("preview", 5.0)),
		"memory_face_up": float(tier.get("face_up", 1.0))
	}


# Pick the frost difficulty tier covering the player's campaign progress;
# mirrors memory_tier.
static func frost_tier(config, progress_level: int) -> Dictionary:
	var tiers = config.get("difficulty_tiers", [])
	if typeof(tiers) == TYPE_ARRAY:
		for tier in tiers:
			if typeof(tier) != TYPE_DICTIONARY or not tier.has("level_range"):
				continue
			var range_data = tier["level_range"]
			if typeof(range_data) != TYPE_ARRAY or range_data.size() < 2:
				continue
			if int(progress_level) >= int(range_data[0]) and int(progress_level) <= int(range_data[1]):
				return {
					"frost_ratio": float(tier.get("frost_ratio", config.get("frost_ratio", 0.3))),
					"rows": int(tier.get("rows", config.get("rows", 10))),
					"cols": int(tier.get("cols", config.get("cols", 8))),
					"kinds": int(tier.get("kinds", config.get("kinds", 9))),
					"time_base": int(tier.get("time_base", config.get("time_base", 110)))
				}
	return {
		"frost_ratio": float(config.get("frost_ratio", 0.3)),
		"rows": int(config.get("rows", 10)),
		"cols": int(config.get("cols", 8)),
		"kinds": int(config.get("kinds", 9)),
		"time_base": int(config.get("time_base", 110))
	}


static func build_frost_level(config, tier: Dictionary):
	var rows = int(tier.get("rows", 10))
	var cols = int(tier.get("cols", 8))
	var kinds = int(tier.get("kinds", 9))
	# Same generous formula as memory: thinking time, not punish time.
	var time_limit = int(tier.get("time_base", 110)) + int(rows * cols * float(config.get("time_per_tile", 1.0)))
	return {
		"id": 1,
		"name": str(config.get("name", "冰雪挑战")),
		"mode": "frost",
		"rows": rows,
		"cols": cols,
		"kinds": kinds,
		"time_limit": time_limit,
		"frost_ratio": clamp(float(tier.get("frost_ratio", 0.3)), 0.0, 0.6)
	}


static func is_mode_unlocked(mode_id: String, config, highest_unlocked_level_index: int) :
	if mode_id == "daily":
		return true
	var unlock_level = int(config.get("unlock_level", 1))
	# Campaign levels are shown 1-based; highest_unlocked_level_index is 0-based.
	return int(highest_unlocked_level_index) + 1 >= unlock_level


static func unlock_requirement_text(mode_id: String, config) :
	if mode_id == "daily":
		return ""
	return "完成第" + str(int(config.get("unlock_level", 1))) + "关解锁"
