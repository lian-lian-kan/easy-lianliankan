extends Reference

# 道具瞄准交互（武装 → 瞄准 → 结算）：炸弹/彩虹/暖宝宝共用的「下一次
# 棋盘点击落子」交互。武装由 powerups.gd 的 _activate_* 完成；这里把
# 武装中的每一次点击交给注册表里登记的执行薄壳，并按可观察状态推导
# 当前阶段（彩虹收下第一块后进入 pick_second 段）。

const REGISTRY = preload("res://scripts/interactions/interaction_registry.gd")

# 当前武装中的登记行（flag/type/executor）；未武装返回 {}。
static func armed_entry(game):
	for entry in REGISTRY.REGISTRY[REGISTRY.POWER_TARGET]["armed"]:
		if bool(game.get(entry["flag"])):
			return entry
	return {}

static func wants_press(game):
	return not armed_entry(game).empty()

static func phase(game):
	var entry = armed_entry(game)
	if entry.empty():
		return ""
	# 彩虹按已选目标分段：第一块已收下则等待第二块。
	if entry["type"] == "rainbow" and game.selected.x >= 0:
		return REGISTRY.PHASE_PICK_SECOND
	return REGISTRY.PHASE_TARGETING

# 武装中的点击全部归这里：交给该次武装的执行薄壳结算（是否消耗/退回
# 由 powerups 域裁决，例如暖宝宝点错冰面会保持武装）。
static func on_press(game, point):
	var entry = armed_entry(game)
	if entry.empty():
		return
	game.call(entry["executor"], point)

# 统一收回：转管道具域既有的「再按一次收回并退费」逻辑。
static func cancel(game) -> bool:
	var entry = armed_entry(game)
	if entry.empty():
		return false
	return game.POWERUPS._recall_armed(game, entry["type"])
