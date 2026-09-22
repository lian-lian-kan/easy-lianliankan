extends Reference

# 交互管理器：棋盘手势的单一入口与多阶段调度中枢（interactions/ 域的
# 门面，game.gd 与 game_input 的薄壳都落到这里）。
#
# 职责：
#   1. 路由——按注册表优先级把棋盘单击交给当前交互：武装中的道具瞄准
#      压过模式交互（盲盒翻牌 > 经典选牌为默认）；连线消手势走独立的
#      down/entered/up 通道。
#   2. 阶段——current_interaction/current_phase 暴露「玩家正处在哪类
#      交互的哪一段」（引导/HUD 可订阅）；一次手势推一段之后自动播出
#      注册表配置的阶段提示（无配置则静默，行为不变）。
#   3. 生命周期——reset 集中清交互草稿态（session 重置关卡时调用）；
#      cancel_armed 统一收回武装并退费。
#
# 新增交互：interaction_registry.gd 加登记行 → 实现 handler（wants_press
# / phase / on_press）→ HANDLERS 挂表。跨模块调用只走 game.* 别名。

const REGISTRY_SCRIPT = preload("res://scripts/interactions/interaction_registry.gd")
const POWER_TARGET = preload("res://scripts/interactions/power_target.gd")
const PAIR_SELECT = preload("res://scripts/interactions/pair_select.gd")
const MEMORY_PICK = preload("res://scripts/interactions/memory_pick.gd")
const DRAG_LINK = preload("res://scripts/interactions/drag_link.gd")

# 交互 id → handler 脚本。键与注册表的 id 常量一一对应（测试锁齐）。
const HANDLERS = {
	"power_target": POWER_TARGET,
	"pair_select": PAIR_SELECT,
	"memory_pick": MEMORY_PICK,
	"drag_link": DRAG_LINK,
}

# —— 事件入口（game.gd / GAME_INPUT 薄壳落到这里） ——

static func on_tile_pressed(game, button):
	# 连线消: a chain release that landed on the start button already consumed
	# the gesture; swallow the trailing `pressed` emission.
	if game.get("drag_consumed"):
		game.drag_consumed = false
		return
	if not press_valid(game, button):
		return
	var point = Vector2(int(button.get_meta("row")), int(button.get_meta("col")))
	press_handler(game).on_press(game, point)
	show_phase_prompt(game)

# 盲盒翻牌的既有入口（game.gd 薄壳签名保留 row/col，路由按格子坐标）。
static func memory_press(game, point):
	if not game._is_memory_mode():
		return
	MEMORY_PICK.on_press(game, point)

static func on_tile_button_down(game, button):
	DRAG_LINK.on_button_down(game, button)

static func on_tile_mouse_entered(game, button):
	DRAG_LINK.on_mouse_entered(game, button)

static func on_tile_button_up(game, button):
	DRAG_LINK.on_button_up(game, button)

# —— 路由 ——

# 路由顺序：priority 降序（并列按登记顺序），armed 瞄准永远在前。
static func route_order():
	var remaining = []
	for id in HANDLERS:
		remaining.append(id)
	var ordered = []
	while remaining.size() > 0:
		var best = remaining[0]
		for id in remaining:
			if int(REGISTRY_SCRIPT.REGISTRY[id]["priority"]) > int(REGISTRY_SCRIPT.REGISTRY[best]["priority"]):
				best = id
		remaining.erase(best)
		ordered.append(best)
	return ordered

# 该接管这次单击的交互：第一个 wants_press 的 handler，默认经典选牌。
static func press_handler(game):
	for id in route_order():
		if HANDLERS[id].wants_press(game):
			return HANDLERS[id]
	return PAIR_SELECT

# Gate every tile click: playing state, real tile, and mechanism playability.
static func press_valid(game, button) -> bool:
	if game.stage_status != game.STATUS_PLAYING:
		return false
	if button == null:
		return false
	var r = int(button.get_meta("row"))
	var c = int(button.get_meta("col"))
	if game.board[r][c] == 0:
		return false
	var point = Vector2(r, c)
	if not game._is_coord_playable(point):
		if game.BOARD_MECHANICS.is_rock(game, point):
			game._show_message("🪨 石头牌消不掉，用 💣 炸开或绕过去", 1.0)
		elif game._is_fogged(point):
			game._show_message("迷雾遮住了这块，先消除里面的方块", 1.0)
		else:
			game._show_message("⛓️ 先消除它旁边的方块来解锁", 1.0)
		return false
	return true

# —— 阶段查询与提示 ——

# 玩家当前所处的交互 id（无交互活跃时返回 ""）。
static func current_interaction(game):
	for id in route_order():
		if HANDLERS[id].phase(game) != "":
			return id
	return ""

# 玩家当前所处的交互与阶段：{"id", "phase"}；无活跃交互时 {}。
static func current_phase(game):
	for id in route_order():
		var phase = HANDLERS[id].phase(game)
		if phase != "":
			return {"id": id, "phase": phase}
	return {}

# 注册表里某交互某阶段的提示配置（未配置返回 {}）。
static func phase_prompt(interaction_id, phase):
	var prompts = REGISTRY_SCRIPT.REGISTRY[interaction_id].get("phase_prompts", {})
	return prompts.get(phase, {})

# 段推进后调用：交互仍活跃且注册表给当前段配了文案则播出。
static func show_phase_prompt(game):
	var info = current_phase(game)
	if info.empty():
		return
	var prompt = phase_prompt(info["id"], info["phase"])
	if prompt.empty():
		return
	game._show_message(prompt["text"], float(prompt.get("duration", 1.2)))

# —— 生命周期 ——

# 统一收回武装中的瞄准交互（退费走道具域）；无武装返回 false。
static func cancel_armed(game) -> bool:
	return POWER_TARGET.cancel(game)

# Interaction scratch state: nothing armed, no stale highlights or paths.
static func reset(game):
	game.frost_pending = false
	game.frost_uses = 0
	game.bomb_pending = false
	game.rainbow_pending = false
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.path_overlay.clear_path()

# —— 兼容入口（game_input 委托薄壳的目标，既有调用方零改动） ——

static func execute_pair_match(game, path, previous, point):
	PAIR_SELECT._execute_pair_match(game, path, previous, point)
