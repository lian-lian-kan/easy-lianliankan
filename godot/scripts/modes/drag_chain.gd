extends Reference

# 连线消 (drag chain) 的纯链数学：相邻判定、延伸判定与链计分。手势推进
# （按下/划入/松手）在交互模块的 drag_link.gd——两类输入范式共享一块
# 棋盘：链长 ≥3 整链清消，恰好两张按相邻对消除，单张轻点落回经典选牌流。

const CHAIN_MIN = 3
const CHAIN_BONUS_PER_TILE = 0.5
const CHAIN_COLOR = Color("da77f2")

static func adjacent(a: Vector2, b: Vector2) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

# Can `point` legally extend this chain on this board: in bounds, not already
# chained, occupied, orthogonally adjacent to the chain head, and same kind
# as the head (head equality implies the whole chain shares one kind).
static func can_extend(board_state, chain, point: Vector2) -> bool:
	if chain.empty() or point.x < 0 or point.y < 0:
		return false
	if point.x >= board_state.size() or point.y >= board_state[0].size():
		return false
	for coord in chain:
		if coord == point:
			return false
	var value = int(board_state[point.x][point.y])
	if value == 0 or value != int(board_state[chain[0].x][chain[0].y]):
		return false
	return adjacent(chain[chain.size() - 1], point)

# Base score for one chain: per-tile value plus a bonus per tile beyond the
# pair (3 tiles = x1.5, 4 = x2, ...), feeding the regular combo pipeline.
static func chain_score(base_score: int, chain_size: int) -> int:
	var bonus = 1.0 + CHAIN_BONUS_PER_TILE * float(max(0, chain_size - 2))
	return int(max(1.0, round(float(base_score) * chain_size * bonus)))
