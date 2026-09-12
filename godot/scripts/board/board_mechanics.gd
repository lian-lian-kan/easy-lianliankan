extends Reference

# Board mechanic state for the classic-rule mechanics (frost armor / stack
# covers / gravity / fog / chain locks): how a match interacts with armor,
# chains and covers, and which cells are playable. Transitions mutate the
# game node's grids; session flow stays in session.gd. Extracted from
# game.gd.

const BOARD_ENGINE = preload("res://scripts/board/board_engine.gd")

# --- Playability and fog geometry ---

static func cell_ring(game, r, c):
	return BOARD_ENGINE.ring_of(game.board.size(), game.board[0].size(), r, c)

static func is_fogged(game, coord):
	if game.special_mode != "fog":
		return false
	return cell_ring(game, coord.x, coord.y) < game._fog_layers

# 迷雾/锁链 make a tile unselectable; clicks, hints and auto tools skip it.
static func is_coord_playable(game, coord):
	if is_fogged(game, coord):
		return false
	if game.special_mode == "chain" and coord.x < game.board_chain.size() and coord.y < game.board_chain[coord.x].size() \
			and int(game.board_chain[coord.x][coord.y]) > 0:
		return false
	return true

# --- Building and tearing down the mechanic grids ---

static func build_stack_layers(game, ratio):
	game.board_lower = BOARD_ENGINE.bury_stack_layer(game.board, ratio)

static func build_chain_locks(game, ratio):
	game.board_chain = BOARD_ENGINE.build_chain_grid(game.board, ratio)

static func dissolve_all_chains(game):
	BOARD_ENGINE.zero_grid(game.board_chain)
	game._show_message("⛓️ 死局解除，锁链全部崩解！", 1.4)
	game._refresh_board_visuals()

static func break_chains_around(game, coords):
	if game.special_mode != "chain" or coords == null:
		return
	if BOARD_ENGINE.break_chains_around(game.board_chain, coords) > 0:
		game._show_message("⛓️ 邻近的锁链松开了", 0.9)

# 重力: columns compact downward after clears.
static func apply_gravity(game):
	var moved = BOARD_ENGINE.compact_columns(game.board)
	if moved:
		game.selected = Vector2(-1, -1)
		game.hint_tiles.clear()
		game.error_tiles.clear()
	return moved

static func update_fog(game):
	if game.special_mode != "fog":
		game._fog_layers = 0
		return
	var max_layers = int(game._current_level().get("fog_layers", 2))
	game._fog_layers = BOARD_ENGINE.fog_layers(game._remaining_tiles_count(), max_layers)

static func pop_stack_at(game, coord):
	if game.special_mode != "stack":
		return
	BOARD_ENGINE.pop_stack(game.board, game.board_lower, coord)

# --- Match resolution against the mechanic grids ---

# One successful match hits both tiles. Frozen cells (armor 1) crack instead
# of clearing and need a second match; cracked tiles keep blocking paths.
static func apply_match_damage(game, a, b):
	var cracked = []
	var removed = []
	damage_tile(game, a, cracked, removed)
	damage_tile(game, b, cracked, removed)
	break_chains_around(game, removed)
	if cracked.size() > 0:
		AudioManager.play_shuffle()
		game._show_message("❄️ 冰层碎裂！再消一次", 1.0)
	return cracked

static func damage_tile(game, coord, cracked, removed = null):
	if game.special_mode == "frost" and coord.x < game.board_armor.size() and coord.y < game.board_armor[coord.x].size() \
			and int(game.board_armor[coord.x][coord.y]) > 0:
		game.board_armor[coord.x][coord.y] = int(game.board_armor[coord.x][coord.y]) - 1
		cracked.append(coord)
		return
	game.board[coord.x][coord.y] = 0
	if removed != null:
		removed.append(coord)
	pop_stack_at(game, coord)
