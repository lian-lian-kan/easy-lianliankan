extends Reference

const DATA = preload("res://scripts/special_modes_data.gd")

# Forwarding aliases: existing code and tests read the tables through
# special_modes.gd, so the data module stays swappable.
const DEFAULT_CONFIGS = DATA.DEFAULT_CONFIGS
const MODE_LABELS = DATA.MODE_LABELS
const INTRO_TEXTS = DATA.INTRO_TEXTS
const MODE_LABELS_EXTRA = DATA.MODE_LABELS_EXTRA
const INTRO_TEXTS_EXTRA = DATA.INTRO_TEXTS_EXTRA
const RECORD_MODES = DATA.RECORD_MODES
const SUBTITLE_RECORDS = DATA.SUBTITLE_RECORDS

# Pure logic for the special game modes (daily challenge / time attack /
# endless). Kept free of scene-tree dependencies so it can run headless in
# tests; game.gd owns all presentation.

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
	if config.has("miss_limit"):
		level["miss_limit"] = int(config.get("miss_limit", 3))
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

static func mode_label(mode: String) -> String:
	if MODE_LABELS_EXTRA.has(mode):
		return str(MODE_LABELS_EXTRA[mode])
	return str(MODE_LABELS.get(mode, '未知'))

# Empty when the mode's subtitle falls to ui_hud's bespoke branches
# (daily/endless/moves/perfect) or the campaign line (tray/collect/flip).
static func subtitle_record_key(mode: String) -> String:
	return str(SUBTITLE_RECORDS.get(mode, ""))

static func intro_text(mode_id: String) -> String:
	if INTRO_TEXTS_EXTRA.has(mode_id):
		return str(INTRO_TEXTS_EXTRA[mode_id])
	return str(INTRO_TEXTS.get(mode_id, "特殊模式开始"))

# Stage-opening callout (title banner): mode -> [text, color]. Campaign
# levels share one format; daily/endless/frost embed their dynamic context.
static func stage_callout(mode: String, level, level_index: int, endless_round: int):
	if mode == "daily":
		var d = OS.get_date()
		return ["每日挑战 · %d月%d日" % [int(d.month), int(d.day)], Color("9775fa")]
	if mode == "endless":
		return ["无尽模式 · 第%d轮" % endless_round, Color("0ca678")]
	if mode == "time_attack":
		return ["限时挑战", Color("f06565")]
	if mode == "memory":
		return ["盲盒模式", Color("3bc9db")]
	if mode == "frost":
		return ["冰雪挑战 · %d%% 方块结了冰" % int(round(float(level.get("frost_ratio", 0.3)) * 100)), Color("4dabf7")]
	if mode == "tray":
		return ["叠叠消", Color("20c997")]
	if mode == "collect":
		return ["收集挑战", Color("f59f00")]
	if mode == "flip":
		return ["翻翻乐", Color("9775fa")]
	return ["第" + str(int(level.get("id", level_index + 1))) + "关 · " + str(level.get("name", "关卡")), Color("e64980")]

# ---- 特殊模式结算表：纪录补丁键 / 首通成就 / 面板标题 ----

static func bonus_achievements(mode: String, context := {}) -> Array:
	var bonus = []
	if mode == "frost" and int(context.get("frost_uses", 1)) == 0:
		bonus.append("frost_no_power")
	if mode == "moves" and int(context.get("moves_left", 0)) >= int(context.get("move_budget", 1)) / 5:
		bonus.append("moves_saver")
	return bonus

# 玩法面板 13 张卡的展示数据（标题 + 详情行），纯函数便于直测。
static func build_tray_level(config):
	return {
		"mode_id": "tray",
		"name": "叠叠消",
		"time_limit": int(config.get("time_limit", 240)),
		"layers": int(config.get("layers", 4)),
		"layer_rows": int(config.get("layer_rows", 5)),
		"layer_cols": int(config.get("layer_cols", 6)),
		"kinds": int(config.get("kinds", 10)),
		"tray_capacity": int(config.get("tray_capacity", 7)),
		"score_multiplier": 1.0
	}

static func build_collect_level(config):
	var kinds = int(config.get("kinds", 10))
	var target_count = int(config.get("target_count", 3))
	var pool := []
	for i in range(kinds):
		pool.append(i)
	var targets := []
	for _i in range(target_count):
		var pick_index = randi() % pool.size()
		targets.append(pool[pick_index])
		pool.remove(pick_index)
	return {
		"mode_id": "collect",
		"name": "收集挑战",
		"rows": int(config.get("rows", 10)),
		"cols": int(config.get("cols", 8)),
		"kinds": kinds,
		"time_limit": int(config.get("time_limit", 150)),
		"targets": targets,
		"target_pairs": int(config.get("target_pairs", 3)),
		"score_multiplier": 1.0
	}

static func build_memory_flip_level(config):
	return {
		"mode_id": "flip",
		"name": "翻翻乐",
		"rows": int(config.get("rows", 4)),
		"cols": int(config.get("cols", 6)),
		"pairs": int(config.get("pairs", 12)),
		"time_limit": int(config.get("time_limit", 180)),
		"score_multiplier": 1.0
	}

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
		{"id": "fever", "title": "🌶️ 狂热模式", "detail": "全程x1.5分消除返时间 · 最佳%d分" % int(progression_state.get("fever_best_score", 0))},
		{"id": "perfect", "title": "💎 完美模式", "detail": "无时限但失误3次即败 · 最佳%d分" % int(progression_state.get("perfect_best_score", 0))},
		{"id": "tray", "title": "🀄 叠叠消", "detail": "点牌入槽三张即消 · 最佳%d分" % int(progression_state.get("tray_best_score", 0))},
		{"id": "collect", "title": "🎯 收集挑战", "detail": "限时集齐目标图案 · 最佳%d分" % int(progression_state.get("collect_best_score", 0))},
		{"id": "flip", "title": "🃏 翻翻乐", "detail": "记忆翻牌全消 · 最佳%d分" % int(progression_state.get("flip_best_score", 0))},
		{"id": "endless", "title": "∞ 无尽模式", "detail": "不限时，棋盘越滚越大 · 最佳第%d轮 · 最高%d分" % [int(endless_best.get("round", 0)), int(endless_best.get("score", 0))]}
	]
