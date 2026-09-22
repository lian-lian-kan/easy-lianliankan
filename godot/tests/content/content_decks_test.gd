extends SceneTree

# Unit tests for the content decks: cheers tier selection, no-repeat deck
# draws with reshuffle-on-dry, milestone bonuses paid once per round, and
# the voice-line pools' data invariants.

const CHEERS = preload("res://scripts/content/cheers.gd")
const VOICE_LINES = preload("res://scripts/content/voice_lines.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class StubAudio:
	var played := []
	func play_voice_path(path):
		played.append(path)

class FakeGame extends Reference:
	const VOICE_LINES = preload("res://scripts/content/voice_lines.gd")
	var audio = StubAudio.new()
	var cheer_decks = {}
	var voice_decks = {}
	var combo_milestones_hit = []
	var patches = []
	var messages = []
	func _patch_progress_state(patch):
		patches.append(patch)
	func _show_message(msg, _dur):
		messages.append(msg)

func _init() -> void:
	print("== content_decks_test")

	# --- cheers tier selection
	check(CHEERS.tier_for(0).empty() and CHEERS.tier_for(1).empty(),
		"combo below 2 has no cheer tier")
	check(int(CHEERS.tier_for(2)["min"]) == 2, "combo 2 lands on the 2-tier")
	check(int(CHEERS.tier_for(4)["min"]) == 4, "combo 4 lands on the 4-tier")
	check(int(CHEERS.tier_for(5)["min"]) == 4, "combo 5 stays on the 4-tier")
	check(int(CHEERS.tier_for(9)["min"]) == 8, "combo 9 stays on the 8-tier")
	check(int(CHEERS.tier_for(10)["min"]) == 10, "combo 10 reaches the top tier")
	check(int(CHEERS.tier_for(99)["min"]) == 10, "combo 99 is capped at the top tier")

	# --- deck draw: every line unique until the pool is exhausted
	var game = FakeGame.new()
	var tier_lines: Array = CHEERS.TIERS.back()["lines"]
	var drawn := []
	for _i in range(tier_lines.size()):
		drawn.append(CHEERS.draw(game, 2))
	check(drawn.size() == tier_lines.size(), "a full pass draws one line per pool entry")
	var unique := {}
	for line in drawn:
		unique[line] = true
	check(unique.size() == tier_lines.size(), "no line repeats within one deck pass")
	var reshuffled = CHEERS.draw(game, 2)
	check(not reshuffled.empty(), "drawing past the deck reshuffles and keeps dealing")

	# --- on_combo: gate, burst text and milestone payments
	game = FakeGame.new()
	check(CHEERS.on_combo(game, 1, 5) == "", "combo 1 is too low to cheer")
	var burst = CHEERS.on_combo(game, 2, 40)
	check(burst.find("+40") != -1 and not burst.empty(), "combo 2 cheers with the gain appended")
	var combo3 = CHEERS.on_combo(game, 3, 10)
	check(combo3.find("+10") != -1, "combo 3 cheers too")
	check(game.patches.size() == 1 and game.patches[0]["coins_delta"] == 2,
		"the 3-streak milestone pays 2 blossoms once")
	check(game.messages.back().find("🌈 3 连击达成") != -1, "the milestone is announced")
	var again = CHEERS.on_combo(game, 3, 10)
	check(again.find("+10") != -1 and game.patches.size() == 1,
		"the same milestone never pays twice in a round")
	# combo 12 crosses the 5/8/12 milestones at once (3 was already paid)
	CHEERS.on_combo(game, 12, 10)
	check(game.patches.size() == 4, "crossing 5/8/12 pays each remaining milestone once")
	check(game.patches.back()["coins_delta"] == 8, "the 12 milestone pays 8 blossoms")
	check(game.combo_milestones_hit.has(12), "the 12 milestone is recorded")

	# --- voice lines: pools, decks and playback
	game = FakeGame.new()
	check(VOICE_LINES.pools_valid(), "every voice pool is non-empty res:// ogg paths")
	check(VOICE_LINES.draw(game, "nonexistent") == "", "an unknown event draws nothing")
	var first = VOICE_LINES.draw(game, "clear")
	check(first.begins_with("res://assets/voice/"), "a known event draws a voice clip")
	game.voice_decks["clear"] = []
	var reshuffle_draw = VOICE_LINES.draw(game, "clear")
	check(not reshuffle_draw.empty(), "an exhausted deck reshuffles on demand")
	var before = game.audio.played.size()
	VOICE_LINES.play(game, "nonexistent")
	check(game.audio.played.size() == before, "play() with an unknown key stays silent")
	VOICE_LINES.play(game, "signin")
	check(game.audio.played.size() == before + 1, "play() with a known key voices a clip")

	# --- husband / clear phrases always come back non-empty
	game = FakeGame.new()
	check(not CHEERS.husband_line(game).empty(), "husband rescue always says something")
	check(not CHEERS.clear_cheer(game).empty(), "clear cheer always says something")

	if failures == 0:
		print("content_decks_test: ALL PASSED")
		quit(0)
	else:
		print("content_decks_test: %d FAILURES" % failures)
		quit(1)
