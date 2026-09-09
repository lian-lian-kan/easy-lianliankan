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
	}
}

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

const MODE_LABELS_EXTRA = {
	"tray": "叠叠消",
	"collect": "收集挑战",
	"flip": "翻翻乐",
}
const INTRO_TEXTS_EXTRA = {
	"tray": "叠叠消！点牌入槽，三张同面即消，槽满则败",
	"collect": "收集挑战！限时集齐目标图案",
	"flip": "翻翻乐！全部盖着，靠记忆翻出配对",
}

const RECORD_MODES = {
	"stack": {"label": "叠层挑战", "patch_key": "stack_result", "best_key": "stack_best_score", "achievements": ["stack_first"]},
	"gravity": {"label": "重力挑战", "patch_key": "gravity_result", "best_key": "gravity_best_score", "achievements": ["gravity_first"]},
	"fog": {"label": "迷雾散尽", "patch_key": "fog_result", "best_key": "fog_best_score", "achievements": ["fog_first"]},
	"chain": {"label": "锁链尽断", "patch_key": "chain_result", "best_key": "chain_best_score", "achievements": ["chain_first"]},
	"tray": {"label": "叠叠消通关", "patch_key": "tray_result", "best_key": "tray_best_score", "achievements": ["tray_first"]},
	"collect": {"label": "收集达成", "patch_key": "collect_result", "best_key": "collect_best_score", "achievements": ["collect_first"]},
	"flip": {"label": "翻翻乐全消", "patch_key": "flip_result", "best_key": "flip_best_score", "achievements": ["flip_first"]},
	"zen": {"label": "休闲一局", "patch_key": "zen_result", "best_key": "zen_best_score", "achievements": ["zen_first"]},
	"hell": {"label": "地狱挑战", "patch_key": "hell_result", "best_key": "hell_best_score", "achievements": ["hell_first"]},
	"moves": {"label": "步数挑战", "patch_key": "moves_result", "best_key": "moves_best_score", "achievements": ["moves_first"]},
	"race": {"label": "竞速对战", "patch_key": "race_result", "best_key": "race_best_score", "achievements": ["race_first"]},
	"frost": {"label": "冰雪挑战", "patch_key": "frost_result", "best_key": "frost_best_score", "achievements": ["frost_first"]},
	"memory": {"label": "盲盒挑战", "patch_key": "memory_result", "best_key": "memory_best_score", "achievements": ["memory_first"]},
}

# 结算后按模式语境补发的条件成就。
