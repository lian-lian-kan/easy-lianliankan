extends Reference

# Sound-effect catalog: WHAT each UI event sounds like, as data. Extracted
# from the AudioManager autoload (Round 40) so the sound design is testable
# and editable without touching playback plumbing — same shape as
# cheers.gd/voice_lines.gd: variant pools per event key drawn through
# shuffled decks held on game.sfx_decks, so repeats stay rare.
#
# A recipe is a list of notes: [frequency_hz, duration_s, volume_db, gap_s].
# The player (AudioManager._play_event) renders notes through the enveloped
# tone synth in order. Keep melodies short (<= 4 notes) — these are UI
# blips, not jingles.

const POOLS = {
	# Cursor / selection: a soft tick, three pitches to rotate through.
	"select": [
		[[880.0, 0.05, -16.0, 0.0]],
		[[987.77, 0.05, -16.0, 0.0]],
		[[1174.66, 0.05, -16.0, 0.0]],
	],
	# Base match: gentle two-note dyad, four melodic variants.
	"eliminate": [
		[[523.25, 0.08, -12.0, 0.04], [659.25, 0.1, -12.0, 0.0]],
		[[659.25, 0.08, -12.0, 0.04], [783.99, 0.1, -12.0, 0.0]],
		[[587.33, 0.08, -12.0, 0.04], [880.0, 0.1, -12.0, 0.0]],
		[[698.46, 0.08, -12.0, 0.04], [1046.5, 0.1, -12.0, 0.0]],
	],
	# Combo tiers: brighter arpeggios as the streak grows.
	"combo_3": [
		[[587.33, 0.08, -11.0, 0.04], [739.99, 0.08, -11.0, 0.04], [880.0, 0.1, -11.0, 0.0]],
		[[659.25, 0.08, -11.0, 0.04], [830.61, 0.08, -11.0, 0.04], [987.77, 0.1, -11.0, 0.0]],
	],
	"combo_5": [
		[[659.25, 0.07, -10.0, 0.03], [830.61, 0.07, -10.0, 0.03], [987.77, 0.1, -10.0, 0.0]],
		[[698.46, 0.07, -10.0, 0.03], [880.0, 0.07, -10.0, 0.03], [1046.5, 0.1, -10.0, 0.0]],
	],
	"combo_7": [
		[[783.99, 0.07, -9.0, 0.03], [987.77, 0.07, -9.0, 0.03], [1174.66, 0.1, -9.0, 0.0]],
		[[880.0, 0.07, -9.0, 0.03], [1108.73, 0.07, -9.0, 0.03], [1318.51, 0.1, -9.0, 0.0]],
	],
	"combo_10": [
		[[1046.5, 0.06, -8.0, 0.03], [1318.51, 0.06, -8.0, 0.03], [1567.98, 0.06, -8.0, 0.03], [2093.0, 0.12, -6.0, 0.0]],
		[[987.77, 0.06, -8.0, 0.03], [1174.66, 0.06, -8.0, 0.03], [1567.98, 0.06, -8.0, 0.03], [1975.53, 0.12, -6.0, 0.0]],
	],
	# Wrong pair / invalid action: a low soft thud (two variants so rapid
	# misclicks do not sound identical).
	"error": [
		[[196.0, 0.12, -10.0, 0.0]],
		[[174.61, 0.12, -10.0, 0.0]],
	],
	"hint": [
		[[440.0, 0.07, -14.0, 0.05], [554.37, 0.07, -14.0, 0.05], [659.25, 0.09, -14.0, 0.0]],
	],
	"win": [
		[[523.25, 0.12, -9.0, 0.08], [659.25, 0.12, -9.0, 0.08], [783.99, 0.12, -9.0, 0.08], [1046.5, 0.26, -7.0, 0.0]],
		[[587.33, 0.12, -9.0, 0.08], [739.99, 0.12, -9.0, 0.08], [880.0, 0.12, -9.0, 0.08], [1174.66, 0.26, -7.0, 0.0]],
	],
	"fail": [
		[[349.23, 0.16, -9.0, 0.1], [293.66, 0.16, -9.0, 0.1], [246.94, 0.26, -7.0, 0.0]],
		[[329.63, 0.16, -9.0, 0.1], [261.63, 0.16, -9.0, 0.1], [220.0, 0.26, -7.0, 0.0]],
	],
	"shuffle": [
		[[300.0, 0.04, -14.0, 0.05], [350.0, 0.04, -14.0, 0.05], [400.0, 0.04, -14.0, 0.05], [450.0, 0.04, -14.0, 0.05], [500.0, 0.05, -14.0, 0.0]],
	],
	"click": [
		[[600.0, 0.04, -16.0, 0.0]],
		[[720.0, 0.04, -16.0, 0.0]],
	],
	"time_warning": [
		[[800.0, 0.08, -11.0, 0.0]],
	],
	# Reward chime (NEW event): blossoms/coins landing — a bright two-note
	# sparkle paid on milestones, mission claims and achievement unlocks.
	"coin": [
		[[1318.51, 0.05, -12.0, 0.03], [1760.0, 0.1, -10.0, 0.0]],
		[[1567.98, 0.05, -12.0, 0.03], [2093.0, 0.1, -10.0, 0.0]],
	],
}


# Draw the next recipe for this event. Each pool keeps its own deck on
# game.sfx_decks — no repeats until the deck runs dry, then it reshuffles.
static func draw(game, key: String) -> Array:
	if not POOLS.has(key):
		return []
	var pool: Array = POOLS[key]
	if not game.sfx_decks.has(key):
		var fresh = pool.duplicate()
		fresh.shuffle()
		game.sfx_decks[key] = fresh
	var deck: Array = game.sfx_decks[key]
	if deck.empty():
		deck = pool.duplicate()
		deck.shuffle()
		game.sfx_decks[key] = deck
	var recipe = deck.pop_front()
	game.sfx_decks[key] = deck
	return recipe


# Combo streaks map onto the tiered arpeggio pools (below 3 falls back to
# the base eliminate dyad).
static func key_for_combo(combo: int) -> String:
	if combo >= 10:
		return "combo_10"
	if combo >= 7:
		return "combo_7"
	if combo >= 5:
		return "combo_5"
	if combo >= 3:
		return "combo_3"
	return "eliminate"


# Data-level invariant for tests: every pool non-empty, every note a
# 4-number row with positive frequency/duration.
static func pools_valid() -> bool:
	for key in POOLS:
		var pool: Array = POOLS[key]
		if pool.empty():
			return false
		for recipe in pool:
			if recipe.empty():
				return false
			for note in recipe:
				if note.size() != 4:
					return false
				if float(note[0]) <= 0.0 or float(note[1]) <= 0.0:
					return false
	return true
