extends SceneTree

# Unit tests for powerups.gd: loadout reset, arm/use/spend flow, recall
# semantics, every activation, and the click-targeted executions (bomb /
# rainbow / warm patch) including frost-ice and rock-shatter interactions.

const POWERUPS = preload("res://scripts/session/powerups.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubTimer:
	var stopped := 0
	var started := 0
	var wait_time := 0.0
	func stop():
		stopped += 1
	func start():
		started += 1

class StubAudio:
	var events := []
	func play_select():
		events.append("select")
	func play_hint():
		events.append("hint")
	func play_shuffle():
		events.append("shuffle")
	func play_button_click():
		events.append("click")
	func play_eliminate_combo(_combo):
		events.append("eliminate")
	func played(what):
		return events.has(what)

class StubEngine:
	func is_rock_value(value):
		return int(value) == 99

class FakeGame extends Reference:
	const STATUS_PLAYING = "playing"
	var audio = StubAudio.new()
	var BOARD_ENGINE = StubEngine.new()
	var stage_status = "playing"
	var special_mode = ""
	var level = {"id": 1, "mode": "classic"}
	var power_ups = {}
	var bomb_pending = false
	var rainbow_pending = false
	var frost_pending = false
	var frost_uses = 0
	var time_frozen = false
	var time_freeze_timer = StubTimer.new()
	var time_left = 30
	var board = [[1, 2, 3], [4, 5, 6], [7, 8, 1]]
	var board_armor = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
	var selected = Vector2(-1, -1)
	var hint_tiles = []
	var error_tiles = []
	var moves = 0
	var combo = 0
	var memory_revealed = {}
	var tuning = {"base_score": 10}
	var messages = []
	var paths_shown = 0
	var pops = []
	var chains_broken = 0
	var consumed_moves = 0
	var resolves = 0
	var refreshes = 0
	var board_refreshes = 0
	var effects = []
	var activations = []
	var reshuffles = 0
	var hint_calls = 0
	func _is_special_session():
		return special_mode != ""
	func _is_memory_mode():
		return special_mode == "memory"
	func _is_frost_mode():
		return special_mode == "frost"
	func _is_rock_mode():
		return special_mode == "rock"
	func _is_target_mode():
		return special_mode == "target"
	func _memory_key(coord):
		return "%d_%d" % [int(coord.x), int(coord.y)]
	func _find_any_hint(working):
		# Answers from the caller's working copy: a cleared corner means the
		# previous pair was consumed by the magnifier loop.
		hint_calls += 1
		if int(working[0][0]) == 0:
			return {}
		if hint_calls == 1:
			return {"a": Vector2(0, 0), "b": Vector2(0, 1), "path": []}
		return {}
	func _is_coord_playable(point):
		return int(board[point.x][point.y]) != 0
	func _show_message(msg, _dur):
		messages.append(msg)
	func _show_path(_path, _kind, _ms):
		paths_shown += 1
	func _board_edge_path(a, _b):
		return [[int(a.x), int(a.y)]]
	func _play_eliminate_effects(tiles):
		effects.append(tiles)
	func _apply_combo_gain(base):
		combo += 1
		return {"gain": int(base)}
	func _pop_stack_at(coord):
		pops.append(coord)
	func _break_chains_around(_tiles):
		chains_broken += 1
	func _consume_move():
		consumed_moves += 1
	func _refresh_ui():
		refreshes += 1
	func _refresh_board_visuals():
		board_refreshes += 1
	func _animate_select(_point):
		pass
	func _animate_hint_tiles(_tiles):
		pass
	func _try_get_tile_button(_coord):
		return null
	func _reshuffle_board(_b):
		reshuffles += 1
	func _on_tile_pressed(_button):
		pass
	func _resolve_after_board_changed():
		resolves += 1
	func _activate_time_freeze():
		activations.append("time_freeze")
	func _activate_bomb():
		activations.append("bomb")
	func _activate_rainbow():
		activations.append("rainbow")
	func _activate_warm_patch():
		activations.append("warm_patch")
	func _activate_time_sand():
		activations.append("time_sand")

func _init() -> void:
	print("== powerups_test")

	# --- loadout reset: real loadout table, pending flags cleared
	var game = FakeGame.new()
	POWERUPS._init_power_ups(game, {"id": 1, "mode": "classic"})
	check(not game.power_ups.empty() and game.bomb_pending == false \
		and game.rainbow_pending == false and game.frost_pending == false \
		and game.frost_uses == 0, "level start resets loadout and pending flags")

	# --- use: budget, state gate, mode restrictions
	game = FakeGame.new()
	game.power_ups = {"bomb": 0}
	POWERUPS._use_power_up(game, "bomb")
	check(game.activations.empty(), "a depleted power-up never activates")
	game.power_ups = {"bomb": 1}
	game.stage_status = "paused"
	POWERUPS._use_power_up(game, "bomb")
	check(game.activations.empty(), "a paused stage never activates")
	game.stage_status = "playing"
	POWERUPS._use_power_up(game, "bomb")
	check(game.activations == ["bomb"] and game.power_ups["bomb"] == 0 \
		and game.refreshes == 1 and game.audio.played("click"),
		"an armed-able power-up activates, spends and refreshes")
	game = FakeGame.new()
	game.special_mode = "endless"
	game.power_ups = {"time_sand": 1}
	POWERUPS._use_power_up(game, "time_sand")
	check(game.messages[0].find("无尽模式") != -1, "time sand is refused in endless")
	game = FakeGame.new()
	game.power_ups = {"warm_patch": 1}
	POWERUPS._use_power_up(game, "warm_patch")
	check(game.messages[0].find("冰雪模式") != -1, "warm patch is refused outside frost")

	# --- recall: re-press refunds an armed click-targeted power-up
	game = FakeGame.new()
	game.power_ups = {"bomb": 1}
	POWERUPS._activate_bomb(game)
	check(game.bomb_pending and game.selected == Vector2(-1, -1), "arming the bomb clears the selection")
	POWERUPS._use_power_up(game, "bomb")
	check(game.bomb_pending == false and game.power_ups["bomb"] == 2 \
		and game.messages.back().find("已收回") != -1, "re-pressing recalls and refunds")
	game = FakeGame.new()
	game.power_ups = {"rainbow": 1}
	game.selected = Vector2(0, 1)
	POWERUPS._activate_rainbow(game)
	check(game.rainbow_pending and game.selected == Vector2(-1, -1), "arming the rainbow clears the selection")
	POWERUPS._use_power_up(game, "rainbow")
	check(game.power_ups["rainbow"] == 2, "the rainbow recall refunds too")
	game = FakeGame.new()
	game.power_ups = {"bomb": 1}
	check(POWERUPS._recall_armed(game, "bomb") == false, "recall only fires on an armed type")

	# --- activations
	game = FakeGame.new()
	POWERUPS._activate_time_freeze(game)
	check(game.time_frozen and game.time_freeze_timer.started == 1, "time freeze stops and restarts the timer")
	game = FakeGame.new()
	POWERUPS._activate_time_sand(game)
	check(game.time_left == 45, "time sand adds 15 seconds")
	game.time_left = 990
	POWERUPS._activate_time_sand(game)
	check(game.time_left == 999, "time sand is capped at 999")
	game = FakeGame.new()
	game.hint_tiles = [Vector2(0, 0)]
	POWERUPS._activate_bomb(game)
	check(game.bomb_pending and game.hint_tiles.empty() and game.rainbow_pending == false \
		and game.frost_pending == false, "arming one click-target disarms the others")

	# --- magnifier highlights up to three pairs
	game = FakeGame.new()
	POWERUPS._activate_magnifier(game)
	check(game.hint_tiles.size() == 2, "the magnifier highlights the first connectable pair")
	game = FakeGame.new()
	game.special_mode = "memory"
	POWERUPS._activate_magnifier(game)
	check(game.memory_revealed.size() == 2, "memory-mode magnifier flips the faces")
	game = FakeGame.new()
	game.board = [[0, 0], [0, 0]]
	POWERUPS._activate_magnifier(game)
	check(game.messages[0].find("没有") != -1, "an empty board gets the magnifier excuse")

	# --- warm patch execution
	game = FakeGame.new()
	game.special_mode = "frost"
	game.frost_pending = true
	game.board_armor = [[5, 0], [0, 0]]
	POWERUPS._execute_warm_patch(game, Vector2(0, 1))
	check(game.frost_pending and game.messages[0].find("没有结冰") != -1,
		"a misclick on bare tile keeps the patch armed")
	POWERUPS._execute_warm_patch(game, Vector2(0, 0))
	check(game.frost_uses == 1 and game.board_armor[0][0] == 0 \
		and game.audio.played("hint"), "an ice hit thaws and counts the use")

	# --- bomb execution
	game = FakeGame.new()
	game.power_ups = {"bomb": 1}
	game.board = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]  # no second "1" anywhere
	POWERUPS._execute_bomb(game, Vector2(0, 0))
	check(game.power_ups["bomb"] == 1 and game.messages[0].find("退回") != -1,
		"a partnerless bomb refunds its charge")
	game = FakeGame.new()
	game.bomb_pending = true
	POWERUPS._execute_bomb(game, Vector2(0, 0))
	check(game.board[0][0] == 0 and game.board[2][2] == 0 and game.moves == 1 \
		and game.combo == 1 and game.resolves == 1 and game.bomb_pending == false,
		"a bomb wipes the clicked tile and its kind partner")
	check(game.pops == [Vector2(0, 0), Vector2(2, 2)] and game.chains_broken == 1 \
		and game.consumed_moves == 1 and game.paths_shown == 1,
		"the shared destruction runs stacks, chains, move and resolve")
	game = FakeGame.new()
	game.special_mode = "frost"
	game.board_armor = [[3, 0, 0], [0, 0, 0], [0, 0, 7]]
	POWERUPS._execute_bomb(game, Vector2(0, 0))
	check(game.board_armor[0][0] == 0 and game.board_armor[2][2] == 0,
		"bombs pierce frost ice on both tiles")
	game = FakeGame.new()
	game.special_mode = "rock"
	game.board = [[1, 99, 3], [4, 5, 6], [7, 8, 1]]
	POWERUPS._execute_bomb(game, Vector2(0, 0))
	check(game.board[0][1] == 0, "a bomb shatters the adjacent rocks")
	game = FakeGame.new()
	POWERUPS._execute_bomb(game, Vector2(0, 0))
	check(game.board[0][1] == 2, "outside rock mode nothing shatters")

	# --- rainbow execution
	game = FakeGame.new()
	game.rainbow_pending = true
	POWERUPS._execute_rainbow_click(game, Vector2(0, 0))
	check(game.selected == Vector2(0, 0) and game.audio.played("select"),
		"the rainbow's first click only selects")
	POWERUPS._execute_rainbow_click(game, Vector2(0, 0))
	check(game.selected == Vector2(-1, -1) and game.rainbow_pending,
		"re-clicking the same tile just deselects")
	POWERUPS._execute_rainbow_click(game, Vector2(0, 1))
	check(game.board[0][0] == 0 and game.board[0][1] == 0 and game.resolves == 1 \
		and game.audio.played("eliminate"),
		"different patterns clear together under the rainbow")

	if failures == 0:
		print("powerups_test: ALL PASSED")
		quit(0)
	else:
		print("powerups_test: %d FAILURES" % failures)
		quit(1)
