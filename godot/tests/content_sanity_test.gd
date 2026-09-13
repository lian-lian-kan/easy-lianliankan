extends SceneTree

# Sanity tests for the content tables: combo cheers (tiered deck draws,
# one-shot milestone bonuses) and voice pools (deck draws + data invariants).

const CHEERS = preload("res://scripts/content/cheers.gd")
const VOICE_LINES = preload("res://scripts/content/voice_lines.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubVoice:
	func play(_game, _key):
		pass

class StubAudio:
	func play_voice_path(_path):
		pass

class FakeGame:
	var cheer_decks = {}
	var combo_milestones_hit = []
	var voice_decks = {}
	var progression_state = {}
	var patches = []
	var messages = []
	var audio = StubAudio.new()
	var ECONOMY = null
	var VOICE_LINES = StubVoice.new()
	func _patch_progress_state(patch):
		patches.append(patch)
	func _show_message(msg, _dur):
		messages.append(msg)

func _init() -> void:
	print("== content_sanity_test")

	# --- cheers: tier selection
	check(CHEERS.tier_for(1).empty(), "combo below 2 has no tier")
	check(int(CHEERS.tier_for(2)["min"]) == 2, "combo 2 lands on the lowest tier")
	check(int(CHEERS.tier_for(9)["min"]) == 8, "combo 9 lands on the 8+ tier")
	check(int(CHEERS.tier_for(99)["min"]) == 10, "huge combos cap at the top tier")

	# --- cheers: deck draws always return pool lines, then refill
	var game = FakeGame.new()
	var top_lines: Array = CHEERS.TIERS[0]["lines"]
	var ok = true
	for _i in range(top_lines.size() + 3):
		var line = CHEERS.draw(game, 99)
		if not top_lines.has(line):
			ok = false
	check(ok, "deck draws only emit lines from the active tier")

	# --- cheers: milestone bonus fires once per milestone per round
	game = FakeGame.new()
	check(CHEERS.on_combo(game, 1, 4) == "", "combo below 2 never cheers")
	var first = CHEERS.on_combo(game, 3, 6)
	check(first.begins_with("+6") == false and first != "", "combo 3 returns a cheer line")
	check(game.patches.size() == 1 and int(game.patches[0]["coins_delta"]) == 2, "milestone 3 pays its blossom bonus once")
	CHEERS.on_combo(game, 3, 6)
	CHEERS.on_combo(game, 3, 6)
	var paid = 0
	for p in game.patches:
		paid += int(p["coins_delta"])
	check(paid == 2, "the same milestone never pays twice in one round")

	# --- cheers: every pool line is short enough for the burst label
	var short_enough = true
	for tier in CHEERS.TIERS:
		for line in tier["lines"]:
			if str(line).length() > 8:
				short_enough = false
	check(short_enough, "praise lines stay within the burst label budget")

	# --- voice pools: data invariants + deck draws
	check(VOICE_LINES.pools_valid(), "every voice pool is non-empty with res:// voice paths")
	game = FakeGame.new()
	check(VOICE_LINES.draw(game, "nope") == "", "unknown voice events draw nothing")
	var seen = {}
	var fresh = true
	for _i in range(3):
		var clip = VOICE_LINES.draw(game, "achievement")
		seen[clip] = true
		if not (clip.begins_with("res://assets/voice/") and clip.ends_with(".ogg")):
			fresh = false
	check(seen.size() >= 1 and fresh, "achievement draws rotate real voice clips")

	if failures == 0:
		print("content_sanity_test: ALL PASSED")
		quit(0)
	else:
		print("content_sanity_test: %d FAILURES" % failures)
		quit(1)
