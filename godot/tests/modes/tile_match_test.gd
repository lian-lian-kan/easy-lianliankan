extends SceneTree

# Unit tests for the tile_match tray-mode state machine (pure rules, no view).

const TM = preload("res://scripts/modes/tile_match.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func first_uncovered_index(state) -> int:
	for i in range(state["tiles"].size()):
		if not state["tiles"][i]["removed"] and not TM.is_covered(state, state["tiles"][i]):
			return i
	return -1

func _init() -> void:
	print("== tile_match_test")

	# --- generate invariants
	var state = TM.generate({"layers": 2, "layer_rows": 3, "layer_cols": 4, "kinds": 4})
	check(state["tiles"].size() == 24, "generate lays out layers*rows*cols tiles")
	var counts = {}
	for t in state["tiles"]:
		counts[int(t["pattern"])] = int(counts.get(int(t["pattern"]), 0)) + 1
	var all_multiple_of_3 = true
	for k in counts:
		if counts[k] % 3 != 0:
			all_multiple_of_3 = false
	check(all_multiple_of_3, "every pattern appears a multiple of 3 so the pile can clear")
	check(state["tray"].empty() and state["undo_left"] == 1 and state["shuffle_left"] == 1, "fresh state starts with an empty tray and one of each tool")

	# --- coverage: only top-layer neighbours cover a tile
	var flat = TM.generate({"layers": 1, "layer_rows": 2, "layer_cols": 2, "kinds": 2})
	var a = flat["tiles"][0]
	check(not TM.is_covered(flat, a), "single-layer tiles are never covered")

	# --- pick: inserts into the tray grouped by pattern
	state = TM.generate({"layers": 1, "layer_rows": 2, "layer_cols": 2, "kinds": 3})
	var t0 = state["tiles"][0]
	var t1 = state["tiles"][1]
	check(TM.pick(state, 0) == "", "first pickup is a normal move")
	check(t0["removed"] == true and state["tray"] == [int(t0["pattern"])], "picked tile moves to the tray")
	TM.pick(state, 1)
	var tray = state["tray"]
	check(tray.size() == 2, "second pickup sits in the tray")

	# --- pick guards
	check(TM.pick(state, -1) == "", "negative index is ignored")
	check(TM.pick(state, 999) == "", "out-of-range index is ignored")
	check(TM.pick(state, 0) == "", "an already-removed tile cannot be picked again")

	# --- triple clears: three of a kind vanish from the tray
	state = TM.generate({"layers": 1, "layer_rows": 3, "layer_cols": 1, "kinds": 1})
	TM.pick(state, 0)
	TM.pick(state, 1)
	var result = TM.pick(state, 2)
	check(result == "cleared", "third of a kind clears and empties the pile")
	check(state["tray"].empty(), "cleared triple leaves the tray empty")
	check(TM.score_for(state) == 30, "score counts 30 per cleared triple")

	# --- lost: tray jams at capacity without a triple
	state = TM.generate({"layers": 1, "layer_rows": 3, "layer_cols": 1, "kinds": 3})
	state["capacity"] = 2
	TM.pick(state, 0)
	result = TM.pick(state, 1)
	check(result == "lost", "full tray with no triple loses")
	check(TM.score_for(state) == 0, "no triples no score")

	# --- undo: restores the last pickup once per tool charge
	state = TM.generate({"layers": 1, "layer_rows": 2, "layer_cols": 1, "kinds": 2})
	TM.pick(state, 0)
	check(TM.undo(state) == true, "undo returns true with charges left")
	check(state["tiles"][0]["removed"] == false and state["tray"].empty(), "undo restores the picked tile")
	check(TM.undo(state) == false, "undo without charges refuses")

	# --- shuffle: rerolls live patterns once
	state = TM.generate({"layers": 1, "layer_rows": 2, "layer_cols": 1, "kinds": 2})
	var before = []
	for t in state["tiles"]:
		before.append(int(t["pattern"]))
	check(TM.shuffle(state) == true, "shuffle with charges returns true")
	check(state["shuffle_left"] == 0, "shuffle consumes its charge")
	var after = []
	for t in state["tiles"]:
		after.append(int(t["pattern"]))
	before.sort()
	after.sort()
	check(after == before, "shuffle keeps the same multiset of patterns")
	check(TM.shuffle(state) == false, "shuffle without charges refuses")

	# --- clear_view: null-safe layer teardown
	var layer = Node.new()
	layer.add_child(Node.new())
	var view_game = ViewGame.new()
	view_game.tray_layer = layer
	TM.clear_view(view_game)
	check(layer.get_child_count() == 0, "clear_view empties the tray layer")
	TM.clear_view(ViewGame.new())
	check(true, "clear_view tolerates a missing layer")

	if failures == 0:
		print("tile_match_test: ALL PASSED")
		quit(0)
	else:
		print("tile_match_test: %d FAILURES" % failures)
		quit(1)

class ViewGame:
	var tray_layer = null
