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

const DIRS = [
	Vector2(-1, 0),
	Vector2(1, 0),
	Vector2(0, -1),
	Vector2(0, 1)
]

static func is_inside(board_state, point):
	return point.x >= 0 and point.x < board_state.size() and point.y >= 0 and point.y < board_state[0].size()

static func pad_board(board_state):
	var rows = board_state.size()
	var cols = board_state[0].size()
	var padded = []

	for r in range(rows + 2):
		var row = []
		for c in range(cols + 2):
			row.append(0)
		padded.append(row)

	for r in range(rows):
		for c in range(cols):
			padded[r + 1][c + 1] = board_state[r][c]

	return padded

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

static func reshuffle_board(board_state, filter_obj = null, filter_method = ""):
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

		if not find_any_hint(board_state, filter_obj, filter_method).empty():
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
	var grid = []
	for r in range(board_state.size()):
		var row = []
		for c in range(board_state[r].size()):
			row.append(0)
		grid.append(row)
	var filled = []
	for r in range(board_state.size()):
		for c in range(board_state[r].size()):
			if int(board_state[r][c]) != 0:
				filled.append(Vector2(r, c))
	shuffle_array(filled)
	var target = clamp(int(round(filled.size() * ratio)), 0, filled.size())
	for i in range(target):
		var cell = filled[i]
		grid[cell.x][cell.y] = 1
	return grid

static func bury_stack_layer(board_state, ratio):
	# Buries a share of visible tiles into a lower layer: swaps each covered
	# cell with a donor tile, clears the donor, returns the lower grid.
	var lower = []
	for r in range(board_state.size()):
		var row = []
		for c in range(board_state[r].size()):
			row.append(0)
		lower.append(row)
	var filled = []
	for r in range(board_state.size()):
		for c in range(board_state[r].size()):
			if int(board_state[r][c]) != 0:
				filled.append(Vector2(r, c))
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
