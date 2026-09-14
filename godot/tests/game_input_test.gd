extends SceneTree

# Unit tests for game_input.gd: tile-press gating, selection toggles (normal
# and memory), the shared match core (with duel/slide/defense hooks), memory
# rejection paths, hint/auto/shuffle/reset/jump flows and the keyboard router
# — through a fake game node (audio/mechanics/engine stubbed).

const GAME_INPUT = preload("res://scripts/session/game_input.gd")

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
	func play_hint():
		events.append("hint")
	func play_shuffle():
		events.append("shuffle")
	func play_eliminate_combo(_combo):
		events.append("eliminate")
	func played(what):
		return events.has(what)

class StubMechanics:
	var defused := []
	func defuse_pair(_game, a, b):
		defused.append([a, b])
	func is_rock(_game, _point):
		return false

class StubEngine:
	var slid := 0
	func slide_random_row(_board):
		slid += 1
		return true

class StubProgression:
	func find_next_unlocked(_state, from_idx, step, size):
		return clamp(int(from_idx) + int(step), 0, int(size) - 1)

class StubOption:
	var count := 3
	var selected := 0
	func get_item_count():
		return count
	func select(i):
		selected = int(i)

func tile_button(r, c):
	var btn = Reference.new()
	btn.set_meta("row", r)
	btn.set_meta("col", c)
	return btn

class FakeGame extends Reference:
	const STATUS_PLAYING = "playing"
	const STATUS_PAUSED = "paused"
	const STATUS_COMPLETED = "completed"
	const STATUS_FAILED = "failed"
	const GAME_INPUT = preload("res://scripts/session/game_input.gd")
	var audio = StubAudio.new()
	var BOARD_MECHANICS = StubMechanics.new()
	var BOARD_ENGINE = StubEngine.new()
	var PROGRESSION_SCRIPT = StubProgression.new()
	var stage_status = "playing"
	var special_mode = ""
	var board = [[1, 2], [2, 1]]
	var selected = Vector2(-1, -1)
	var hint_tiles = [Vector2(0, 0)]
	var error_tiles = [Vector2(0, 0)]
	var combo = 0
	var moves = 0
	var tuning = {}
	var special_level = {"memory_face_up": 1.0}
	var level = {"time_limit": 60, "defense_start": 5, "defense_step": 12}
	var target_pair = [Vector2(-1, -1), Vector2(-1, -1)]
	var frost_pending = false
	var bomb_pending = false
	var rainbow_pending = false
	var duel_current = 0
	var duel_scores = [0, 0]
	var defense_distance = 0
	var defense_countdown = 0
	var memory_previewing = false
	var memory_lock = false
	var memory_revealed = {}
	var level_index = 1
	var level_hints_used = 0
	var level_auto_used = 0
	var progression_state = {}
	var unlocked_levels = [0, 1, 2]
	var selected_level_option = 1
	var level_select_option = StubOption.new()
	var path_blocked = false
	var remaining = 2
	var campaign_levels = [1, 2, 3]
	var hint = {"a": Vector2(0, 0), "b": Vector2(1, 1), "path": [[0, 0]]}
	var messages = []
	var paths_shown = []
	var damage_calls = []
	var tile_damages = []
	var collect_calls = []
	var flashes = []
	var selects_animated = []
	var consumed_moves = 0
	var time_costs = []
	var resolves = 0
	var perfect_misses = 0
	var started_levels = []
	var special_restarts = 0
	var pauses = 0
	var resumes = 0
	var power_ups_used = []
	var warm_patches = []
	var bombs = []
	var rainbows = []
	var reshuffles = 0
	func _is_special_session():
		return special_mode != ""
	func _is_memory_mode():
		return special_mode == "memory"
	func _is_sum_mode():
		return special_mode == "sum10"
	func _is_target_mode():
		return special_mode == "target"
	func _is_duel_mode():
		return special_mode == "duel"
	func _is_slide_mode():
		return special_mode == "slide"
	func _is_defense_mode():
		return special_mode == "defense"
	func _is_fogged(_point):
		return false
	func _values_match(a, b):
		return int(a) == int(b)
	func _current_level():
		return level
	func _find_path(_board, _a, _point):
		return [] if path_blocked else [[0, 0], [0, 1]]
	func _is_coord_playable(_point):
		return true
	func _is_level_unlocked(i):
		return unlocked_levels.has(int(i))
	func _selected_level_option_index():
		return int(selected_level_option)
	func _memory_key(coord):
		return "%d_%d" % [int(coord.x), int(coord.y)]
	func _find_any_hint(_board):
		return hint
	# Keyboard routes through the game's own thin shells, exactly like the
	# real composition root — the fakes delegate back into GAME_INPUT.
	func _on_pause_pressed():
		GAME_INPUT._on_pause_pressed(self)
	func _on_hint_pressed():
		GAME_INPUT._on_hint_pressed(self)
	func _on_shuffle_pressed():
		GAME_INPUT._on_shuffle_pressed(self)
	func _show_message(msg, _dur):
		messages.append(msg)
	func _show_path(path, _kind, _ms):
		paths_shown.append(path)
	func _play_eliminate_effects(_tiles):
		pass
	func _animate_select(point):
		selects_animated.append(point)
	func _flash_error_tiles(tiles):
		flashes.append(tiles)
	func _animate_hint_tiles(_tiles):
		pass
	func _refresh_board_visuals():
		pass
	func _refresh_ui():
		pass
	func _register_perfect_miss():
		perfect_misses += 1
	func _apply_combo_gain(base):
		combo += 1
		return {"gain": int(base)}
	func _apply_match_damage(a, b):
		damage_calls.append([a, b])
	func _on_collect_pair_progress(patterns):
		collect_calls.append(patterns)
	func _consume_move():
		consumed_moves += 1
	func _consume_time_cost(seconds):
		time_costs.append(int(seconds))
	func _resolve_after_board_changed():
		resolves += 1
	func _pick_target_pair():
		target_pair = [Vector2(0, 0), Vector2(1, 1)]
	func _use_power_up(power_up_type):
		power_ups_used.append(power_up_type)
	func _pause_stage():
		pauses += 1
	func _resume_stage():
		resumes += 1
	func _start_level(index, reset_total):
		started_levels.append([int(index), bool(reset_total)])
	func _start_special_mode(mode_id):
		special_restarts += 1
		special_mode = mode_id
	func _sync_level_select_selection():
		pass
	func _level_label_by_index(i):
		return "第%d关" % int(i)
	func _trigger_level_highlight():
		pass
	func accept_event():
		pass
	func _memory_schedule_hide(_coords, _delay):
		pass
	func _damage_tile(coord, cracked, removed):
		tile_damages.append(coord)
		cracked.append(coord)
		removed.append(coord)
	func _break_chains_around(_removed):
		pass
	func _remaining_tiles_count():
		return int(remaining)
	func _animate_shuffle_wave():
		pass
	func _reshuffle_board(_board):
		reshuffles += 1
	func _spawn_board_particles(_n, _color, _dur):
		pass
	func _execute_warm_patch(point):
		warm_patches.append(point)
	func _execute_bomb(point):
		bombs.append(point)
	func _execute_rainbow_click(point):
		rainbows.append(point)

func key_event(scancode):
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.scancode = scancode
	return ev

func _init() -> void:
	print("== game_input_test")

	# --- press gating: only a playing-state click on a live tile counts
	var game = FakeGame.new()
	game.stage_status = FakeGame.STATUS_PAUSED
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	check(game.moves == 0 and not game.audio.played("select"), "a paused stage ignores tile presses")
	game = FakeGame.new()
	game.board = [[1, 0], [2, 1]]
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 1))
	check(game.selected.x < 0 and game.moves == 0, "a cleared cell ignores presses")

	# --- armed click-targeted power-ups take over the click
	game = FakeGame.new()
	game.bomb_pending = true
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	check(game.bombs == [Vector2(0, 0)] and game.moves == 0, "an armed bomb intercepts the click")
	game = FakeGame.new()
	game.frost_pending = true
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 1))
	check(game.warm_patches == [Vector2(0, 1)], "an armed warm patch intercepts the click")

	# --- selection toggles
	game = FakeGame.new()
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	check(game.selected == Vector2(0, 0) and game.audio.played("select"), "the first press selects a tile")
	check(game.hint_tiles.empty() and game.error_tiles.empty(), "selecting clears stale highlights")
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	check(game.selected == Vector2(-1, -1), "re-clicking the selection deselects")

	# --- mismatch rejection
	game = FakeGame.new()
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 1))
	check(game.moves == 1, "a rejected pair still spends the move")
	check(game.audio.played("error") and game.perfect_misses == 1, "a rejected pair plays the error path")
	check(game.messages.size() == 1 and game.messages[0].find("请先选择相同图案") != -1, "a plain mismatch explains the rule")
	check(game.selected == Vector2(0, 1), "a rejected pair moves the selection to the new tile")
	game = FakeGame.new()
	game.special_mode = "sum10"
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 1))
	check(game.messages[0].find("合十消") != -1, "sum10 teaches its own rule")
	game = FakeGame.new()
	game.special_mode = "duel"
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 1))
	check(game.duel_current == 1, "a failed duel attempt passes the turn")

	# --- target mode: only the golden pair may clear
	game = FakeGame.new()
	game.special_mode = "target"
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(1, 1))
	check(game.messages[0].find("金光") != -1 and game.resolves == 0, "a non-target pair refuses to clear")

	# --- blocked path
	game = FakeGame.new()
	game.path_blocked = true
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(1, 1))
	check(game.messages[0].find("路径不通") != -1, "a blocked path is explained")

	# --- a real match runs the shared core
	game = FakeGame.new()
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(1, 1))
	check(game.damage_calls == [[Vector2(0, 0), Vector2(1, 1)]], "a match damages the pressed pair")
	check(game.BOARD_MECHANICS.defused.size() == 1, "a match asks mechanics to defuse")
	check(game.collect_calls == [[1, 1]], "a match reports its patterns to the collection")
	check(game.consumed_moves == 1 and game.resolves == 1, "a match spends a move and resolves the board")
	check(game.combo == 1 and game.audio.played("eliminate"), "a match pays out combo score")
	check(game.selected == Vector2(-1, -1), "a match clears the selection")

	# --- mode hooks on the shared core
	game = FakeGame.new()
	game.special_mode = "duel"
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(1, 1))
	check(game.duel_scores == [10, 0], "duel gains land on the current player's board")
	game = FakeGame.new()
	game.special_mode = "slide"
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(1, 1))
	check(game.BOARD_ENGINE.slid == 1, "slide rotates a row per match")
	game = FakeGame.new()
	game.special_mode = "defense"
	GAME_INPUT._on_tile_pressed(game, tile_button(0, 0))
	GAME_INPUT._on_tile_pressed(game, tile_button(1, 1))
	check(game.defense_distance == 1 and game.defense_countdown == 12, "defense pushes the monster back")

	# --- memory mode: face-up tracking through the same toggles
	game = FakeGame.new()
	game.special_mode = "memory"
	game.memory_revealed = {}
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(0, 0), 0, 0)
	check(game.memory_revealed.has("0_0"), "selecting in memory reveals the face")
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(0, 0), 0, 0)
	check(game.selected == Vector2(-1, -1), "re-clicking deselects in memory too")
	game.memory_previewing = true
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(1, 1), 1, 1)
	check(game.moves == 0, "the memory preview locks input")

	# --- memory mismatch reveals both faces and hides them again
	game = FakeGame.new()
	game.special_mode = "memory"
	game.memory_revealed = {}
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(0, 0), 0, 0)
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(0, 1), 0, 1)
	check(game.memory_revealed.has("0_0") and game.memory_revealed.has("0_1"), "a memory mismatch reveals both faces")
	check(game.selected == Vector2(-1, -1), "a memory mismatch clears the selection")

	# --- memory path blocked keeps the new tile selected
	game = FakeGame.new()
	game.special_mode = "memory"
	game.path_blocked = true
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(0, 0), 0, 0)
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(1, 1), 1, 1)
	check(game.selected == Vector2(1, 1) and game.memory_revealed.has("1_1"), "a blocked memory path keeps the new tile")

	# --- memory match erases the revealed faces
	game = FakeGame.new()
	game.special_mode = "memory"
	game.memory_revealed = {"0_0": true, "1_1": true}
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(0, 0), 0, 0)
	GAME_INPUT._on_memory_tile_pressed(game, Vector2(1, 1), 1, 1)
	check(not game.memory_revealed.has("0_0") and not game.memory_revealed.has("1_1"), "a memory match clears both faces")
	check(game.resolves == 1 and game.consumed_moves == 1, "a memory match runs the shared core")

	# --- hint: gated, counted, reveals, and costs time outside memory
	game = FakeGame.new()
	game.stage_status = FakeGame.STATUS_COMPLETED
	GAME_INPUT._on_hint_pressed(game)
	check(game.level_hints_used == 0, "hints only fire while playing")
	game = FakeGame.new()
	GAME_INPUT._on_hint_pressed(game)
	check(game.level_hints_used == 1 and game.audio.played("hint"), "a hint is counted and announced")
	check(game.hint_tiles == [Vector2(0, 0), Vector2(1, 1)], "a hint highlights its pair")
	check(game.time_costs == [1], "a hint costs one second outside memory")
	game = FakeGame.new()
	game.special_mode = "memory"
	GAME_INPUT._on_hint_pressed(game)
	check(game.time_costs.empty() and game.selected == Vector2(-1, -1), "a memory hint stays free and unselected")
	game = FakeGame.new()
	game.hint = {}
	GAME_INPUT._on_hint_pressed(game)
	check(game.reshuffles == 1, "an empty hint reshuffles instead")

	# --- auto: clears the pair outright and costs two seconds while tiles remain
	game = FakeGame.new()
	GAME_INPUT._on_auto_pressed(game)
	check(game.level_auto_used == 1, "auto is counted")
	check(game.tile_damages == [Vector2(0, 0), Vector2(1, 1)] and game.consumed_moves == 1, "auto damages the hint pair for one move")
	check(game.time_costs == [2], "an auto clear that leaves tiles costs two seconds")
	game = FakeGame.new()
	game.remaining = 0
	GAME_INPUT._on_auto_pressed(game)
	check(game.time_costs.empty(), "a board-clearing auto skips the time cost")
	game = FakeGame.new()
	game.hint = {}
	GAME_INPUT._on_auto_pressed(game)
	check(game.reshuffles == 1, "an empty hint reshuffles auto away")

	# --- shuffle: reshuffles and costs one second
	game = FakeGame.new()
	GAME_INPUT._on_shuffle_pressed(game)
	check(game.reshuffles == 1 and game.time_costs == [1], "a shuffle reshuffles and costs one second")

	# --- reset: special restarts, completed restarts the campaign, else replay
	game = FakeGame.new()
	game.special_mode = "frost"
	GAME_INPUT._on_reset_pressed(game)
	check(game.special_restarts == 1, "reset restarts the special session")
	game = FakeGame.new()
	game.stage_status = FakeGame.STATUS_COMPLETED
	GAME_INPUT._on_reset_pressed(game)
	check(game.started_levels == [[0, true]], "reset from the endgame restarts the campaign")
	game = FakeGame.new()
	GAME_INPUT._on_reset_pressed(game)
	check(game.started_levels == [[1, false]], "reset mid-level replays the same level")

	# --- jump: locked targets refuse, unlocked ones start
	game = FakeGame.new()
	game.selected_level_option = 5
	GAME_INPUT._on_jump_level_pressed(game)
	check(game.messages[0].find("尚未解锁") != -1 and game.started_levels.empty(), "a locked jump is refused")
	game = FakeGame.new()
	game.selected_level_option = 2
	GAME_INPUT._on_jump_level_pressed(game)
	check(game.started_levels == [[2, true]], "an unlocked jump starts the level fresh")

	# --- pause toggles with the stage state
	game = FakeGame.new()
	GAME_INPUT._on_pause_pressed(game)
	check(game.pauses == 1 and game.resumes == 0, "pausing a playing stage pauses")
	game.stage_status = FakeGame.STATUS_PAUSED
	GAME_INPUT._on_pause_pressed(game)
	check(game.resumes == 1, "pausing a paused stage resumes")

	# --- bracket keys cycle the level select
	game = FakeGame.new()
	GAME_INPUT._cycle_level_selection(game, 1)
	check(game.level_select_option.selected == 2, "cycling moves to the next unlocked level")

	# --- reveal_hint_pair contract
	game = FakeGame.new()
	check(GAME_INPUT.reveal_hint_pair(game, {}) == false, "an empty hint reveals nothing and returns false")
	game = FakeGame.new()
	check(GAME_INPUT.reveal_hint_pair(game, game.hint) == true, "a real hint reveals and returns true")
	check(game.hint_tiles == [Vector2(0, 0), Vector2(1, 1)], "the revealed pair lands in hint_tiles")

	# --- keyboard router
	check(GAME_INPUT.KEY_ACTIONS.has(KEY_H) and GAME_INPUT.KEY_ACTIONS[KEY_H].get("playing", false), "H is a playing-gated action")
	check(GAME_INPUT.KEY_ACTIONS.has(KEY_P) and not GAME_INPUT.KEY_ACTIONS[KEY_P].get("playing", false), "P works outside play")
	game = FakeGame.new()
	GAME_INPUT._unhandled_input(game, key_event(KEY_P))
	check(game.pauses == 1, "P pauses while playing")
	game = FakeGame.new()
	GAME_INPUT._unhandled_input(game, key_event(KEY_6))
	check(game.power_ups_used == ["bomb"], "6 arms the bomb")
	game = FakeGame.new()
	GAME_INPUT._unhandled_input(game, key_event(KEY_H))
	check(game.level_hints_used == 1, "H hints while playing")
	game.stage_status = FakeGame.STATUS_PAUSED
	GAME_INPUT._unhandled_input(game, key_event(KEY_H))
	check(game.level_hints_used == 1, "H is gated while paused")
	game = FakeGame.new()
	GAME_INPUT._unhandled_input(game, key_event(KEY_Y))
	check(game.pauses == 0 and game.power_ups_used.empty(), "an unmapped key does nothing")

	if failures == 0:
		print("game_input_test: ALL PASSED")
		quit(0)
	else:
		print("game_input_test: %d FAILURES" % failures)
		quit(1)
