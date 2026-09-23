extends Reference

# 攀登树 roguelike 增益：每层登顶后三选一，增益作用于即将开始的那一层。
# Tables and pure math here; the offer modal lives in ui_panels.gd and the
# session hooks (clock/combo/powerups) in special_session/session/revive.

const BUFF_POOL = [
	{"id": "time_gift", "icon": "⏱️", "name": "时间礼物", "desc": "下一层开局 +15 秒"},
	{"id": "score_prism", "icon": "🌈", "name": "分数棱镜", "desc": "下一层得分 x1.25"},
	{"id": "combo_ember", "icon": "🔥", "name": "余烬连击", "desc": "下一层连击窗口 +40%"},
	{"id": "tool_breeze", "icon": "🍃", "name": "工具清风", "desc": "下一层提示/洗牌不耗时"},
	{"id": "bomb_gift", "icon": "💣", "name": "炸弹礼物", "desc": "下一层 +1 炸弹"},
	{"id": "freeze_gift", "icon": "🧊", "name": "时光瓶", "desc": "下一层 +1 冻结"},
	{"id": "shuffle_gift", "icon": "🔀", "name": "洗牌礼物", "desc": "下一层 +1 洗牌"},
]

const OFFER_SIZE = 3
const TIME_GIFT_SECONDS = 15
const SCORE_MULT = 1.25
const COMBO_WINDOW_MULT = 1.4

static func buff_by_id(buff_id) -> Dictionary:
	for buff in BUFF_POOL:
		if str(buff["id"]) == str(buff_id):
			return buff
	return {}

# Roll OFFER_SIZE distinct buff ids (partial Fisher-Yates over a copy).
# excluded_ids lets clockless sessions (endless) drop time-based buffs.
static func roll_offer(excluded_ids := []) -> Array:
	var pool = []
	for buff in BUFF_POOL:
		if str(buff["id"]) in excluded_ids:
			continue
		pool.append(str(buff["id"]))
	var picked = []
	for i in range(min(OFFER_SIZE, pool.size())):
		var j = i + int(randi() % (pool.size() - i))
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
		picked.append(pool[i])
	return picked

static func is_score_prism(buffs) -> bool:
	return _has_buff(buffs, "score_prism")

# score_prism folds into the upcoming layer's score multiplier (the level dict
# is rebuilt fresh every layer, so the mult never compounds).
static func apply_score_mult(level: Dictionary, buffs) -> void:
	if not is_score_prism(buffs):
		return
	level["score_multiplier"] = float(level.get("score_multiplier", 1.0)) * SCORE_MULT

static func combo_window_mult(buffs) -> float:
	return COMBO_WINDOW_MULT if _has_buff(buffs, "combo_ember") else 1.0

static func tools_free(buffs) -> bool:
	return _has_buff(buffs, "tool_breeze")

static func has_time_gift(buffs) -> bool:
	return _has_buff(buffs, "time_gift")

# Power-up grants merge into the layer's resolved loadout; gift ids map onto
# their loadout keys explicitly (freeze_gift → time_freeze, shuffle_gift →
# reshuffle — the naive suffix strip would miss both).
const GIFT_LOADOUT_KEYS = {
	"bomb_gift": "bomb",
	"freeze_gift": "time_freeze",
	"shuffle_gift": "reshuffle",
}

static func bonus_loadout(buffs) -> Dictionary:
	var bonus = {}
	if typeof(buffs) != TYPE_DICTIONARY:
		return bonus
	for gift_id in GIFT_LOADOUT_KEYS:
		if buffs.has(gift_id):
			bonus[GIFT_LOADOUT_KEYS[gift_id]] = 1
	return bonus

static func _has_buff(buffs, buff_id: String) -> bool:
	return typeof(buffs) == TYPE_DICTIONARY and buffs.has(buff_id)
