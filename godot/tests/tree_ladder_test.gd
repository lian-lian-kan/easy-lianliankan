extends SceneTree

# Headless tests for the tree-climb ladder: the growth curve, its even-tile
# invariant, and the milestone payout table.

const TREE_LADDER = preload("res://scripts/modes/tree_ladder.gd")

var failures := 0


func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)


func _init() -> void:
	# --- curve at the bottom: layer 1 is the gentle opening board
	var first = TREE_LADDER.level_for(1)
	check(int(first["rows"]) == 8 and int(first["cols"]) == 6, "layer 1 opens 8x6")
	check(int(first["kinds"]) == 6, "layer 1 deals 6 kinds")
	check(int(first["time_limit"]) == 99, "layer 1 clocks 100-height seconds")
	check(int(first["tree_height"]) == 1, "level carries its height")
	check(str(first["mode"]) == "tree", "level is tagged mode tree")

	# --- curve mid-climb: growth is visible but bounded
	var mid = TREE_LADDER.level_for(40)
	check(int(mid["rows"]) > int(first["rows"]), "rows grow with height")
	check(int(mid["kinds"]) > int(first["kinds"]), "kinds grow with height")
	check(int(mid["time_limit"]) < int(first["time_limit"]), "clock tightens with height")
	check(float(mid["score_multiplier"]) > float(first["score_multiplier"]), "score multiplier climbs")

	# --- curve at the ceiling: plateau keeps late layers clearable
	var deep = TREE_LADDER.level_for(5000)
	var deeper = TREE_LADDER.level_for(1000000)
	check(int(deep["rows"]) == 14 and int(deep["cols"]) == 10, "board plateaus at 14x10")
	check(int(deep["kinds"]) == 12, "kinds plateau at 12")
	check(int(deeper["time_limit"]) == 45, "clock floors at 45 seconds")
	check(int(deeper["tree_height"]) == 1000000, "height is unbounded")

	# --- pairability: every sampled layer deals an even tile count
	var cells_ok := true
	for h in [1, 2, 6, 7, 11, 13, 40, 61, 100, 999, 5000]:
		var level = TREE_LADDER.level_for(h)
		if (int(level["rows"]) * int(level["cols"])) % 2 != 0:
			cells_ok = false
			push_error("odd tile count at layer %d" % h)
	check(cells_ok, "every sampled layer deals an even tile count")

	# --- milestone table: parallel arrays, one-time payouts
	check(TREE_LADDER.MILESTONE_HEIGHTS.size() == TREE_LADDER.MILESTONE_REWARDS.size(),
		"milestone heights and rewards are parallel")
	check(TREE_LADDER.milestone_reward(8) == 20, "layer 8 pays 20 blossoms")
	check(TREE_LADDER.milestone_reward(10000) == 1200, "layer 10000 pays 1200 blossoms")
	check(TREE_LADDER.milestone_reward(1000000) == 5000, "layer 1000000 pays 5000 blossoms")
	check(TREE_LADDER.milestone_reward(7) == 0 and TREE_LADDER.milestone_reward(9) == 0,
		"non-milestone neighbours pay nothing")
	check(TREE_LADDER.is_milestone(50) and not TREE_LADDER.is_milestone(51),
		"is_milestone mirrors the table")

	# --- claimed_count filters save-data noise
	check(TREE_LADDER.claimed_count([8, 18, 999]) == 2, "claimed_count keeps real milestones only")
	check(TREE_LADDER.claimed_count([]) == 0, "claimed_count of nothing is zero")
	check(TREE_LADDER.claimed_count("bad") == 0, "claimed_count of a non-array is zero")

	# --- heights below 1 clamp to the opening layer
	check(int(TREE_LADDER.level_for(0)["tree_height"]) == 1, "height 0 clamps to layer 1")
	check(int(TREE_LADDER.level_for(-5)["tree_height"]) == 1, "negative height clamps to layer 1")

	if failures == 0:
		print("tree_ladder_test: ALL PASSED")
		quit(0)
	else:
		print("tree_ladder_test: %d FAILURES" % failures)
		quit(1)
