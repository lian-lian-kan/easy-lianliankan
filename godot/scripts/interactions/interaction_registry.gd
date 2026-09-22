extends Reference

# 交互注册表（纯数据）：棋盘交互类型的唯一登记处，新增交互从这里开始。
#
# 一个「交互」是一条多阶段状态机：phases 按推进顺序列出阶段名，玩家的
# 每次棋盘手势把交互向前推一段（选第一张 → 配对判定；武装 → 瞄准 →
# 结算）。每段可挂自己的提示文案与时长（phase_prompts），精细力度按段
# 配置——管理器在段推进后播出当前段的提示，交互结束时静默。
#
# 登记行字段：
#   label         交互的中文名（文档/调试用）。
#   priority      路由优先级，数字大的先接管棋盘单击（armed 瞄准 > 模式交互）。
#   gestures      消费的手势：press 单击 / drag 按下-划入-松开。
#   armed         瞄准类交互的武装维度（其余交互无此字段）：flag 是与
#                 game 成员同名的武装旗标，type 是道具类型，executor 是
#                 game.gd 上「点击目标后结算」的执行薄壳名。数组顺序即
#                 判定顺序（同时武装时先到先得）。
#   phases        阶段名数组，顺序即推进顺序。
#   phase_prompts 阶段名 → {text, duration}；段推进后交互仍活跃则播出。
#
# handler 契约（见 interaction_manager.gd 的 HANDLERS）：每个交互一个
# 静态模块，实现 wants_press / phase / on_press（drag 类再加三个手势
# 函数）。阶段从可观察状态推导，不新增跨局状态。

# —— 手势 ——
const GESTURE_PRESS = "press"
const GESTURE_DRAG = "drag"

# —— 交互类型 id ——
const POWER_TARGET = "power_target"
const PAIR_SELECT = "pair_select"
const MEMORY_PICK = "memory_pick"
const DRAG_LINK = "drag_link"

# —— 阶段名 ——
const PHASE_SELECT_FIRST = "select_first"
const PHASE_FLIP_FIRST = "flip_first"
const PHASE_TARGETING = "targeting"
const PHASE_PICK_SECOND = "pick_second"
const PHASE_PRESS = "press"
const PHASE_EXTEND = "extend"
const PHASE_RELEASE = "release"
const PHASE_RESOLVE = "resolve"
const PHASE_RESOLVE_PAIR = "resolve_pair"

const REGISTRY = {
	POWER_TARGET: {
		"label": "道具瞄准",
		"priority": 100,
		"gestures": [GESTURE_PRESS],
		"armed": [
			{"flag": "frost_pending", "type": "warm_patch", "executor": "_execute_warm_patch"},
			{"flag": "bomb_pending", "type": "bomb", "executor": "_execute_bomb"},
			{"flag": "rainbow_pending", "type": "rainbow", "executor": "_execute_rainbow_click"},
		],
		"phases": [PHASE_TARGETING, PHASE_PICK_SECOND, PHASE_RESOLVE],
		"phase_prompts": {
			# 彩虹第二段（已收第一块）过去没有提示，玩家常不知道还要点
			# 一下；文案只复用既有字符，字体子集无需重跑。
			PHASE_PICK_SECOND: {"text": "🌈 已选一块，再点一块不同的方块", "duration": 1.6},
		},
	},
	PAIR_SELECT: {
		"label": "经典选牌",
		"priority": 10,
		"gestures": [GESTURE_PRESS],
		"phases": [PHASE_SELECT_FIRST, PHASE_RESOLVE_PAIR],
	},
	MEMORY_PICK: {
		"label": "盲盒翻牌",
		"priority": 10,
		"gestures": [GESTURE_PRESS],
		"phases": [PHASE_FLIP_FIRST, PHASE_RESOLVE_PAIR],
	},
	DRAG_LINK: {
		"label": "连线消",
		# 高于选牌：连线消会话里阶段查询优先报手势段；它不 wants_press，
		# 单击路由不受影响（轻点仍落回经典选牌流）。
		"priority": 20,
		"gestures": [GESTURE_DRAG, GESTURE_PRESS],
		"phases": [PHASE_PRESS, PHASE_EXTEND, PHASE_RELEASE],
	},
}
