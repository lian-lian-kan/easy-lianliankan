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
