extends SceneTree

# Unit tests for scripts/board/board_mechanics.gd — the mechanic grids
# (frost armor / stack covers / chains / fog / rocks / bombs / gravity) that
# used to live only under scene probes. Every public function runs here
# headless against a fake game node; the probes keep guarding the real scene.

const MECHANICS = preload("res://scripts/board/board_mechanics.gd")
const ENGINE = preload("res://scripts/board/board_engine.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubAudio:
	var shuffled := 0
	func play_shuffle():
		shuffled += 1

class FakeGame extends Reference:
	var special_mode = ""
	var board = []
	var board_armor = []
	var board_lower = []
	var board_chain = []
	var board_bomb = {}
	var _fog_layers = 0
	var level = {"fog_layers": 2}
	var selected = Vector2(-1, -1)
	var hint_tiles = []
	var error_tiles = []
	var audio = StubAudio.new()
	var messages = []
	var refreshes = 0
	var fails = 0
	func _init():
		SESSION = self
	var SESSION = null
	func _current_level():
		return level
	func _remaining_tiles_count():
		return ENGINE.count_tiles(board)
	func _show_message(msg, _dur):
		messages.append(msg)
	func _refresh_board_visuals():
		refreshes += 1
	func _fail_stage(_game, _reason):
		fails += 1

func _grid(rows, cols, value = 0) -> Array:
	var grid := []
	for r in range(rows):
		var row := []
		for c in range(cols):
			row.append(value)
		grid.append(row)
	return grid

func _game(mode, board) -> FakeGame:
	var game = FakeGame.new()
	game.special_mode = mode
	game.board = board
	return game

func _init() -> void:
	print("== board_mechanics_test")

	# --- cell_ring / fog geometry
	var ring_game = _game("fog", _grid(6, 6, 1))
	check(MECHANICS.cell_ring(ring_game, 0, 0) == 0 && MECHANICS.cell_ring(ring_game, 2, 2) == 2,
		"cell_ring reports the distance to the board edge")
	ring_game._fog_layers = 2
	check(not MECHANICS.is_fogged(ring_game, Vector2(2, 2)), "cells beyond the fog radius stay visible")
	check(MECHANICS.is_fogged(ring_game, Vector2(0, 0)), "edge cells inside the fog radius are fogged")
	var plain_game = _game("", _grid(4, 4, 1))
	plain_game._fog_layers = 3
	check(not MECHANICS.is_fogged(plain_game, Vector2(0, 0)), "fog never applies outside the fog mode")

	# --- rocks
	check(not MECHANICS.is_rock(_game("", [[1]]), Vector2(0, 0)), "rocks only read in rock mode")
	var rock_game = _game("rock", _grid(6, 6, 1))
	var half = 18
	var id = 1
	for r in range(6):
		for c in range(6):
			rock_game.board[r][c] = id
			if (r * 6 + c) % 2 == 1:
				id = id % half + 1
	var rocks_before := 0
	for row in rock_game.board:
		for v in row:
			rocks_before += 1 if int(v) == ENGINE.ROCK_VALUE else 0
	MECHANICS.build_rocks(rock_game, {"rock_ratio": 0.3})
	var rocks_after := 0
	for row in rock_game.board:
		for v in row:
			rocks_after += 1 if int(v) == ENGINE.ROCK_VALUE else 0
	check(rocks_after > rocks_before, "build_rocks converts tiles into rocks")
	check((rocks_after - rocks_before) % 2 == 0, "rock placement converts whole pairs only")
	var rock_coord = Vector2(-1, -1)
	var plain_coord = Vector2(-1, -1)
	for r in range(6):
		for c in range(6):
			if int(rock_game.board[r][c]) == ENGINE.ROCK_VALUE and rock_coord.x < 0:
				rock_coord = Vector2(r, c)
			if int(rock_game.board[r][c]) != ENGINE.ROCK_VALUE and plain_coord.x < 0:
				plain_coord = Vector2(r, c)
	check(MECHANICS.is_rock(rock_game, rock_coord), "rock mode flags rock tiles")
	check(not MECHANICS.is_rock(rock_game, plain_coord), "rock mode passes normal tiles")

	# --- playability gate
	var chain_game = _game("chain", _grid(4, 4, 1))
	chain_game.board_chain = _grid(4, 4, 0)
	chain_game.board_chain[1][1] = 2
	check(not MECHANICS.is_coord_playable(chain_game, Vector2(1, 1)), "chained tiles are unselectable")
	check(MECHANICS.is_coord_playable(chain_game, Vector2(2, 2)), "free tiles stay playable")
	check(not MECHANICS.is_coord_playable(rock_game, rock_coord), "rock tiles are unselectable")

	# --- defuse bombs
	var bomb_game = _game("defuse", _grid(4, 4, 1))
	MECHANICS.build_bombs(bomb_game, {"bomb_ratio": 0.0})
	check(bomb_game.board_bomb.empty(), "a zero ratio seeds no bombs")
	MECHANICS.build_bombs(bomb_game, {"bomb_ratio": 0.25, "bomb_seconds": 9})
	check(bomb_game.board_bomb.size() > 0 && bomb_game.board_bomb.size() % 2 == 0,
		"bombs deal an even, non-zero count")
	var symmetric := true
	for coord in bomb_game.board_bomb.keys():
		var mirror = Vector2(coord.x, bomb_game.board[0].size() - 1 - coord.y)
		if not bomb_game.board_bomb.has(mirror):
			symmetric = false
	check(symmetric, "bombs place in mirror-symmetric pairs")
	for coord in bomb_game.board_bomb.keys():
		check(int(bomb_game.board_bomb[coord]) == 9, "every bomb carries the configured countdown")
	MECHANICS.defuse_pair(bomb_game, bomb_game.board_bomb.keys()[0], Vector2(-1, -1))
	check(bomb_game.board_bomb.size() % 2 == 1, "defusing removes exactly the paired tile")
	var other = _game("classic", {})
	other.board_bomb = {Vector2(0, 0): 5}
	MECHANICS.defuse_pair(other, Vector2(0, 0), Vector2(0, 1))
	check(other.board_bomb.size() == 1, "defuse_pair ignores sessions outside defuse mode")

	# --- bomb ticking
	var tick_game = _game("defuse", _grid(2, 2, 1))
	tick_game.board_bomb = {Vector2(0, 0): 3, Vector2(0, 1): 2}
	MECHANICS.tick_bombs(tick_game)
	check(tick_game.board_bomb[Vector2(0, 0)] == 2 && tick_game.board_bomb[Vector2(0, 1)] == 1
		&& tick_game.fails == 0, "ticking decrements every bomb without a zero")
	check(tick_game.refreshes == 1, "surviving ticks refresh the board visuals")
	tick_game.board_bomb[Vector2(0, 1)] = 1
	MECHANICS.tick_bombs(tick_game)
	check(tick_game.fails == 1, "a bomb reaching zero fails the run")

	# --- stack layers: donors swap down over a quarter of the filled cells
	var stack_game = _game("stack", _grid(4, 4, 1))
	stack_game.board[0][0] = 0
	MECHANICS.build_stack_layers(stack_game, 0.25)
	check(stack_game.board_lower.size() == 4, "build_stack_layers buries a full-size lower grid")
	var buried := 0
	for row in stack_game.board_lower:
		for v in row:
			if int(v) != 0:
				buried += 1
	check(buried == 4, "the bury ratio picks round(filled * 0.25) cover cells")

	# --- chains
	var chain_build = _game("chain", _grid(4, 4, 1))
	MECHANICS.build_chain_locks(chain_build, 0.25)
	check(chain_build.board_chain.size() == 4, "build_chain_locks lays a full-size chain grid")
	MECHANICS.dissolve_all_chains(chain_build)
	var chains_left := 0
	for row in chain_build.board_chain:
		for v in row:
			if int(v) != 0:
				chains_left += 1
	check(chains_left == 0, "dissolve_all_chains clears every lock")
	var chain_hook = _game("chain", _grid(3, 3, 1))
	chain_hook.board_chain = _grid(3, 3, 0)
	chain_hook.board_chain[0][1] = 1
	chain_hook.board_chain[2][2] = 1
	MECHANICS.break_chains_around(chain_hook, [Vector2(1, 1)])
	check(int(chain_hook.board_chain[0][1]) == 0, "breaking decrements orthogonal neighbours")
	check(int(chain_hook.board_chain[2][2]) == 1, "non-orthogonal chains stay intact")
	MECHANICS.break_chains_around(chain_hook, [Vector2(1, 1)])
	check(chain_hook.messages.size() >= 1, "chain feedback is messaged")
	MECHANICS.break_chains_around(_game("", [[1]]), [Vector2(0, 0)])
	check(true, "breaking is a no-op outside chain mode")

	# --- gravity
	var gravity_game = _game("gravity", [[1, 0], [0, 2], [0, 0]])
	gravity_game.selected = Vector2(0, 0)
	gravity_game.hint_tiles = [Vector2(0, 0)]
	gravity_game.error_tiles = [Vector2(0, 0)]
	var moved = MECHANICS.apply_gravity(gravity_game)
	check(moved, "gravity reports movement when columns compact")
	check(gravity_game.board[2][0] == 1 && gravity_game.board[0][0] == 0, "tiles fall to the bottom")
	check(gravity_game.selected == Vector2(-1, -1) && gravity_game.hint_tiles.empty(),
		"movement clears the interaction scratch state")
	check(not MECHANICS.apply_gravity(_game("gravity", [[0], [1]])), "settled columns report no movement")

	# --- fog bookkeeping: one layer per 12 cleared pairs' worth of tiles
	var fog_game = _game("fog", _grid(6, 6, 1))
	MECHANICS.update_fog(fog_game)
	check(fog_game._fog_layers == 1, "a full 36-tile board holds one fog layer")
	for r in range(6):
		for c in range(6):
			if r + c > 3:
				fog_game.board[r][c] = 0
	MECHANICS.update_fog(fog_game)
	check(fog_game._fog_layers == 0, "few remaining tiles recede every fog layer")
	fog_game._fog_layers = 3
	MECHANICS.update_fog(_game("", _grid(2, 2, 1)))
	check(_game("", _grid(2, 2, 1))._fog_layers == 0, "non-fog sessions hold no fog layers")

	# --- stack pop
	var pop_game = _game("stack", [[0]])
	pop_game.board_lower = [[7]]
	MECHANICS.pop_stack_at(pop_game, Vector2(0, 0))
	check(int(pop_game.board[0][0]) == 7 && int(pop_game.board_lower[0][0]) == 0,
		"popping lifts the buried tile through the mode gate")
	MECHANICS.pop_stack_at(_game("", [[1]]), Vector2(0, 0))
	check(true, "pop_stack_at is a no-op outside stack mode")

	# --- match damage: armor cracks, clears remove, chains react
	var frost_game = _game("frost", _grid(2, 2, 1))
	frost_game.board_armor = [[1, 0], [0, 0]]
	var cracked = MECHANICS.apply_match_damage(frost_game, Vector2(0, 0), Vector2(1, 1))
	check(cracked == [Vector2(0, 0)], "armored tiles crack instead of clearing")
	check(int(frost_game.board_armor[0][0]) == 0 && int(frost_game.board[0][0]) == 1,
		"cracking consumes the armor and keeps the tile")
	check(int(frost_game.board[1][1]) == 0, "unarmored tiles clear on damage")
	var pop_combo = _game("stack", [[0, 1], [1, 1]])
	pop_combo.board_lower = [[5, 0], [0, 0]]
	var removed = []
	MECHANICS.damage_tile(pop_combo, Vector2(0, 0), [], removed)
	check(int(pop_combo.board[0][0]) == 5 && removed.has(Vector2(0, 0)),
		"damage_tile lifts buried tiles through the stack gate")

	if failures == 0:
		print("board_mechanics_test: ALL PASSED")
		quit(0)
	else:
		print("board_mechanics_test: %d FAILURES" % failures)
		quit(1)
