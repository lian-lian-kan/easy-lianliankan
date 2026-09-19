extends Reference

# Screen-derived board grids. The level's tile count seeds the difficulty;
# the arrangement belongs to the screen. grid_for() decides columns and rows
# straight from the board area's size — tiles may be rectangular (no square
# rule), the grid fills the area edge to edge, and any extra tiles are dealt
# as whole pairs so every kind stays pairable. Time limits scale with the
# dealt count so a big screen is not penalized with a phone's clock.
#
# Opt-outs: editor custom grids, levels flagged lock_shape (drag's 8x8
# chain density, edu's exactly-sized concept decks), and headless calls
# without a viewport.

const MIN_DIM = 4
const BOARD_AREA_FRACTION = 0.9
const MAX_TILE = 220
const MIN_TILE = 34
const MAX_DISTORTION = 1.6

# Integer grid (rows x cols, even tile count) tiling a width x height area
# with at least tile_count tiles, fewest extras first, then the squarest
# tiles. Columns and rows come from the area: big screens simply deal more
# tiles instead of growing margins or poster-sized pieces.
static func grid_for(tile_count: int, width: float, height: float) -> Dictionary:
	var best := {"rows": 0, "cols": 0, "extra": 0}
	var min_cols = max(MIN_DIM, int(ceil(width / MAX_TILE)))
	var max_cols = int(floor(width / MIN_TILE))
	var min_rows = max(MIN_DIM, int(ceil(height / MAX_TILE)))
	var max_rows = int(floor(height / MIN_TILE))
	var best_score := INF
	for cols in range(min_cols, max_cols + 1):
		var rows_floor = max(min_rows, int(ceil(float(tile_count) / cols)))
		for rows in range(rows_floor, max_rows + 1):
			var total = rows * cols
			if total % 2 != 0:
				continue
			var extra = total - tile_count
			if extra < 0:
				continue
			var dist = _tile_distortion(width, height, cols, rows)
			var score = extra * 10.0 + (dist * 40.0 if dist > MAX_DISTORTION else dist)
			if score < best_score - 0.0001:
				best_score = score
				best = {"rows": rows, "cols": cols, "extra": extra}
	return best


# Copy of the level with rows/cols re-derived from the viewport. Kinds,
# rewards and every other field carry over; time_limit scales with the dealt
# tile count (a 4K screen dealing 162 tiles gets a proportionally longer
# clock); the incoming level dict is never mutated.
static func level_with_fitted_shape(level, viewport_size):
	if level.has("custom_grid") or bool(level.get("lock_shape", false)):
		return level
	if typeof(viewport_size) != TYPE_VECTOR2 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return level
	var rows := int(level.get("rows", 8))
	var cols := int(level.get("cols", 6))
	var height := float(viewport_size.y) * BOARD_AREA_FRACTION
	var grid := grid_for(rows * cols, float(viewport_size.x), height)
	if int(grid["rows"]) == 0:
		return level
	var fitted = level.duplicate()
	fitted["rows"] = int(grid["rows"])
	fitted["cols"] = int(grid["cols"])
	var total := int(grid["rows"]) * int(grid["cols"])
	var time_limit := float(level.get("time_limit", 0))
	if time_limit > 0.0 and total != rows * cols:
		fitted["time_limit"] = int(round(time_limit * float(total) / float(rows * cols)))
	return fitted


# Tile aspect a cols x rows grid produces in this area; 1.0 means square.
static func _tile_distortion(width: float, height: float, cols: int, rows: int) -> float:
	var tile_w = width / float(cols)
	var tile_h = height / float(rows)
	return max(tile_w, tile_h) / min(tile_w, tile_h)
