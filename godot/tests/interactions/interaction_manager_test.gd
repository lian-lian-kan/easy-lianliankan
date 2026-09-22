extends SceneTree

# Unit tests for the interactions module: registry invariants (handler table
# matches the registry, phases/prompts well-formed, armed rows complete),
# press routing priority (armed power targeting > memory pick > pair select),
# the multi-phase model (pair select / rainbow targeting phases), per-phase
# prompts, press gating, drag-consumed guard, reset and armed cancel —
# through a fake game node (audio/mechanics/powerups stubbed).

const INTERACTIONS = preload("res://scripts/interactions/interaction_manager.gd")
const REGISTRY = preload("res://scripts/interactions/interaction_registry.gd")
const POWERUPS = preload("res://scripts/session/powerups.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubAudio:
	var events := []
	func play_select():
		events.append("select")
	func play_error():
		events.append("error")
	func play_shuffle():
		events.append("shuffle")
	func play_eliminate_combo(_combo):
		events.append("eliminate")
	func played(what):
		return events.has(what)

class StubMechanics:
	var rock_mode := false
	var defused := 0
	func defuse_pair(_game, _a, _b):
		defused += 1
	func is_rock(_game, _point):
		return rock_mode

class StubOverlay:
	var cleared := 0
	func clear_path():
		cleared += 1

func tile_button(r, c):
	var btn = Reference.new()
	btn.set_meta("row", r)
	btn.set_meta("col", c)
	return btn

# Dictionary == 在 GDScript 3 是引用比较，阶段断言逐键比。
func phase_is(game, id, phase) -> bool:
	var info = INTERACTIONS.current_phase(game)
	return info.get("id", "") == id and info.get("phase", "") == phase

func prompt_count(game, needle) -> int:
	var hits = 0
	for msg in game.messages:
		if msg.find(needle) >= 0:
			hits += 1
	return hits

class FakeGame extends Reference:
	const STATUS_PLAYING = "playing"
	const POWERUPS = preload("res://scripts/session/powerups.gd")
	const DRAG_CHAIN = preload("res://scripts/modes/drag_chain.gd")
	var audio = StubAudio.new()
	var BOARD_MECHANICS = StubMechanics.new()
	var path_overlay = StubOverlay.new()
	var stage_status = "playing"
	var special_mode = ""
	var board = [[1, 2], [2, 1]]
	var selected = Vector2(-1, -1)
	var hint_tiles = []
	var error_tiles = []
	var moves = 0
	var combo = 0
	var tuning = {"base_score": 10, "path_preview_ms": 10}
	var target_pair = [Vector2(-1, -1), Vector2(-1, -1)]
	var frost_pending = false
	var frost_uses = 0
	var bomb_pending = false
	var rainbow_pending = false
	var drag_active = false
	var drag_chain = []
	var drag_consumed = false
	var memory_previewing = false
	var memory_lock = false
	var memory_revealed = {}
	var power_ups = {"bomb": 2, "rainbow": 1}
	var playable = true
	var messages = []
	var paths_shown = []
	var bombs = []
	var consumed_moves = 0
	var resolves = 0
	func _is_memory_mode():
		return special_mode == "memory"
	func _is_drag_mode():
		return special_mode == "drag"
	func _is_target_mode():
		return false
	func _is_duel_mode():
		return false
	func _is_slide_mode():
		return false
	func _is_defense_mode():
		return false
	func _is_frost_mode():
		return false
	func _is_rock_mode():
		return false
	func _is_sum_mode():
		return false
	func _is_edu_mode():
		return false
	func _is_coord_playable(_point):
		return playable
	func _is_fogged(_point):
		return false
	func _values_match(a, b):
		return int(a) == int(b)
	func _find_path(_board, _a, _b):
		return [[0, 0], [0, 1]]
	func _board_edge_path(_a, _b):
		return []
	func _memory_key(coord):
		return "%d_%d" % [int(coord.x), int(coord.y)]
	func _memory_schedule_hide(_coords, _delay):
		pass
	func _show_message(msg, _dur):
		messages.append(str(msg))
	func _register_perfect_miss():
		pass
	func _show_path(path, _kind, _ms):
		paths_shown.append(path)
	func _play_eliminate_effects(_tiles):
		pass
	func _animate_select(_point):
		pass
	func _flash_error_tiles(_tiles):
		pass
	func _refresh_board_visuals():
		pass
	func _refresh_ui():
		pass
	func _apply_combo_gain(base):
		combo += 1
		return {"gain": int(base)}
	func _apply_match_damage(_a, _b):
		pass
	func _on_collect_pair_progress(_patterns):
		pass
	func _consume_move():
		consumed_moves += 1
	func _pop_stack_at(_coord):
		pass
	func _break_chains_around(_coords):
		pass
	func _resolve_after_board_changed():
		resolves += 1
	# 执行薄壳：与 game.gd 同名薄壳同签名，记录调用即可。
	func _execute_bomb(point):
		bombs.append(point)
		bomb_pending = false
	func _execute_warm_patch(_point):
		frost_pending = false
	func _execute_rainbow_click(point):
		POWERUPS._execute_rainbow_click(self, point)

func _init() -> void:
	print("== interaction_manager_test")
	_check_registry()
	_check_routing()
	_check_pair_phases()
	_check_rainbow_phases()
	_check_gates()
	_check_lifecycle()
	print("== done: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(1 if failures > 0 else 0)

# --- 注册表不变量：handler 表、阶段表、armed 行、路由顺序 ---

func _check_registry() -> void:
	# 局部表引用：避免 REGISTRY.REGISTRY.<fn>() 被跨模块审计误读为别名调用。
	var table = REGISTRY.REGISTRY
	var ids = table.keys()
	check(ids.size() == INTERACTIONS.HANDLERS.size(), "registry and handler table agree in size")
	for id in INTERACTIONS.HANDLERS.keys():
		check(table.has(id), "handler %s is registered" % id)
		check(INTERACTIONS.HANDLERS[id] != null, "handler for %s is wired" % id)
	for id in ids:
		var row = table[id]
		check(row.has("label") and str(row["label"]) != "", "%s has a label" % id)
		check(row.has("priority"), "%s has a priority" % id)
		check(row.has("phases") and row["phases"].size() > 0, "%s declares phases" % id)
		var prompts = row.get("phase_prompts", {})
		for phase in prompts:
			check(row["phases"].has(phase), "%s prompt targets a declared phase (%s)" % [id, phase])
		for gesture in row["gestures"]:
			check(gesture == REGISTRY.GESTURE_PRESS or gesture == REGISTRY.GESTURE_DRAG, "%s gesture known" % id)
		for entry in row.get("armed", []):
			check(entry.has("flag") and entry.has("type") and entry.has("executor"), "%s armed row complete" % id)
	# 路由顺序必须按优先级降序。
	var order = INTERACTIONS.route_order()
	var in_order = true
	for i in range(1, order.size()):
		if int(table[order[i - 1]]["priority"]) < int(table[order[i]]["priority"]):
			in_order = false
	check(in_order, "route order is priority-descending")
	check(order[0] == REGISTRY.POWER_TARGET, "armed targeting outranks mode interactions")
	# 注册表的 armed 道具类型必须都能在道具域找到武装旗标（防漂移）。
	for entry in table[REGISTRY.POWER_TARGET]["armed"]:
		check(POWERUPS.ARMED_FLAG_BY_TYPE.has(entry["type"]), "armed type %s exists in powerups" % entry["type"])
		check(POWERUPS.ARMED_FLAG_BY_TYPE[entry["type"]] == entry["flag"], "armed flag for %s matches powerups" % entry["type"])

# --- 路由优先级与门槛 ---

func _check_routing() -> void:
	var game = FakeGame.new()
	# armed 炸弹压过选牌：单击交给炸弹执行薄壳，选牌状态不动。
	game.bomb_pending = true
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 0))
	check(game.bombs == [Vector2(0, 0)], "armed bomb takes over the click")
	check(game.selected == Vector2(-1, -1) and game.moves == 0, "armed click never touches pair selection")
	check(not game.drag_consumed, "armed click consumes nothing else")
	# 无武装时默认走经典选牌：第一击选中，阶段进入配对段。
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 0))
	check(game.selected == Vector2(0, 0), "default click selects the tile")
	check(phase_is(game, "pair_select", "resolve_pair"), "phase advances to resolve_pair")
	# 盲盒模式路由到 memory_pick。
	var mem = FakeGame.new()
	mem.special_mode = "memory"
	INTERACTIONS.on_tile_pressed(mem, tile_button(1, 1))
	check(mem.selected == Vector2(1, 1) and mem.memory_revealed.has("1_1"), "memory mode routes to memory_pick")
	check(phase_is(mem, "memory_pick", "resolve_pair"), "memory phase advances")
	# drag_consumed 守卫：吞掉这次单击并自清。
	var guarded = FakeGame.new()
	guarded.drag_consumed = true
	INTERACTIONS.on_tile_pressed(guarded, tile_button(0, 0))
	check(not guarded.drag_consumed and guarded.selected == Vector2(-1, -1), "drag_consumed swallows exactly one press")
	# 连线消会话：手势段走 drag 通道；单张轻点落回经典选牌流。
	var drag = FakeGame.new()
	drag.special_mode = "drag"
	check(phase_is(drag, "drag_link", "press"), "drag session reports the gesture phase")
	INTERACTIONS.on_tile_button_down(drag, tile_button(0, 0))
	check(drag.drag_active and phase_is(drag, "drag_link", "extend"), "press arms the chain and advances the phase")
	INTERACTIONS.on_tile_button_up(drag, tile_button(0, 0))
	check(not drag.drag_active and not drag.drag_consumed, "single-tile release stays in the click flow")
	INTERACTIONS.on_tile_pressed(drag, tile_button(0, 0))
	check(drag.selected == Vector2(0, 0), "lone tap falls through to classic select")

func _check_pair_phases() -> void:
	var game = FakeGame.new()
	check(phase_is(game, "pair_select", "select_first"), "fresh board sits in select_first")
	# 错配：走拒绝路径，选中换到新牌，步数+1。
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 0))
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 1))
	check(game.selected == Vector2(0, 1), "mismatch moves selection to the new tile")
	check(game.moves == 1 and game.audio.played("error"), "mismatch costs a move and plays error")
	# 配对成功：走消除核心，步数消耗、结算进一次。
	var win = FakeGame.new()
	INTERACTIONS.on_tile_pressed(win, tile_button(0, 0))
	INTERACTIONS.on_tile_pressed(win, tile_button(1, 1))
	check(win.selected == Vector2(-1, -1), "match clears the selection")
	check(win.consumed_moves == 1 and win.resolves == 1, "match consumes a move and resolves")
	check(win.BOARD_MECHANICS.defused == 1, "match runs the defuse hook")
	check(win.audio.played("eliminate"), "match plays eliminate audio")

func _check_rainbow_phases() -> void:
	var game = FakeGame.new()
	game.board = [[1, 2], [3, 4]]
	game.rainbow_pending = true
	check(phase_is(game, "power_target", "targeting"), "armed rainbow sits in targeting")
	# 第一击：收下第一块，交互仍武装，进入 pick_second 并播阶段提示。
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 0))
	check(game.selected == Vector2(0, 0) and game.rainbow_pending, "first rainbow pick keeps it armed")
	check(INTERACTIONS.current_phase(game)["phase"] == REGISTRY.PHASE_PICK_SECOND, "phase advances to pick_second")
	check(prompt_count(game, "再点一块") == 1, "pick_second phase prompt is shown")
	# 第二击（不同图案）：结算并解除武装，不再有阶段提示。
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 1))
	check(not game.rainbow_pending, "second rainbow pick resolves and disarms")
	check(int(game.board[0][0]) == 0 and int(game.board[0][1]) == 0, "rainbow clears both picked tiles")
	check(prompt_count(game, "再点一块") == 1, "no phase prompt after the interaction ends")

func _check_gates() -> void:
	var game = FakeGame.new()
	game.stage_status = "paused"
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 0))
	check(game.selected == Vector2(-1, -1), "presses are ignored while paused")
	game.stage_status = "playing"
	game.board[0][0] = 0
	INTERACTIONS.on_tile_pressed(game, tile_button(0, 0))
	check(game.selected == Vector2(-1, -1), "empty cells never route")
	# 石头牌：机制层拒绝并提示（不路由到任何交互）。
	var rocky = FakeGame.new()
	rocky.playable = false
	rocky.BOARD_MECHANICS.rock_mode = true
	INTERACTIONS.on_tile_pressed(rocky, tile_button(0, 0))
	check(rocky.selected == Vector2(-1, -1), "rock tiles never route")
	var rock_warned := false
	for msg in rocky.messages:
		if msg.find("石头牌") >= 0:
			rock_warned = true
	check(rock_warned, "rock tiles get the mechanism hint")

func _check_lifecycle() -> void:
	var game = FakeGame.new()
	game.hint_tiles = [Vector2(0, 0)]
	game.error_tiles = [Vector2(0, 1)]
	game.selected = Vector2(1, 1)
	game.bomb_pending = true
	game.frost_pending = true
	game.rainbow_pending = true
	INTERACTIONS.reset(game)
	check(not game.bomb_pending and not game.rainbow_pending and not game.frost_pending, "reset disarms every armed flag")
	check(game.selected == Vector2(-1, -1) and game.hint_tiles.empty() and game.error_tiles.empty(), "reset clears selection and highlights")
	check(game.path_overlay.cleared == 1, "reset clears the path overlay")
	# cancel_armed：转管道具域收回逻辑，退费一次。
	var armed = FakeGame.new()
	armed.bomb_pending = true
	armed.power_ups["bomb"] = 0
	check(INTERACTIONS.cancel_armed(armed), "cancel_armed reports a recall")
	check(not armed.bomb_pending and int(armed.power_ups["bomb"]) == 1, "cancel_armed refunds the charge")
	var idle = FakeGame.new()
	check(not INTERACTIONS.cancel_armed(idle), "cancel_armed is inert without an armed power")
