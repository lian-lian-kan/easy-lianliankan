extends Reference

# Spoken voice lines: a sweet audio layer over moments the text banners
# already cover. Same shape as cheers.gd — pools per event key drawn through
# shuffled decks held on game.voice_decks, so repeats stay rare. The pools
# point at res://assets/voice/*.ogg clips (Tingting TTS, pitch-lifted).
# Playback is fault-tolerant by design: the headless test env has no import
# cache for ogg, so a missing stream just skips silently.

const POOLS = {
	"clear": [
		"res://assets/voice/clear_1.ogg",
		"res://assets/voice/clear_2.ogg",
		"res://assets/voice/clear_3.ogg",
		"res://assets/voice/clear_4.ogg",
	],
	"fail": [
		"res://assets/voice/fail_1.ogg",
		"res://assets/voice/fail_2.ogg",
		"res://assets/voice/fail_3.ogg",
	],
	"milestone": [
		"res://assets/voice/milestone_1.ogg",
		"res://assets/voice/milestone_2.ogg",
		"res://assets/voice/milestone_3.ogg",
		"res://assets/voice/milestone_4.ogg",
	],
	"signin": [
		"res://assets/voice/signin_1.ogg",
		"res://assets/voice/signin_2.ogg",
	],
	"achievement": [
		"res://assets/voice/achievement_1.ogg",
		"res://assets/voice/achievement_2.ogg",
	],
}


# Draw the next clip path for this event. Each pool keeps its own deck on
# game.voice_decks — no repeats until the deck runs dry, then it reshuffles.
static func draw(game, key: String) -> String:
	if not POOLS.has(key):
		return ""
	var pool: Array = POOLS[key]
	if not game.voice_decks.has(key):
		var fresh = pool.duplicate()
		fresh.shuffle()
		game.voice_decks[key] = fresh
	var deck: Array = game.voice_decks[key]
	if deck.empty():
		deck = pool.duplicate()
		deck.shuffle()
		game.voice_decks[key] = deck
	return str(deck.pop_front())


static func play(game, key: String):
	var path = draw(game, key)
	if path == "":
		return
	AudioManager.play_voice_path(path)


# Data-level invariant for tests: every pool is non-empty and every clip
# path is a res:// ogg under assets/voice.
static func pools_valid() -> bool:
	for key in POOLS:
		var pool: Array = POOLS[key]
		if pool.empty():
			return false
		for path in pool:
			if not str(path).begins_with("res://assets/voice/") or not str(path).ends_with(".ogg"):
				return false
	return true
