extends SceneTree

# Unit tests for scripts/board/board_pathfinder.gd (turn-limited BFS, hint
# search and the pair-matching rule extracted from board_engine).

const FINDER = preload("res://scripts/board/board_pathfinder.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class BlockAll:
	func playable(_coord):
		return false

class AllowAll:
	func playable(_coord):
		return true

func _init() -> void:
	print("== board_pathfinder_test")

	# --- values_match: the pair rule
	check(FINDER.values_match("", 3, 3), "classic rule matches equal faces")
	check(not FINDER.values_match("", 3, 4), "classic rule rejects different faces")
	check(FINDER.values_match("sum10", 1, 9), "sum10 matches 1+9")
	check(FINDER.values_match("sum10", 5, 5), "sum10 matches the equal 5-5 pair")
	check(not FINDER.values_match("sum10", 2, 3), "sum10 rejects 2+3")
	check(FINDER.values_match("sum10", 4, 4), "sum10 keeps the classic equal-face rule")

	# --- is_inside / pad_board (moved shape helpers)
	var b = [[1, 0], [2, 2]]
	check(FINDER.is_inside(b, Vector2(1, 1)), "is_inside accepts the last cell")
	check(not FINDER.is_inside(b, Vector2(2, 0)), "is_inside rejects past-bottom")
	var padded = FINDER.pad_board([[1, 2], [3, 4]])
	check(padded.size() == 4 and int(padded[1][1]) == 1 and int(padded[0][0]) == 0, "pad_board ring + shift")

	# --- node_key / parse_node_key round trip
	var parts = FINDER.parse_node_key(FINDER.node_key(3, 4, 2, 1))
	check(parts == [3, 4, 2, 1], "node key round-trips through parse")

	# --- compress_path
	check(FINDER.compress_path([Vector2(0, 0)]) == [Vector2(0, 0)], "single point passes through")
	check(FINDER.compress_path([Vector2(0, 0), Vector2(1, 0)]) == [Vector2(0, 0), Vector2(1, 0)], "two points pass through")
	check(FINDER.compress_path([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)]) == [Vector2(0, 0), Vector2(2, 0)], "collinear middle point compresses away")
	var straight = FINDER.compress_path([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)])
	check(straight == [Vector2(0, 0), Vector2(2, 0), Vector2(3, 0)], "long runs keep one interior waypoint (historical drawing behaviour, preserved)")
	var bend = FINDER.compress_path([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	check(bend == [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], "a corner is kept")

	# --- find_path: turn budget geometry
	# straight: same row, no bends
	check(not FINDER.find_path([[1, 0, 0, 1]], Vector2(0, 0), Vector2(0, 3)).empty(), "straight path exists")
	# one bend: L route around the corner of an empty board
	check(not FINDER.find_path([[1, 0], [0, 1]], Vector2(0, 0), Vector2(1, 1)).empty(), "one-bend L route exists")
	# two bends: S route around a wall segment
	var s_board = [
		[1, 9, 0],
		[0, 0, 0],
		[0, 9, 1],
	]
	check(not FINDER.find_path(s_board, Vector2(0, 0), Vector2(2, 2)).empty(), "two-bend S route exists")
	# three bends required -> impossible (enclosed by walls)
	check(FINDER.find_path([[9, 9, 9, 9], [9, 1, 9, 1], [9, 9, 9, 9]], Vector2(1, 1), Vector2(1, 3)).empty(), "enclosed tiles have no path")
	# sum10: 1 and 9 connect even though faces differ
	check(not FINDER.find_path([[1, 0, 0, 9]], Vector2(0, 0), Vector2(0, 3), "sum10").empty(), "sum10 connects 1 and 9")
	check(FINDER.find_path([[1, 0, 0, 9]], Vector2(0, 0), Vector2(0, 3)).empty(), "classic mode refuses 1 and 9")
	# guards: out of bounds, same cell, empty cells
	check(FINDER.find_path([[1, 0], [0, 1]], Vector2(-1, 0), Vector2(1, 1)).empty(), "out-of-bounds rejected")
	check(FINDER.find_path([[1, 0], [0, 1]], Vector2(0, 0), Vector2(0, 0)).empty(), "same cell rejected")
	check(FINDER.find_path([[0, 0], [0, 0]], Vector2(0, 0), Vector2(1, 1)).empty(), "empty cells rejected")

	# --- find_any_hint
	var hint = FINDER.find_any_hint([[1, 2, 1]])
	check(hint.size() == 3 and hint["a"] == Vector2(0, 0) and hint["b"] == Vector2(0, 2), "hint reports the connectable pair")
	check(FINDER.find_any_hint([[1, 2, 3]]).empty(), "no hint without a pair")
	check(FINDER.find_any_hint([[1, 2, 1]], BlockAll.new(), "playable").empty(), "hint respects a blocking filter")
	check(not FINDER.find_any_hint([[1, 2, 1]], AllowAll.new(), "playable").empty(), "hint respects an allowing filter")
	var sum_hint = FINDER.find_any_hint([[1, 2, 9]], BlockAll.new(), "playable", "sum10")
	check(sum_hint.empty(), "sum10 hint also honours filters")
	check(not FINDER.find_any_hint([[1, 2, 9]], AllowAll.new(), "playable", "sum10").empty(), "sum10 hint finds 1-9")

	# --- digit rule predicates: diff1 neighbours, mult divisors
	check(FINDER.values_match("diff1", 3, 4), "diff1 connects 3 and 4")
	check(FINDER.values_match("diff1", 4, 3), "diff1 is symmetric")
	check(FINDER.values_match("diff1", 5, 5), "diff1 keeps equal faces matchable")
	check(FINDER.values_match("diff1", 3, 5) == false, "diff1 refuses a gap of 2")
	check(not FINDER.find_path([[3, 0, 0, 4]], Vector2(0, 0), Vector2(0, 3), "diff1").empty(), "diff1 path honours the predicate")
	check(FINDER.values_match("mult", 2, 8), "mult connects 2 and 8")
	check(FINDER.values_match("mult", 9, 3), "mult connects 9 and 3")
	check(FINDER.values_match("mult", 6, 6), "mult keeps equal faces matchable")
	check(FINDER.values_match("mult", 5, 2) == false, "mult refuses 5 and 2")
	check(FINDER.values_match("mult", 8, 6) == false, "mult refuses 8 and 6")
	check(not FINDER.find_any_hint([[2, 0, 4]], AllowAll.new(), "playable", "mult").empty(), "mult hint finds a divisor pair")
	check(FINDER.find_any_hint([[5, 0, 7]], BlockAll.new(), "playable", "mult").empty(), "mult hint refuses non-divisor faces")

	# --- reconstruct_path: walks the parent chain back to the start
	var parent = {
		"1,1,0,0": "0,1,0,0",
		"0,1,0,0": "0,0,0,0",
	}
	var walked = FINDER.reconstruct_path({"r": 1, "c": 1, "dir": 0, "turns": 0}, parent, Vector2(0, 0))
	check(walked == [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)],
		"reconstruct_path rebuilds the route start-to-end")

	if failures == 0:
		print("board_pathfinder_test: ALL PASSED")
		quit(0)
	else:
		print("board_pathfinder_test: %d FAILURES" % failures)
		quit(1)
