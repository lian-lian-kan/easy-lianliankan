extends Reference

const DATA = preload("res://scripts/modes/special_modes_data.gd")
const TREE_LADDER = preload("res://scripts/modes/tree_ladder.gd")
const EDU = preload("res://scripts/content/edu_decks.gd")
const CURVE = preload("res://scripts/modes/difficulty_curve.gd")

# Forwarding aliases: existing code and tests read the tables through
# special_modes.gd, so the data module stays swappable.
const DEFAULT_CONFIGS = DATA.DEFAULT_CONFIGS
const MODES = DATA.MODES
const CATEGORY_TITLES = DATA.CATEGORY_TITLES
const CAMPAIGN_LABELS = DATA.CAMPAIGN_LABELS

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
	var expansion_every = int(config.get("board_expansion_every", 3))
	var extra_rounds = round_index - 1
	if extra_rounds < 0:
		extra_rounds = 0
	# Rows/cols/kinds all ride the shared grow-then-plateau step; even bases
	# with +2 strides keep every round's tile count pairable.
	return {
		"id": 1,
		"name": "第" + str(round_index) + "轮",
		"mode": "endless",
		"rows": CURVE.plateau_int(int(config.get("base_rows", 10)), int(config.get("max_rows", 16)), 2, expansion_every, extra_rounds),
		"cols": CURVE.plateau_int(int(config.get("base_cols", 8)), int(config.get("max_cols", 14)), 2, expansion_every, extra_rounds),
		"kinds": CURVE.plateau_int(int(config.get("base_kinds", 6)), int(config.get("max_kinds", 20)), int(config.get("kinds_increment_every", 1)), 1, extra_rounds),
		"time_limit": 0,
		"round_index": round_index
	}

# Tree climb: the layer height alone drives the board (curve + caps live in
# tree_ladder.gd); config stays unused but keeps the builder signature uniform.
static func build_tree_level(config, height: int):
	return TREE_LADDER.level_for(height)


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

# Shared tier picker for tiered modes (rock/defuse reuse the frost shape).
static func mode_tier(config, progress_level: int, ratio_key: String) -> Dictionary:
	var tiers = config.get("difficulty_tiers", [])
	if typeof(tiers) == TYPE_ARRAY:
		for tier in tiers:
			if typeof(tier) != TYPE_DICTIONARY or not tier.has("level_range"):
				continue
			var range_data = tier["level_range"]
			if typeof(range_data) != TYPE_ARRAY or range_data.size() < 2:
				continue
			if int(progress_level) >= int(range_data[0]) and int(progress_level) <= int(range_data[1]):
				return tier
	return {"ratio_key": config.get(ratio_key, 0.0), "rows": config.get("rows", 10), "cols": config.get("cols", 8), "kinds": config.get("kinds", 8), "time_base": config.get("time_base", 120)}

static func build_tiered_level(config, mode_id: String, progress_level: int, ratio_key: String) -> Dictionary:
	var tier = mode_tier(config, progress_level, ratio_key)
	var rows = int(tier.get("rows", 10))
	var cols = int(tier.get("cols", 8))
	var time_limit = int(tier.get("time_base", 120)) + int(rows * cols * 1.0)
	return {
		"id": 1,
		"name": str(config.get("name", mode_id)),
		"mode": mode_id,
		"rows": rows,
		"cols": cols,
		"kinds": int(tier.get("kinds", 8)),
		"time_limit": time_limit,
		ratio_key: float(tier.get(ratio_key, config.get(ratio_key, 0.0)))
	}

static func build_rock_level(config, progress_level: int) -> Dictionary:
	return build_tiered_level(config, "rock", progress_level, "rock_ratio")

static func build_defuse_level(config, progress_level: int) -> Dictionary:
	var level = build_tiered_level(config, "defuse", progress_level, "bomb_ratio")
	level["bomb_seconds"] = int(config.get("bomb_seconds", 40))
	return level


# Classic-rules boards with different knobs: zen/hell change board and
# clock pressure, moves adds a pair budget, race adds the AI interval.
# Optional passthroughs are table-driven so new knobs are one row here.
const CLASSIC_OPTIONAL_FIELDS = [
	"move_budget", "miss_limit", "ai_interval", "stack_ratio", "fog_layers",
	"defense_start", "defense_step", "sum10", "chain_ratio", "target_bonus",
	"shift_interval", "chain_min", "boss_hp",
]

static func build_classic_style_level(config, mode_id: String):
	var level = {
		"id": 1,
		"name": str(config.get("name", mode_id)),
		"mode": mode_id,
		"rows": int(config.get("rows", 10)),
		"cols": int(config.get("cols", 8)),
		"kinds": int(config.get("kinds", 8)),
		"time_limit": int(config.get("time_limit", 90))
	}
	# 连线消的一笔拖链密度是 8x8 设计的一部分，形状不做屏幕适配。
	if mode_id == "drag":
		level["lock_shape"] = true
	for field in CLASSIC_OPTIONAL_FIELDS:
		if config.has(field):
			level[field] = config[field]
	return level


# 知识配对: concept count equals the pair count so every concept deals exactly
# one prompt + one answer; the subject rotates daily (see edu_decks.gd).
static func build_edu_level(config, progress_level: int) -> Dictionary:
	var tier = mode_tier(config, progress_level, "time_base")
	var rows = int(tier.get("rows", 6))
	var cols = int(tier.get("cols", 6))
	var pairs = int(rows * cols / 2)
	# 概念牌组刚好够发该形状，形状不随屏幕适配。
	var level = {
		"id": 1,
		"name": "知识配对",
		"mode": "edu",
		"lock_shape": true,
		"rows": rows,
		"cols": cols,
		"kinds": pairs,
		"time_limit": int(tier.get("time_base", 120)) + int(rows * cols * float(config.get("time_per_tile", 1.2))),
		"subject": EDU.subject_for_date(OS.get_date())
	}
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

# ---- 模式展示元数据：全部由 MODES 注册表派生 ----

# 结算纪录表（旧 RECORD_MODES 散表的派生视图）：settle 非空的玩法各得一行，
# 键名走注册表约定（mode_meta_test 强制）：patch_key=<id>_result、
# best_key=<id>_best_score、首胜成就=<id>_first。
static func record_modes() -> Dictionary:
	var records = {}
	for mode_id in MODES:
		var row = MODES[mode_id]
		if str(row["settle"]) == "":
			continue
		records[mode_id] = {
			"label": str(row["settle"]),
			"patch_key": str(mode_id) + "_result",
			"best_key": str(mode_id) + "_best_score",
			"achievements": [str(mode_id) + "_first"],
		}
	return records

# 平铺最佳分键（progression 存档 schema 的单一来源）：
# 注册表结算玩法的 best_key + time_attack/tree 两个专属结算路径。
static func flat_best_keys() -> Array:
	var keys = []
	for mode_id in record_modes():
		keys.append(str(mode_id) + "_best_score")
	keys.append("time_attack_best_score")
	keys.append("tree_best_height")
	return keys

# 玩法面板分组（旧 MODE_CATEGORIES 常量的派生视图）：组顺序取 CATEGORY_TITLES，
# 组内成员与顺序取 MODES 行的 cat 字段。
static func mode_categories() -> Array:
	var groups = []
	for category in CATEGORY_TITLES:
		var modes = []
		for mode_id in MODES:
			if str(MODES[mode_id]["cat"]) == str(category["id"]):
				modes.append(mode_id)
		groups.append({"title": str(category["title"]), "modes": modes})
	return groups

static func mode_label(mode: String) -> String:
	if MODES.has(mode):
		return str(MODES[mode]["label"])
	return str(CAMPAIGN_LABELS.get(mode, "未知"))

# Empty when the mode's subtitle falls to ui_hud's bespoke branches
# (sub "dyn") or the campaign line (sub "fall").
static func subtitle_record_key(mode: String) -> String:
	if MODES.has(mode) and str(MODES[mode]["sub"]) == "best":
		return mode + "_best_score"
	return ""

static func intro_text(mode_id: String) -> String:
	if MODES.has(mode_id) and str(MODES[mode_id]["intro"]) != "":
		return str(MODES[mode_id]["intro"])
	return "特殊模式开始"
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
	if mode == "tree":
		return ["攀登树 · 第%d层" % int(level.get("tree_height", 1)), Color("40c057")]
	if mode == "boss":
		return ["Boss挑战 · Boss剩余 %d" % int(level.get("boss_hp", 24)), Color("f06565")]
	if mode == "drag":
		return ["连线消 · 一笔拖过 3+ 同款", Color("20c997")]
	if mode == "edu":
		var subject_name = str(EDU.SUBJECT_NAMES.get(level.get("subject", "hanzi"), ""))
		return ["知识配对 · 今日主题 %s" % subject_name, Color("7048e8")]
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

# 玩法面板行：注册表驱动。daily/endless/tree 的详情带动态上下文，走专属分支；
# 其余玩法统一「blurb · 最佳N分」（有结算纪录的玩法）或纯 blurb。
static func modes_panel_rows(progression_state) -> Array:
	var rows = []
	for mode_id in MODES:
		var spec = MODES[mode_id]
		var title = str(spec["icon"]) + " " + str(spec["label"])
		if mode_id == "daily":
			var daily = progression_state.get("daily_challenge", {})
			var done_today = str(daily.get("last_date", "")) == date_string(OS.get_date())
			rows.append({"id": mode_id, "title": title, "detail": "全网同一棋盘 · 连胜%d · 最佳%d分 · %s" % [int(daily.get("streak", 0)), int(daily.get("best_score", 0)), "今日已完成" if done_today else "今日未完成"]})
			continue
		if mode_id == "endless":
			var endless_best = progression_state.get("endless_best", {})
			rows.append({"id": mode_id, "title": title, "detail": "不限时，棋盘越滚越大 · 最佳第%d轮 · 最高%d分" % [int(endless_best.get("round", 0)), int(endless_best.get("score", 0))]})
			continue
		if mode_id == "tree":
			rows.append({"id": mode_id, "title": title, "detail": "望不到头的大树逐层攀登 · 最佳第%d层" % int(progression_state.get("tree_best_height", 0))})
			continue
		var detail = str(spec["blurb"])
		if progression_state.has(str(mode_id) + "_best_score"):
			detail += " · 最佳%d分" % int(progression_state.get(str(mode_id) + "_best_score", 0))
		rows.append({"id": mode_id, "title": title, "detail": detail})
	return rows
