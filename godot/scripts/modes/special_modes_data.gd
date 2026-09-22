extends Reference

# Pure data tables for the special modes: default configs per mode, display
# labels, intro copy, tray/collect/flip extras and the settlement table.
# Split from special_modes.gd so balance/content tweaks only touch data.

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
		# Must stay equal to data/game_modes.json (override_consistency gate):
		# this default is what players get if the JSON ever fails to load.
		"kinds_increment_every": 5,
		"board_expansion_every": 3,
		"max_rows": 16,
		"max_cols": 14,
		"max_kinds": 20,
		"unlock_level": 8,
		"base_rows": 10,
		"base_cols": 8
	},
	"tree": {
		"mode_id": "tree",
		"name": "攀登树",
		"description": "一棵望不到头的大树，逐层向上攀登",
		"unlock_level": 1
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
		"description": "考验你的记忆力",
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
	},
	"fever": {
		"mode_id": "fever",
		"name": "狂热模式",
		"description": "全程狂热，消除得分x1.5还返时间",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 90,
		"fever_mode_threshold": 2,
		"fever_multiplier": 1.5,
		"time_bonus_per_match": 1,
		"combo_time_bonus": 0
	},
	"perfect": {
		"mode_id": "perfect",
		"name": "完美模式",
		"description": "没有时限，但失误3次即败",
		"unlock_level": 15,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 0,
		"miss_limit": 3
	},
	"tray": {
		"mode_id": "tray",
		"name": "叠叠消",
		"description": "点牌入槽，三张同面即消",
		"unlock_level": 13,
		"time_limit": 240,
		"layers": 4,
		"layer_rows": 5,
		"layer_cols": 6,
		"kinds": 10,
		"tray_capacity": 7
	},
	"collect": {
		"mode_id": "collect",
		"name": "收集挑战",
		"description": "限时收集指定的目标图案",
		"unlock_level": 14,
		"rows": 10,
		"cols": 8,
		"kinds": 10,
		"time_limit": 150,
		"target_count": 3,
		"target_pairs": 3
	},
	"flip": {
		"mode_id": "flip",
		"name": "翻翻乐",
		"description": "全暗牌翻配对，靠记忆全消",
		"unlock_level": 15,
		"rows": 4,
		"cols": 6,
		"pairs": 12,
		"time_limit": 180
	},
	"rock": {
		"mode_id": "rock",
		"name": "障碍模式",
		"description": "石头牌挡路，炸弹开路或绕行",
		"unlock_level": 14,
		"rock_ratio": 0.12,
		"difficulty_tiers": [
			{"level_range": [1, 5], "rock_ratio": 0.08, "rows": 10, "cols": 8, "kinds": 8, "time_base": 120},
			{"level_range": [6, 10], "rock_ratio": 0.14, "rows": 10, "cols": 8, "kinds": 9, "time_base": 140},
			{"level_range": [11, 999], "rock_ratio": 0.2, "rows": 10, "cols": 9, "kinds": 11, "time_base": 160}
		]
	},
	"defuse": {
		"mode_id": "defuse",
		"name": "拆弹行动",
		"description": "诅咒方块倒计时，先拆为敬",
		"unlock_level": 15,
		"bomb_ratio": 0.16,
		"bomb_seconds": 40,
		"difficulty_tiers": [
			{"level_range": [1, 5], "bomb_ratio": 0.1, "rows": 10, "cols": 8, "kinds": 8, "time_base": 120},
			{"level_range": [6, 10], "bomb_ratio": 0.16, "rows": 10, "cols": 8, "kinds": 9, "time_base": 140},
			{"level_range": [11, 999], "bomb_ratio": 0.22, "rows": 10, "cols": 9, "kinds": 11, "time_base": 160}
		],
	},
	"target": {
		"mode_id": "target",
		"name": "指定连消",
		"description": "金光指哪消哪，顺序不能乱",
		"unlock_level": 14,
		"target_bonus": 5,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 150
	},
	"shift": {
		"mode_id": "shift",
		"name": "变脸模式",
		"description": "图案周期交换位置，手要快",
		"unlock_level": 15,
		"shift_interval": 8,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 150
	},
	"slide": {
		"mode_id": "slide",
		"name": "滑移模式",
		"description": "每消一对，整行滑移一位",
		"unlock_level": 16,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 180
	},
	"defense": {
		"mode_id": "defense",
		"name": "守卫模式",
		"description": "消除击退怪物，别让它近身",
		"unlock_level": 16,
		"defense_start": 5,
		"defense_step": 12,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 240
	},
	"sum10": {
		"mode_id": "sum10",
		"name": "合十消",
		"description": "两数相加为10即可消除",
		"unlock_level": 17,
		"sum10": true,
		"rows": 10,
		"cols": 8,
		"kinds": 5,
		"time_limit": 180
	},
	"duel": {
		"mode_id": "duel",
		"name": "同屏对战",
		"description": "双人轮流消除，分高者胜",
		"unlock_level": 17,
		"rows": 10,
		"cols": 8,
		"kinds": 8,
		"time_limit": 240
	},
	"drag": {
		"mode_id": "drag",
		"name": "连线消",
		"description": "一笔拖过相邻同款，三连即消",
		"unlock_level": 15,
		"rows": 8,
		"cols": 8,
		"kinds": 6,
		"time_limit": 150,
		"chain_min": 3
	},
	"edu": {
		"mode_id": "edu",
		"name": "知识配对",
		"description": "汉字↔拼音、单词↔翻译、算式↔答案",
		"unlock_level": 14,
		"time_base": 120,
		"time_per_tile": 1.2,
		"difficulty_tiers": [
			{"level_range": [1, 5], "rows": 6, "cols": 6, "time_base": 110},
			{"level_range": [6, 10], "rows": 8, "cols": 6, "time_base": 130},
			{"level_range": [11, 999], "rows": 10, "cols": 6, "time_base": 150}
		]
	}
}

# ── 玩法注册表：每个特殊玩法一行声明，全部展示/结算表面由此派生 ──
# 新增玩法的必改清单只有三处：DEFAULT_CONFIGS 加配置行、本表加声明行、
# achievements.gd 加首胜成就文案（可选：startup_probe 加启动 Witness）。
# 字段：
#   icon/label  面板与统计页的图标+名称        blurb    玩法面板一行简介
#   intro       开局横幅（空串回落「特殊模式开始」）  cat  面板分组（CATEGORY_TITLES 键）
#   settle      结算面板名（空串 = 非纪录玩法，结算走 special_session 专属分支）
#   sub         副标题语义："best"=最佳N分 / "dyn"=ui_hud 专属动态文案 / "fall"=回落战役行
# 派生约定（mode_meta_test 强制）：patch_key=<id>_result、best_key=<id>_best_score、
# 首胜成就=<id>_first（仅 settle 非空的玩法）。
const MODES = {
	"daily": {"icon": "📅", "label": "每日挑战", "blurb": "", "intro": "每日挑战开始！今天的棋盘人人相同", "cat": "rush", "settle": "", "sub": "dyn"},
	"time_attack": {"icon": "⏱️", "label": "限时挑战", "blurb": "60秒起，消除得时间", "intro": "限时挑战！每次消除加时间，连击 5 触发狂热", "cat": "rush", "settle": "", "sub": "best"},
	"memory": {"icon": "🎁", "label": "盲盒模式", "blurb": "记忆翻牌配对", "intro": "", "cat": "memory", "settle": "盲盒挑战", "sub": "best"},
	"frost": {"icon": "❄️", "label": "冰雪挑战", "blurb": "冰冻方块要消除两次", "intro": "冰雪挑战！❄️ 结霜的方块要消除两次，🔥暖宝宝可以直接解冻", "cat": "mech", "settle": "冰雪挑战", "sub": "best"},
	"zen": {"icon": "🍵", "label": "休闲模式", "blurb": "没有时限，纯享受", "intro": "休闲模式！没有时限，慢慢享受", "cat": "casual", "settle": "休闲一局", "sub": "best"},
	"hell": {"icon": "🔥", "label": "地狱模式", "blurb": "大盘少图案超紧时间", "intro": "地狱模式！大盘少图案，时间极紧", "cat": "rush", "settle": "地狱挑战", "sub": "best"},
	"moves": {"icon": "🧮", "label": "步数挑战", "blurb": "步数有限精打细算", "intro": "步数挑战！每消一对花 1 步，省着用", "cat": "casual", "settle": "步数挑战", "sub": "dyn"},
	"race": {"icon": "🤖", "label": "竞速对战", "blurb": "和机器人抢消·先完成者胜", "intro": "竞速对战！抢在机器人前面消完全部", "cat": "duel", "settle": "竞速对战", "sub": "best"},
	"stack": {"icon": "🥞", "label": "叠层模式", "blurb": "上层压下层先消上层", "intro": "", "cat": "mech", "settle": "叠层挑战", "sub": "best"},
	"gravity": {"icon": "🍎", "label": "重力模式", "blurb": "消除后方块掉落补位", "intro": "", "cat": "mech", "settle": "重力挑战", "sub": "best"},
	"fog": {"icon": "🌫️", "label": "迷雾模式", "blurb": "边缘迷雾随消除退散", "intro": "", "cat": "mech", "settle": "迷雾散尽", "sub": "best"},
	"chain": {"icon": "⛓️", "label": "锁链模式", "blurb": "相邻消除解锁锁链", "intro": "", "cat": "mech", "settle": "锁链尽断", "sub": "best"},
	"fever": {"icon": "🌶️", "label": "狂热模式", "blurb": "全程x1.5分消除返时间", "intro": "狂热模式！连击 2 起全程 x1.5 分，消除还返时间", "cat": "rush", "settle": "狂热燃尽", "sub": "best"},
	"perfect": {"icon": "💎", "label": "完美模式", "blurb": "无时限但失误3次即败", "intro": "完美模式！没有时限，但失误 3 次就失败啦", "cat": "casual", "settle": "完美零失误", "sub": "dyn"},
	"tray": {"icon": "🀄", "label": "叠叠消", "blurb": "点牌入槽三张即消", "intro": "叠叠消！点牌入槽，三张同面即消，槽满则败", "cat": "memory", "settle": "叠叠消通关", "sub": "fall"},
	"collect": {"icon": "🎯", "label": "收集挑战", "blurb": "限时集齐目标图案", "intro": "收集挑战！限时集齐目标图案", "cat": "casual", "settle": "收集达成", "sub": "fall"},
	"flip": {"icon": "🃏", "label": "翻翻乐", "blurb": "记忆翻牌全消", "intro": "翻翻乐！全部盖着，靠记忆翻出配对", "cat": "memory", "settle": "翻翻乐全消", "sub": "fall"},
	"rock": {"icon": "🪨", "label": "障碍模式", "blurb": "石头牌挡路炸弹开路", "intro": "障碍模式！🪨 石头牌消不掉，炸弹能炸开它", "cat": "mech", "settle": "障碍通关", "sub": "best"},
	"defuse": {"icon": "💣", "label": "拆弹行动", "blurb": "诅咒方块限时拆除", "intro": "拆弹行动！💣 诅咒方块限时拆除，别让它数到 0", "cat": "mech", "settle": "拆弹成功", "sub": "best"},
	"target": {"icon": "✨", "label": "指定连消", "blurb": "金光指哪消哪", "intro": "指定连消！✨ 只能消金光高亮的那一对", "cat": "mech", "settle": "指哪打哪", "sub": "best"},
	"shift": {"icon": "🔄", "label": "变脸模式", "blurb": "图案偷偷换位置", "intro": "变脸模式！🔄 图案会偷偷换位置，盯紧了", "cat": "mech", "settle": "变脸大师", "sub": "best"},
	"slide": {"icon": "🧲", "label": "滑移模式", "blurb": "每消一对整行滑移", "intro": "滑移模式！🧲 每消一对整行就滑动一位，位置要重新算", "cat": "mech", "settle": "滑移通关", "sub": "best"},
	"defense": {"icon": "🧟", "label": "守卫模式", "blurb": "消除击退怪物近身即败", "intro": "守卫模式！🧟 消除击退怪物，它近身就输了", "cat": "mech", "settle": "守卫成功", "sub": "best"},
	"sum10": {"icon": "🔟", "label": "合十消", "blurb": "两数相加为10即可消", "intro": "合十消！🔟 两张牌的数字相加为 10 就能消除", "cat": "mech", "settle": "合十满分", "sub": "best"},
	"duel": {"icon": "👫", "label": "同屏对战", "blurb": "轮流消牌分高者胜", "intro": "同屏对战！👫 成功消除继续，失败换对方，分高者胜", "cat": "duel", "settle": "同屏争霸", "sub": "best"},
	"drag": {"icon": "🖋️", "label": "连线消", "blurb": "一笔拖过相邻同款三连即消", "intro": "连线消！🖋️ 按住一笔拖过相邻同款，凑满 3 个松手一次消掉", "cat": "know", "settle": "一笔连消", "sub": "best"},
	"edu": {"icon": "🎓", "label": "知识配对", "blurb": "每日轮换知识主题配对", "intro": "知识配对！🎓 牌面是一对知识：找到相关的两张（如 汉字↔拼音）", "cat": "know", "settle": "知识学士", "sub": "best"},
	"endless": {"icon": "∞", "label": "无尽模式", "blurb": "", "intro": "无尽模式第1轮！棋盘会越滚越大", "cat": "infinite", "settle": "", "sub": "dyn"},
	"tree": {"icon": "🌳", "label": "攀登树", "blurb": "", "intro": "攀登树！🌳 从第 1 层开始往上爬，每层更难，里程碑送上樱花", "cat": "infinite", "settle": "", "sub": "dyn"},
}

# 玩法面板分组：标题与顺序在此；组内成员与顺序由 MODES 行的 cat 字段派生。
const CATEGORY_TITLES = [
	{"id": "rush", "title": "🏁 竞速限时"},
	{"id": "memory", "title": "🧠 记忆翻牌"},
	{"id": "mech", "title": "⚙️ 机制挑战"},
	{"id": "know", "title": "🎓 知识新范式"},
	{"id": "duel", "title": "👥 双人"},
	{"id": "casual", "title": "🌙 休闲自定"},
	{"id": "infinite", "title": "∞ 无尽"},
]

# 战役规则标签（非特殊玩法，不进注册表）。
const CAMPAIGN_LABELS = {
	"classic": "经典", "rush": "冲刺", "combo": "连击", "endurance": "耐力"
}

# 结算后按模式语境补发的条件成就。
