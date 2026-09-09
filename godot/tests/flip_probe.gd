extends SceneTree

# Memory-flip ("翻翻乐") pure-logic probe: dealing, flipping, pairing,
# misses, and unflip behavior. No scene needed — build_view early-outs
# when flip_layer is null.

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== flip_probe")
	var MF = load("res://scripts/memory_flip.gd")

	var game = {
		"flip_state": {},
		"special_level": {"pairs": 12, "cols": 6},
		"flip_layer": null,
	}
	MF.new_round(game)
	var state = game["flip_state"]
	check(state["cards"].size() == 24, "dealt 24 cards (12 pairs)")
	var counts := {}
	for c in state["cards"]:
		var key = int(c["pattern"])
		counts[key] = int(counts.get(key, 0)) + 1
	var pairs_ok = true
	var kinds_seen = 0
	for key in counts:
		kinds_seen += 1
		if int(counts[key]) != 2:
			pairs_ok = false
	check(pairs_ok && kinds_seen == 12, "every pattern appears exactly twice across 12 kinds")

	# --- scripted flips: first pair matches ---
	var first_pattern = int(state["cards"][0]["pattern"])
	var partner_idx = -1
	var odd_idx = -1
	for i in range(1, state["cards"].size()):
		if partner_idx == -1 && int(state["cards"][i]["pattern"]) == first_pattern:
			partner_idx = i
		elif odd_idx == -1 && int(state["cards"][i]["pattern"]) != first_pattern:
			odd_idx = i
	check(partner_idx != -1 && odd_idx != -1, "found a partner and an odd card")

	var r1 = MF.flip(game, 0)
	check(r1 == "" && int(state["open"].size()) == 1, "first flip stays open")
	var r2 = MF.flip(game, partner_idx)
	check(r2 == "match" && int(state["pairs_left"]) == 11, "matching pair removes both cards")
	check(bool(state["cards"][0]["removed"]) && bool(state["cards"][partner_idx]["removed"]), "matched cards are removed")

	# --- mismatch flips back after unflip ---
	var odd_pattern = int(state["cards"][odd_idx]["pattern"])
	var odd_partner = -1
	for i in range(state["cards"].size()):
		if i != odd_idx && !bool(state["cards"][i]["removed"]) && int(state["cards"][i]["pattern"]) == odd_pattern:
			odd_partner = i
	check(odd_partner != -1, "found the odd pattern partner")
	var r3 = MF.flip(game, odd_idx)
	check(r3 == "" && int(state["open"].size()) == 1, "single odd flip stays open")
	var r4 = MF.flip(game, odd_partner)
	check(r4 == "miss", "mismatched pair is a miss")
	MF.unflip_misses(game)
	check(int(state["open"].size()) == 0, "unflip clears the open queue")
	var flipped_left = 0
	for c in state["cards"]:
		if bool(c["flipped"]) && !bool(c["removed"]):
			flipped_left += 1
	check(flipped_left == 0, "missed cards flip back face down")

	# --- already-flipped card cannot be flipped again ---
	var guard = MF.flip(game, odd_idx)
	check(guard == "" && int(state["open"].size()) == 1, "already-flipped card cannot be flipped again")
	MF.unflip_misses(game)

	if failures == 0:
		print("flip_probe: ALL PASSED")
		quit(0)
	else:
		print("flip_probe: %d FAILURES" % failures)
		quit(1)
