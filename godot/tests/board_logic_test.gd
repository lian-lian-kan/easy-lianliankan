extends SceneTree

# Headless regression test for the core lianliankan algorithms in game.gd:
#   godot --headless --path godot -s res://tests/board_logic_test.gd

var _failures = 0

func _check(cond, message):
	if cond:
		return
	_failures += 1
	push_error("FAIL: " + message)

func _init():
	var game_script = load("res://scripts/game.gd")
	if game_script == null:
		push_error("game.gd failed to load/parse")
		quit(1)
		return
	var game = game_script.new()

	# --- path finding: straight line
	var b1 = [[1, 0, 0, 1]]
	_check(not game._find_path(b1, Vector2(0, 0), Vector2(0, 3)).empty(), "straight path should exist")

	# --- adjacent tiles
	var b2 = [[1, 2, 2, 1]]
	_check(not game._find_path(b2, Vector2(0, 1), Vector2(0, 2)).empty(), "adjacent tiles should connect")

	# --- blocked straight line (needs to go around via border => 2 turns, allowed)
	var b3 = [[1, 2, 1]]
	_check(not game._find_path(b3, Vector2(0, 0), Vector2(0, 2)).empty(), "outer-border detour (2 turns) should connect")

	# --- one turn (L shape)
	var b4 = [
		[1, 0],
		[0, 1]
	]
	_check(not game._find_path(b4, Vector2(0, 0), Vector2(1, 1)).empty(), "L-shaped 1-turn path should exist")

	# --- fully enclosed: 3x3 with center blocked on all sides, targets are the corners but
	#     center tile (value 3) is enclosed by 8 tiles => corners can still route via border,
	#     so instead test a genuinely unreachable pair: a 3-turn-only case.
	var b5 = [
		[1, 2, 0],
		[2, 2, 2],
		[0, 2, 1]
	]
	# (0,0) -> (2,2): path must leave via border twice; needs 2 turns around board edge: (0,0)->(-1,0)->(-1,3)->(3,3)->... that's 3 turns; fails
	_check(game._find_path(b5, Vector2(0, 0), Vector2(2, 2)).empty(), "diagonal corners enclosed should NOT connect (3 turns)")

	# --- different values never connect
	_check(game._find_path(b2, Vector2(0, 0), Vector2(0, 1)).empty(), "different values must not connect")

	# --- hint finder must find a pair on a trivially solvable board
	var hint = game._find_any_hint([[1, 2, 2, 1]])
	_check(not hint.empty(), "hint should be found on solvable board")
	if not hint.empty():
		_check(hint.has("a") and hint.has("b") and hint.has("path"), "hint has a/b/path")

	# --- hint finder returns empty when no move exists
	var dead = [
		[1, 2],
		[2, 1]
	]
	# 1s are diagonal, 2s are diagonal; each pair enclosed by the other => border route needs 3 turns
	_check(game._find_any_hint(dead).empty(), "deadlocked 2x2 board should have no hint")

	# --- reshuffle must produce a board with at least one move (when possible)
	var shuffled = [
		[1, 2],
		[2, 1]
	]
	game._reshuffle_board(shuffled)
	_check(not game._find_any_hint(shuffled).empty(), "reshuffle should yield a solvable board")

	# --- reshuffle preserves tile multiset
	var multiset_before = {}
	for row in dead:
		for v in row:
			multiset_before[v] = multiset_before.get(v, 0) + 1
	var multiset_after = {}
	for row in shuffled:
		for v in row:
			multiset_after[v] = multiset_after.get(v, 0) + 1
	var same_counts = multiset_before.size() == multiset_after.size()
	for k in multiset_before.keys():
		if int(multiset_after.get(k, -1)) != int(multiset_before[k]):
			same_counts = false
	_check(same_counts, "reshuffle preserves tile counts")

	# --- generated board is even-sized and solvable
	var created = game._create_playable_board({"rows": 6, "cols": 6, "kinds": 6})
	_check(created.size() == 6 and created[0].size() == 6, "created board has correct dims")
	_check(not game._find_any_hint(created).empty(), "created board is solvable from the start")

	game.free()
	if _failures == 0:
		print("board_logic_test: ALL PASSED")
		quit(0)
	else:
		print("board_logic_test: " + str(_failures) + " FAILURE(S)")
		quit(1)
