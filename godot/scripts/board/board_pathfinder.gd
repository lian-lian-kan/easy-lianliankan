extends Reference

# Path-finding subsystem for the lianliankan board: turn-limited BFS over
# (cell, direction) states, hint search and the pair-matching rule. Extracted
# from board_engine.gd so routing logic lives in one cohesive module; pure
# static functions, no scene-tree or mode knowledge.
#
# Conventions (same as board_engine):
#   - board_state: Array of Arrays of ints, 0 = empty cell.
#   - Coordinates are Vector2(x=row, y=col).
#   - Optional playable filter: callers may pass (filter_obj, filter_method)
#     where filter_obj.filter_method(coord) -> bool.

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

# Pair rule: equal faces everywhere; sum10 mode also clears digit pairs that
# add up to 10 (1-9, 2-8, 3-7, 4-6, plus the equal 5-5 pair).
static func values_match(mode_id, a, b):
	if mode_id == "sum10":
		return a == b or a + b == 10
	return a == b


static func node_key(r, c, d, t):
	return str(r) + "," + str(c) + "," + str(d) + "," + str(t)

static func parse_node_key(key):
	var parts = key.split(",")
	return [int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])]

static func reconstruct_path(cur, parent, start):
	var steps = []
	var key = node_key(int(cur["r"]), int(cur["c"]), int(cur["dir"]), int(cur["turns"]))

	while parent.has(key):
		var parsed = parse_node_key(key)
		steps.append(Vector2(parsed[0], parsed[1]))
		key = parent[key]

	steps.invert()
	var path: Array = [start]
	for item in steps:
		path.append(item)
	return path

static func compress_path(points):
	if points.size() <= 2:
		return points.duplicate()

	var result: Array = [points[0]]
	for i in range(1, points.size() - 1):
		var prev = result[result.size() - 1]
		var current = points[i]
		var next = points[i + 1]

		var v1 = current - prev
		var v2 = next - current
		if v1 != v2:
			result.append(current)

	result.append(points[points.size() - 1])
	return result

# BFS over (cell, direction) states with at most 2 turns; the board is padded
# with an empty border so routes may leave the grid.
static func find_path(board_state, a, b, match_mode := ""):
	if not is_inside(board_state, a) or not is_inside(board_state, b):
		return []
	if a == b:
		return []

	var value_a = int(board_state[a.x][a.y])
	var value_b = int(board_state[b.x][b.y])
	if value_a == 0 or value_b == 0 or not values_match(match_mode, value_a, value_b):
		return []

	var padded = pad_board(board_state)
	var start = Vector2(a.x + 1, a.y + 1)
	var target = Vector2(b.x + 1, b.y + 1)

	var p_rows = padded.size()
	var p_cols = padded[0].size()

	var visited = []
	for r in range(p_rows):
		var row = []
		for c in range(p_cols):
			row.append([999, 999, 999, 999])
		visited.append(row)

	var queue = []
	var head = 0
	var parent = {}
	_init_path_frontier(padded, start, target, visited, queue, parent)

	while head < queue.size():
		var cur: Dictionary = queue[head]
		head += 1

		if int(cur["r"]) == target.x and int(cur["c"]) == target.y:
			return _finish_path(cur, parent, start)

		_expand_path_node(padded, visited, queue, parent, cur, target, p_rows, p_cols)

	return []

# Seed the BFS queue with the start node's four immediate neighbours.
static func _init_path_frontier(padded, start, target, visited, queue, parent):
	var p_rows = padded.size()
	var p_cols = padded[0].size()
	for d in range(4):
		var np = start + DIRS[d]
		if np.x < 0 or np.x >= p_rows or np.y < 0 or np.y >= p_cols:
			continue
		if int(padded[np.x][np.y]) != 0 and np != target:
			continue
		visited[np.x][np.y][d] = 0
		var node = {"r": np.x, "c": np.y, "dir": d, "turns": 0}
		queue.append(node)
		parent[node_key(np.x, np.y, d, 0)] = node_key(start.x, start.y, -1, 0)

# Reconstruct, compress and unpad the winning route.
static func _finish_path(cur, parent, start) -> Array:
	var path_padded = reconstruct_path(cur, parent, start)
	var compressed = compress_path(path_padded)

	var unpadded = []
	for p in compressed:
		unpadded.append(Vector2(p.x - 1, p.y - 1))
	return unpadded

# Visit one node's neighbours (turn budget 2, turn-minimal memoization).
static func _expand_path_node(padded, visited, queue, parent, cur, target, p_rows, p_cols):
	for nd in range(4):
		var nr = int(cur["r"]) + DIRS[nd].x
		var nc = int(cur["c"]) + DIRS[nd].y
		if nr < 0 or nr >= p_rows or nc < 0 or nc >= p_cols:
			continue
		if int(padded[nr][nc]) != 0 and not (nr == target.x and nc == target.y):
			continue

		var turns = int(cur["turns"])
		var nturns = turns + (0 if int(cur["dir"]) == nd else 1)
		if nturns > 2:
			continue
		if int(visited[nr][nc][nd]) <= nturns:
			continue

		visited[nr][nc][nd] = nturns
		var next_node = {"r": nr, "c": nc, "dir": nd, "turns": nturns}
		queue.append(next_node)
		parent[node_key(nr, nc, nd, nturns)] = node_key(int(cur["r"]), int(cur["c"]), int(cur["dir"]), turns)

static func find_any_hint(board_state, filter_obj = null, filter_method = "", match_mode := ""):
	var rows = board_state.size()
	var cols = board_state[0].size()

	for r1 in range(rows):
		for c1 in range(cols):
			var value = int(board_state[r1][c1])
			if value == 0:
				continue
			if filter_obj != null and not filter_obj.call(filter_method, Vector2(r1, c1)):
				continue

			for r2 in range(r1, rows):
				var start_c = c1 + 1 if r2 == r1 else 0
				for c2 in range(start_c, cols):
					if not values_match(match_mode, int(board_state[r2][c2]), value):
						continue
					if filter_obj != null and not filter_obj.call(filter_method, Vector2(r2, c2)):
						continue

					var path = find_path(board_state, Vector2(r1, c1), Vector2(r2, c2))
					if not path.empty():
						return {
							"a": Vector2(r1, c1),
							"b": Vector2(r2, c2),
							"path": path
						}

	return {}

