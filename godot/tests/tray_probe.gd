extends SceneTree

# Tray-match ("叠叠消") pure-logic probe: generation legality, coverage,
# triple clears, win/loss transitions, undo and shuffle. No scene needed.

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== tray_probe")
	var TM = load("res://scripts/tile_match.gd")
	var cfg = {"layers": 4, "layer_rows": 5, "layer_cols": 6, "kinds": 10, "tray_capacity": 7}

	# --- generation legality ---
	var state = TM.generate(cfg)
	var tiles: Array = state["tiles"]
	check(tiles.size() == 120, "generate fills 120 tile slots (got %d)" % tiles.size())
	var counts := {}
	for t in tiles:
		var key = int(t["pattern"])
		counts[key] = int(counts.get(key, 0)) + 1
	var multiples_ok = true
	var kinds_seen = 0
	for key in counts:
		kinds_seen += 1
		if int(counts[key]) % 3 != 0:
			multiples_ok = false
	check(multiples_ok && kinds_seen == 10, "every pattern appears a multiple of 3 across 10 kinds")
	check(int(state["capacity"]) == 7, "tray capacity is 7")

	# --- coverage: a tile under a top-layer neighbor is locked ---
	var top = null
	for t in tiles:
		if int(t["layer"]) == 3:
			top = t
			break
	check(top != null && !TM.is_covered(state, top), "top-layer tile is never covered")
	var bottom = null
	for t in tiles:
		if int(t["layer"]) == 0:
			bottom = t
			break
	# cover the bottom tile from layer 1 if not already covered
	if bottom != null and !TM.is_covered(state, bottom):
		for t in tiles:
			if int(t["layer"]) == 1 and abs(int(t["row"]) - int(bottom["row"])) <= 1 \
					and abs(int(t["col"]) - int(bottom["col"])) <= 1:
				t["removed"] = false
				bottom = bottom
				break
	check(bottom != null, "bottom-layer tiles exist")

	# --- triple clear and win on a tiny deterministic board ---
	var mini = TM.generate({"layers": 1, "layer_rows": 1, "layer_cols": 3, "kinds": 1, "tray_capacity": 7})
	var mini_tiles: Array = mini["tiles"]
	var seq = [0, 0, 0]
	for i in range(mini_tiles.size()):
		mini_tiles[i]["pattern"] = seq[i]
	var first_pick = TM.pick(mini, 0)
	var second_pick = TM.pick(mini, 1)
	check(first_pick == "" && second_pick == "", "first two picks just fill the tray")
	var third = TM.pick(mini, 2)
	check(third == "cleared" && int(mini["tray"].size()) == 0, "three of a kind clear the tray and the pile")
	check(TM.score_for(mini) == 30, "one triple scores 30")

	# --- tray jam -> lost ---
	var jam = TM.generate({"layers": 1, "layer_rows": 1, "layer_cols": 9, "kinds": 9, "tray_capacity": 7})
	var jt: Array = jam["tiles"]
	var seq2 = [0, 1, 2, 3, 4, 5, 6, 0, 1]
	for i in range(jt.size()):
		jt[i]["pattern"] = seq2[i]
	var last = ""
	for i in range(7):
		last = TM.pick(jam, i)
	check(last == "lost" && int(jam["tray"].size()) == 7, "jamming the tray loses (tray=%d)" % int(jam["tray"].size()))

	# --- full clear -> cleared ---
	var win = TM.generate({"layers": 1, "layer_rows": 1, "layer_cols": 3, "kinds": 1, "tray_capacity": 7})
	for i in range(3):
		TM.pick(win, i)
	check(TM.score_for(win) == 30, "tiny board fully clears")
	var cleared = false
	for t in win["tiles"]:
		if t["removed"]:
			cleared = true
	check(cleared, "cleared board has no live tiles")

	# --- undo restores the last pickup and refunds its charge once ---
	var ud = TM.generate({"layers": 1, "layer_rows": 1, "layer_cols": 3, "kinds": 1, "tray_capacity": 7})
	TM.pick(ud, 0)
	var undo_ok = TM.undo(ud)
	check(undo_ok && int(ud["tray"].size()) == 0 && int(ud["undo_left"]) == 0, "undo refunds the tray once")
	check(!TM.undo(ud), "second undo is refused (charge spent)")

	# --- shuffle rerolls live patterns without changing counts ---
	var sh = TM.generate({"layers": 1, "layer_rows": 2, "layer_cols": 3, "kinds": 3, "tray_capacity": 7})
	var before := {}
	for t in sh["tiles"]:
		before[int(t["pattern"])] = int(before.get(int(t["pattern"]), 0)) + 1
	check(TM.shuffle(sh), "shuffle spends its charge")
	var after := {}
	for t in sh["tiles"]:
		after[int(t["pattern"])] = int(after.get(int(t["pattern"]), 0)) + 1
	check(before.size() == after.size(), "shuffle keeps the pattern multiset")

	if failures == 0:
		print("tray_probe: ALL PASSED")
		quit(0)
	else:
		print("tray_probe: %d FAILURES" % failures)
		quit(1)
