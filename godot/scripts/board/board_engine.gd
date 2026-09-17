extends Reference

# Pure board algorithms for the lianliankan core, extracted from game.gd so
# they can be unit-tested without a scene tree (high cohesion: this module
# knows nothing about modes, UI or scene state). Every function is static.
#
# Conventions:
#   - board_state: Array of Arrays of ints, 0 = empty cell.
#   - Coordinates are Vector2(x=row, y=col).
#   - Optional playable filter: callers may pass (filter_obj, filter_method)
#     where filter_obj.filter_method(coord) -> bool. Mode mechanics such as
#     fog and chains use it to hide tiles from hints and reshuffles.

# Obstacle tile marker: never matchable, blocks paths, excluded from the
# win count and from reshuffles (classic rock tiles).
const ROCK_VALUE = 99

static func is_rock_value(value) -> bool:
	return int(value) == ROCK_VALUE

static func count_tiles(board_state):
	var count = 0
	for row in board_state:
		for value in row:
			if int(value) != 0 and not is_rock_value(value):
				count += 1
	return count

# Rock placement that never breaks pair parity: convert a whole existing
# pair of same-value cells into rocks until the ratio is met.
static func build_rock_grid(board_state, ratio):
	var rows = board_state.size()
	var cols = board_state[0].size()
	var target_pairs = int(rows * cols * clamp(ratio, 0.0, 0.4) / 2)
	var made = 0
	var attempts = 0
	while made < target_pairs and attempts < target_pairs * 30 + 20:
		attempts += 1
		var r = randi() % rows
		var c = randi() % cols
		var v = int(board_state[r][c])
		if v == 0 or is_rock_value(v):
			continue
		var partner = Vector2(-1, -1)
		var found = false
		for rr in range(rows):
			for cc in range(cols):
				if (rr != r or cc != c) and int(board_state[rr][cc]) == v:
					partner = Vector2(rr, cc)
					found = true
					break
			if found:
				break
		if partner.x < 0:
			continue
		board_state[r][c] = ROCK_VALUE
		board_state[partner.x][partner.y] = ROCK_VALUE
		made += 1
	return made * 2

static func format_time(seconds):
	var mm = seconds / 60
	var ss = seconds % 60
	return "%02d:%02d" % [mm, ss]

static func ring_of(rows, cols, r, c):
	return min(min(r, rows - 1 - r), min(c, cols - 1 - c))

static func shuffle_array(arr):
	for i in range(arr.size() - 1, 0, -1):
		var j = int(rand_range(0, i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func create_board(rows, cols, kinds):
	var total = rows * cols
	if total % 2 != 0:
		total -= 1

	var ids = []
	for i in range(total / 2):
		var id = (i % int(max(1, kinds))) + 1
		ids.append(id)
		ids.append(id)

	shuffle_array(ids)

	var created = []
	var index = 0
	for r in range(rows):
		var row = []
		for c in range(cols):
			# Odd-sized boards leave the tail cells empty instead of crashing.
			if index >= ids.size():
				row.append(0)
			else:
				row.append(ids[index])
				index += 1
		created.append(row)
	return created

# Sum10 deal: logical types 1..5 (each guaranteed an even count by the classic
# generator) split evenly into digit faces (v, 10-v); type 5 stays 5 (5+5).
static func apply_sum10_faces(board_state):
	var seen = {}
	for r in range(board_state.size()):
		for c in range(board_state[0].size()):
			var v = int(board_state[r][c])
			if v == 0 or is_rock_value(v):
				continue
			var times = int(seen.get(v, 0))
			seen[v] = times + 1
			if v == 5:
				continue
			if times % 2 == 1:
				board_state[r][c] = 10 - v


# Edu deal: concept ids 1..kinds (each dealt exactly twice) split into a
# prompt face (2c-1) and an answer face (2c); edu values_match pairs them.
static func apply_edu_faces(board_state):
	var seen = {}
	for r in range(board_state.size()):
		for c in range(board_state[0].size()):
			var v = int(board_state[r][c])
			if v == 0 or is_rock_value(v):
				continue
			var times = int(seen.get(v, 0))
			seen[v] = times + 1
			board_state[r][c] = 2 * v - 1 if times % 2 == 0 else 2 * v


const PATHFINDER = preload("res://scripts/board/board_pathfinder.gd")

# ── pathfinding (delegated to board_pathfinder.gd; these shells keep the
# historical call sites in game.gd and inside this module stable) ──

static func is_inside(board_state, point):
	return PATHFINDER.is_inside(board_state, point)

static func pad_board(board_state):
	return PATHFINDER.pad_board(board_state)

static func values_match(mode_id, a, b):
	return PATHFINDER.values_match(mode_id, a, b)

static func node_key(r, c, d, t):
	return PATHFINDER.node_key(r, c, d, t)

static func find_path(board_state, a, b, match_mode := ""):
	return PATHFINDER.find_path(board_state, a, b, match_mode)

static func find_any_hint(board_state, filter_obj = null, filter_method = "", match_mode := ""):
	return PATHFINDER.find_any_hint(board_state, filter_obj, filter_method, match_mode)


static func create_playable_board(level, filter_obj = null, filter_method = "", match_mode := ""):
	var rows = int(level.get("rows", 8))
	var cols = int(level.get("cols", 6))
	var kinds = int(level.get("kinds", 6))
	var created = create_board(rows, cols, kinds)
	if find_any_hint(created, filter_obj, filter_method, match_mode).empty():
		reshuffle_board(created, filter_obj, filter_method, match_mode)
	return created

# Bomb/rainbow pairs have no connectable path; draw a playful via-top route
# instead. (-1, col) is the row just above the board, the same edge
# convention find_path uses for routes that leave the grid.
static func edge_path(a: Vector2, b: Vector2) -> Array:
	return [a, Vector2(-1, min(a.y, b.y)), b]


# Shuffle values among the occupied cells until a playable hint exists.
# Returns false when the tile count is odd (nothing to do) or no solvable
# arrangement was found within the attempt budget.
# 变脸: swap the values of two differently-valued tiles (multiset intact,
# so pair parity and solvability guarantees are preserved).
static func swap_random_faces(board_state) -> bool:
	var rows = board_state.size()
	var cols = board_state[0].size()
	var a = Vector2(randi() % rows, randi() % cols)
	var b = Vector2(randi() % rows, randi() % cols)
	var va = int(board_state[a.x][a.y])
	var vb = int(board_state[b.x][b.y])
	if va == 0 or vb == 0 or va == vb or is_rock_value(va) or is_rock_value(vb):
		return false
	board_state[a.x][a.y] = vb
	board_state[b.x][b.y] = va
	return true


# 滑移: pick a row that still holds tiles and rotate it right by one cell.
# A cyclic rotation keeps every value, so pair parity stays intact.
static func slide_random_row(board_state) -> bool:
	var rows = board_state.size()
	var cols = board_state[0].size()
	var candidates = []
	for r in range(rows):
		var filled = 0
		for c in range(cols):
			if int(board_state[r][c]) != 0:
				filled += 1
		if filled >= 2:
			candidates.append(r)
	if candidates.empty():
		return false
	var row = candidates[randi() % candidates.size()]
	var last = board_state[row][cols - 1]
	for c in range(cols - 1, 0, -1):
		board_state[row][c] = board_state[row][c - 1]
	board_state[row][0] = last
	return true


static func reshuffle_board(board_state, filter_obj = null, filter_method = "", match_mode := ""):
	var rows = board_state.size()
	var cols = board_state[0].size()

	var tiles = []
	var movable = []
	for r in range(rows):
		for c in range(cols):
			var value = int(board_state[r][c])
			if value != 0 and not is_rock_value(value):
				tiles.append(value)
				movable.append(Vector2(r, c))

	if tiles.size() % 2 != 0:
		return false

	for _attempt in range(20):
		shuffle_array(tiles)
		for i in range(movable.size()):
			var cell = movable[i]
			board_state[cell.x][cell.y] = tiles[i]

		if not find_any_hint(board_state, filter_obj, filter_method, match_mode).empty():
			return true
	return false

# Gravity: compact every column downward. Returns true when anything moved.
static func compact_columns(board_state):
	var moved = false
	for c in range(board_state[0].size()):
		var write = board_state.size() - 1
		for r in range(board_state.size() - 1, -1, -1):
			if int(board_state[r][c]) != 0:
				if r != write:
					board_state[write][c] = int(board_state[r][c])
					board_state[r][c] = 0
					moved = true
				write -= 1
	return moved

# Millisecond-precision time format for best-time labels.
static func format_time_seconds(time_seconds):
	var mm = int(time_seconds) / 60
	var ss = int(time_seconds) % 60
	var ms = int((time_seconds - int(time_seconds)) * 100)
	return "%02d:%02d.%02d" % [mm, ss, ms]

static func contains_coord(list, coord):
	for item in list:
		if item == coord:
			return true
	return false

# --- Mechanic grids: frost armor / chains / stack burying / fog layers ---

static func zero_grid(grid):
	for r in range(grid.size()):
		for c in range(grid[r].size()):
			grid[r][c] = 0
	return grid

static func build_frost_armor_grid(board_state, ratio):
	# Frozen cells bind to positions, so the ice sheet is a plain parallel
	# grid stamped over a share of the occupied cells.
	var armor = []
	for r in range(board_state.size()):
		var row = []
		for c in range(board_state[r].size()):
			row.append(0)
		armor.append(row)
	ratio = float(ratio)
	if ratio <= 0.0:
		return armor
	var cells = []
	for r in range(board_state.size()):
		for c in range(board_state[r].size()):
			if int(board_state[r][c]) != 0:
				cells.append(Vector2(r, c))
	shuffle_array(cells)
	var target = clamp(int(round(cells.size() * ratio)), 0, cells.size())
	for i in range(target):
		var cell = cells[i]
		armor[cell.x][cell.y] = 1
	return armor

static func build_chain_grid(board_state, ratio):
	var grid = _blank_grid(board_state)
	var filled = _filled_cells(board_state)
	shuffle_array(filled)
	var target = clamp(int(round(filled.size() * ratio)), 0, filled.size())
	for i in range(target):
		var cell = filled[i]
		grid[cell.x][cell.y] = 1
	return grid

# A zero grid shaped like board_state, and the list of its non-empty cells —
# shared helpers for the mechanics that scatter values over the board.
static func _blank_grid(board_state):
	var grid = []
	for r in range(board_state.size()):
		var row = []
		for c in range(board_state[r].size()):
			row.append(0)
		grid.append(row)
	return grid

static func _filled_cells(board_state):
	var filled = []
	for r in range(board_state.size()):
		for c in range(board_state[r].size()):
			if int(board_state[r][c]) != 0:
				filled.append(Vector2(r, c))
	return filled

static func bury_stack_layer(board_state, ratio):
	# Buries a share of visible tiles into a lower layer: swaps each covered
	# cell with a donor tile, clears the donor, returns the lower grid.
	var lower = _blank_grid(board_state)
	var filled = _filled_cells(board_state)
	shuffle_array(filled)
	var target = clamp(int(round(filled.size() * ratio)), 0, int(filled.size() / 2))
	var used = {}
	var i = 0
	var covered = 0
	while covered < target and i < filled.size():
		var cover_cell = filled[i]
		i += 1
		if used.has(cover_cell):
			continue
		var donor = Vector2(-1, -1)
		for j in range(i, filled.size()):
			var cand = filled[j]
			if cand != cover_cell and not used.has(cand):
				donor = cand
				break
		if donor.x < 0:
			break
		lower[cover_cell.x][cover_cell.y] = int(board_state[cover_cell.x][cover_cell.y])
		board_state[cover_cell.x][cover_cell.y] = int(board_state[donor.x][donor.y])
		board_state[donor.x][donor.y] = 0
		used[cover_cell] = true
		used[donor] = true
		covered += 1
	return lower

static func count_chains(chain_grid):
	var count = 0
	for row in chain_grid:
		for value in row:
			count += int(value != 0)
	return count

static func break_chains_around(chain_grid, coords):
	# One successful match loosens the chains orthogonally adjacent to it.
	var broke = 0
	for coord in coords:
		for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			var n = coord + dir
			if n.x < 0 or n.y < 0 or n.x >= chain_grid.size() or n.y >= chain_grid[0].size():
				continue
			if int(chain_grid[n.x][n.y]) > 0:
				chain_grid[n.x][n.y] = int(chain_grid[n.x][n.y]) - 1
				broke += 1
	return broke

static func pop_stack(board_state, lower, coord):
	if coord.x < 0 or coord.y < 0 or coord.x >= lower.size() or coord.y >= lower[coord.x].size():
		return false
	if int(lower[coord.x][coord.y]) == 0:
		return false
	board_state[coord.x][coord.y] = int(lower[coord.x][coord.y])
	lower[coord.x][coord.y] = 0
	return true

static func fog_layers(remaining_tiles, max_layers):
	# Fog recedes as pairs are cleared: one layer per 12 remaining pairs.
	return clamp(int(int(remaining_tiles) / 2 / 12), 0, int(max_layers))
