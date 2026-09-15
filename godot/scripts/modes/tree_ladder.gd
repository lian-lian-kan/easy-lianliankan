extends Reference

# 攀登树 (tree climb): an endless ladder of layers carved into a big tree.
# The player always resumes at their best cleared height + 1, so the climb
# never ends and every layer is cleared in order. Pure balance math lives
# here so the curve and the milestone table stay headless-assertable;
# special_modes.gd wraps level_for() into a virtual level.

# Layer heights that fire a one-time blossom payout when first cleared.
const MILESTONE_HEIGHTS = [8, 18, 28, 50, 100, 200, 365, 500, 1000, 5000, 10000, 100000, 1000000]
const MILESTONE_REWARDS = [20, 30, 40, 60, 100, 150, 200, 300, 500, 800, 1200, 2000, 5000]

# Board curve: rows/cols/kinds grow with height then plateau so late layers
# stay clearable; the clock tightens toward the floor. rows and cols stride
# in even steps so every rows*cols tile count stays even (pairable).
const BASE_ROWS = 8
const BASE_COLS = 6
const BASE_KINDS = 6
const MAX_ROWS = 14
const MAX_COLS = 10
const MAX_KINDS = 12
const BASE_TIME = 100
const MIN_TIME = 45

static func level_for(height: int):
	var h = max(1, height)
	return {
		"id": 1,
		"name": "第" + str(h) + "层",
		"mode": "tree",
		"rows": min(BASE_ROWS + int((h - 1) / 6.0), MAX_ROWS),
		"cols": min(BASE_COLS + int((h - 1) / 10.0), MAX_COLS),
		"kinds": min(BASE_KINDS + int((h - 1) / 8.0), MAX_KINDS),
		"time_limit": max(MIN_TIME, BASE_TIME - h),
		"tree_height": h,
		"score_multiplier": 1.0 + min(1.0, float(h) / 200.0)
	}


static func milestone_reward(height: int) -> int:
	for i in range(MILESTONE_HEIGHTS.size()):
		if int(MILESTONE_HEIGHTS[i]) == int(height):
			return int(MILESTONE_REWARDS[i])
	return 0


static func is_milestone(height: int) -> bool:
	return milestone_reward(height) > 0


# How many of the claimed heights are real milestones (guards save-data
# noise from inflating the progress readout).
static func claimed_count(claimed) -> int:
	var total = 0
	if typeof(claimed) == TYPE_ARRAY:
		for height in claimed:
			if milestone_reward(int(height)) > 0:
				total += 1
	return total
