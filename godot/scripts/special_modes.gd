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
	},
	"zen": {
		"mode_id": "zen",
		"name": "休闲模式",
		"description": "没有时限，慢慢享受",
		"unlock_level": 1,
		"rows": 10,
		"cols": 8,
		"kinds": 7,
		"time_limit": 0
	},
	"hell": {
		"mode_id": "hell",
		"name": "地狱模式",
		"description": "大盘少图案，时间极紧",
		"unlock_level": 12,
		"rows": 12,
		"cols": 8,
		"kinds": 12,
		"time_limit": 100
	},
	"moves": {
		"mode_id": "moves",
		"name": "步数挑战",
		"description": "步数有限，精打细算",
		"unlock_level": 14,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 0,
		"move_budget": 56
	},
	"race": {
		"mode_id": "race",
		"name": "竞速对战",
		"description": "和机器人比谁先消完",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 0,
		"ai_interval": 8.5
	},
	"stack": {
		"mode_id": "stack",
		"name": "叠层模式",
		"description": "上层压着下层，先消上层",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 150,
		"stack_ratio": 0.25
	},
	"gravity": {
		"mode_id": "gravity",
		"name": "重力模式",
		"description": "消除后上方方块掉落补位",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 120
	},
	"fog": {
		"mode_id": "fog",
		"name": "迷雾模式",
		"description": "边缘迷雾随消除退散",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 150,
		"fog_layers": 2
	},
	"chain": {
		"mode_id": "chain",
		"name": "锁链模式",
		"description": "相邻消除才能解锁锁链",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 140,
		"chain_ratio": 0.22
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


# Classic-rules boards with different knobs: zen/hell change board and
# clock pressure, moves adds a pair budget, race adds the AI interval.
static func build_classic_style_level(config, mode_id: String):
	var rows = int(config.get("rows", 10))
	var cols = int(config.get("cols", 8))
	var kinds = int(config.get("kinds", 8))
	var level = {
		"id": 1,
		"name": str(config.get("name", mode_id)),
		"mode": mode_id,
		"rows": rows,
		"cols": cols,
		"kinds": kinds,
		"time_limit": int(config.get("time_limit", 90))
	}
	if config.has("move_budget"):
		level["move_budget"] = int(config.get("move_budget", 56))
	if config.has("ai_interval"):
		level["ai_interval"] = float(config.get("ai_interval", 8.5))
	if config.has("stack_ratio"):
		level["stack_ratio"] = float(config.get("stack_ratio", 0.25))
	if config.has("fog_layers"):
		level["fog_layers"] = int(config.get("fog_layers", 2))
	if config.has("chain_ratio"):
		level["chain_ratio"] = float(config.get("chain_ratio", 0.22))
	return level


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

# ---- 模式展示元数据（标签 / 开场文案）----

const MODE_LABELS = {
	"classic": "经典", "rush": "冲刺", "combo": "连击", "endurance": "耐力",
	"daily": "每日挑战", "time_attack": "限时挑战", "endless": "无尽模式",
	"memory": "盲盒模式", "frost": "冰雪挑战", "zen": "休闲模式",
	"hell": "地狱模式", "moves": "步数挑战", "race": "竞速对战",
	"stack": "叠层模式", "gravity": "重力模式", "fog": "迷雾模式", "chain": "锁链模式"
}

const INTRO_TEXTS = {
	"daily": "每日挑战开始！今天的棋盘人人相同",
	"time_attack": "限时挑战！每次消除加时间，连击 5 触发狂热",
	"endless": "无尽模式第1轮！棋盘会越滚越大",
	"frost": "冰雪挑战！❄️ 结霜的方块要消除两次，🔥暖宝宝可以直接解冻",
	"zen": "休闲模式！没有时限，慢慢享受",
	"hell": "地狱模式！大盘少图案，时间极紧",
	"moves": "步数挑战！每消一对花 1 步，省着用",
	"race": "竞速对战！抢在机器人前面消完全部"
}

static func mode_label(mode: String) -> String:
	return str(MODE_LABELS.get(mode, '未知'))

static func intro_text(mode_id: String) -> String:
	return str(INTRO_TEXTS.get(mode_id, "特殊模式开始"))

# ---- 特殊模式结算表：纪录补丁键 / 首通成就 / 面板标题 ----

const RECORD_MODES = {
	"stack": {"label": "叠层挑战", "patch_key": "stack_result", "best_key": "stack_best_score", "achievements": ["stack_first"]},
	"gravity": {"label": "重力挑战", "patch_key": "gravity_result", "best_key": "gravity_best_score", "achievements": ["gravity_first"]},
	"fog": {"label": "迷雾散尽", "patch_key": "fog_result", "best_key": "fog_best_score", "achievements": ["fog_first"]},
	"chain": {"label": "锁链尽断", "patch_key": "chain_result", "best_key": "chain_best_score", "achievements": ["chain_first"]},
	"zen": {"label": "休闲一局", "patch_key": "zen_result", "best_key": "zen_best_score", "achievements": ["zen_first"]},
	"hell": {"label": "地狱挑战", "patch_key": "hell_result", "best_key": "hell_best_score", "achievements": ["hell_first"]},
	"moves": {"label": "步数挑战", "patch_key": "moves_result", "best_key": "moves_best_score", "achievements": ["moves_first"]},
	"race": {"label": "竞速对战", "patch_key": "race_result", "best_key": "race_best_score", "achievements": ["race_first"]},
	"frost": {"label": "冰雪挑战", "patch_key": "frost_result", "best_key": "frost_best_score", "achievements": ["frost_first"]},
	"memory": {"label": "盲盒挑战", "patch_key": "memory_result", "best_key": "memory_best_score", "achievements": ["memory_first"]},
}

# 结算后按模式语境补发的条件成就。
static func bonus_achievements(mode: String, context := {}) -> Array:
	var bonus = []
	if mode == "frost" and int(context.get("frost_uses", 1)) == 0:
		bonus.append("frost_no_power")
	if mode == "moves" and int(context.get("moves_left", 0)) >= int(context.get("move_budget", 1)) / 5:
		bonus.append("moves_saver")
	return bonus

# 玩法面板 13 张卡的展示数据（标题 + 详情行），纯函数便于直测。
static func modes_panel_rows(progression_state) -> Array:
	var today = date_string(OS.get_date())
	var daily = progression_state.get("daily_challenge", {})
	var endless_best = progression_state.get("endless_best", {})
	var done_today = str(daily.get("last_date", "")) == today
	return [
		{"id": "daily", "title": "📅 每日挑战", "detail": "全网同一棋盘 · 连胜%d · 最佳%d分 · %s" % [int(daily.get("streak", 0)), int(daily.get("best_score", 0)), "今日已完成" if done_today else "今日未完成"]},
		{"id": "time_attack", "title": "⏱️ 限时挑战", "detail": "60秒起，消除得时间 · 最佳%d分" % int(progression_state.get("time_attack_best_score", 0))},
		{"id": "memory", "title": "🎁 盲盒模式", "detail": "记忆翻牌配对 · 最佳%d分" % int(progression_state.get("memory_best_score", 0))},
		{"id": "frost", "title": "❄️ 冰雪挑战", "detail": "冰冻方块要消除两次 · 最佳%d分" % int(progression_state.get("frost_best_score", 0))},
		{"id": "zen", "title": "🍵 休闲模式", "detail": "没有时限，纯享受 · 最佳%d分" % int(progression_state.get("zen_best_score", 0))},
		{"id": "hell", "title": "🔥 地狱模式", "detail": "大盘少图案超紧时间 · 最佳%d分" % int(progression_state.get("hell_best_score", 0))},
		{"id": "moves", "title": "🧮 步数挑战", "detail": "步数有限精打细算 · 最佳%d分" % int(progression_state.get("moves_best_score", 0))},
		{"id": "race", "title": "🤖 竞速对战", "detail": "和机器人抢消·先完成者胜 · 最佳%d分" % int(progression_state.get("race_best_score", 0))},
		{"id": "stack", "title": "🥞 叠层模式", "detail": "上层压下层先消上层 · 最佳%d分" % int(progression_state.get("stack_best_score", 0))},
		{"id": "gravity", "title": "🍎 重力模式", "detail": "消除后方块掉落补位 · 最佳%d分" % int(progression_state.get("gravity_best_score", 0))},
		{"id": "fog", "title": "🌫️ 迷雾模式", "detail": "边缘迷雾随消除退散 · 最佳%d分" % int(progression_state.get("fog_best_score", 0))},
		{"id": "chain", "title": "⛓️ 锁链模式", "detail": "相邻消除解锁锁链 · 最佳%d分" % int(progression_state.get("chain_best_score", 0))},
		{"id": "endless", "title": "∞ 无尽模式", "detail": "不限时，棋盘越滚越大 · 最佳第%d轮 · 最高%d分" % [int(endless_best.get("round", 0)), int(endless_best.get("score", 0))]}
	]
