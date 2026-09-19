extends Reference

# Screen-fit for level boards. Two ideas, both gameplay-neutral:
#
#   1. Shape fit: a level's tile count is the design contract (it sets the
#      difficulty, the clock, the records), but the rows x cols ARRANGEMENT
#      is free. pick() walks the factor shapes of the same tile count and
#      keeps the one whose cols/rows ratio lands closest to the board area's
#      aspect — a wide desktop deals 12x4 where a phone keeps 8x6 — same
#      tiles, same kinds, same clock, no side margins.
#   2. Everything stays opt-out: the level editor's custom grid, levels
#      flagged lock_shape (drag chains want their designed 8x8), headless
#      calls without a viewport, and tiny tile counts all pass through
#      untouched. board_view.gd's bounded-elastic tiles (max 1.6x) absorb
#      whatever aspect gap the chosen shape still leaves.

const MIN_DIM = 4

# The board canvas floors at ~90% of viewport height (HUD chrome above).
# Fit against that area's aspect, not the raw window, so phones keep a
# board wider than tall instead of collapsing into a narrow snake.
const BOARD_AREA_FRACTION = 0.9

# Best-fitting arrangement for this board-area aspect (width / height).
# Ties and unsuitable counts keep the incoming shape.
static func pick(rows: int, cols: int, aspect: float) -> Dictionary:
	var best := {"rows": rows, "cols": cols}
	var tile_count := rows * cols
	if aspect <= 0.0 or tile_count < 2 * MIN_DIM:
		return best
	var best_dist := _shape_distance(cols, rows, aspect)
	var candidate := MIN_DIM
	while candidate <= tile_count:
		if tile_count % candidate == 0:
			var other := tile_count / candidate
			if other >= MIN_DIM:
				var dist := _shape_distance(candidate, other, aspect)
				if dist < best_dist - 0.0001:
					best_dist = dist
					best = {"rows": other, "cols": candidate}
		candidate += 1
	return best


# Copy of the level with rows/cols swapped to the fitted shape. Only the
# shape changes; kinds, clocks, rewards and every other field carry over,
# and the incoming level dict is never mutated.
static func level_with_fitted_shape(level, viewport_size):
	if level.has("custom_grid") or bool(level.get("lock_shape", false)):
		return level
	if typeof(viewport_size) != TYPE_VECTOR2 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return level
	var rows := int(level.get("rows", 8))
	var cols := int(level.get("cols", 6))
	var area_aspect: float = float(viewport_size.x) / float(viewport_size.y) / BOARD_AREA_FRACTION
	var shape := pick(rows, cols, area_aspect)
	if shape["rows"] == rows and shape["cols"] == cols:
		return level
	var fitted = level.duplicate()
	fitted["rows"] = shape["rows"]
	fitted["cols"] = shape["cols"]
	return fitted


# Log-space distance between a shape's ratio and the target aspect: picking
# the minimum is exactly picking the tile shape with the least square/rect
# distortion once the elastic clamp is applied.
static func _shape_distance(cols: int, rows: int, aspect: float) -> float:
	return abs(log(float(cols) / float(rows)) - log(aspect))
