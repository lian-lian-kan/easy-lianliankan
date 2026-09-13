extends Reference

# Power-up loadout resolution: what each campaign level (or special session)
# grants when play begins. Extracted from powerups.gd as a pure table-driven
# resolver so the grant ladder is data and can be unit-tested directly.
#
# Ladder semantics (matching the historical if-chain exactly): every unlocked
# key SETS its count (it does not stack); rush/endurance ADD on top; special
# sessions ignore the ladder and receive the fixed per-mode loadout.

const UNLOCK_LADDER = [
	{"level": 3, "key": "auto_match", "count": 1},
	{"level": 5, "key": "time_freeze", "count": 2},
	{"level": 6, "key": "magnifier", "count": 1},
	{"level": 8, "key": "time_sand", "count": 1},
	{"level": 10, "key": "bomb", "count": 1},
	{"level": 12, "key": "rainbow", "count": 1},
]

const MODE_EXTRA = {"rush": {"time_freeze": 1}, "endurance": {"reshuffle": 1}}

# Special sessions get a friendly fixed loadout: base grants, per-mode extras,
# then explicit overrides (assignment order preserved).
const SPECIAL_LOADOUT_BASE = {"time_freeze": 2, "reshuffle": 2, "auto_match": 1, "bomb": 1, "rainbow": 1}
const SPECIAL_LOADOUT_EXTRA = {
	"memory": {"magnifier": 1},
	"time_attack": {"time_sand": 1},
	"frost": {"warm_patch": 3},
}
const SPECIAL_LOADOUT_OVERRIDE = {
	"hell": {"time_freeze": 1, "reshuffle": 1, "auto_match": 0, "magnifier": 0, "time_sand": 0, "bomb": 0, "rainbow": 0, "warm_patch": 0},
}


static func resolve(level_id: int, mode: String, special_session: bool, special_mode: String) -> Dictionary:
	var loadout = {"time_freeze": 0, "auto_match": 0, "reshuffle": 0, "magnifier": 0, "time_sand": 0, "bomb": 0, "rainbow": 0, "warm_patch": 0}
	loadout["time_freeze"] = 1
	loadout["reshuffle"] = 1

	for entry in UNLOCK_LADDER:
		if level_id >= int(entry["level"]):
			loadout[entry["key"]] = int(entry["count"])

	if MODE_EXTRA.has(mode):
		for key in MODE_EXTRA[mode]:
			loadout[key] += int(MODE_EXTRA[mode][key])

	if special_session:
		for key in SPECIAL_LOADOUT_BASE:
			loadout[key] = int(SPECIAL_LOADOUT_BASE[key])
		if SPECIAL_LOADOUT_EXTRA.has(special_mode):
			for key in SPECIAL_LOADOUT_EXTRA[special_mode]:
				loadout[key] = int(SPECIAL_LOADOUT_EXTRA[special_mode][key])
		if SPECIAL_LOADOUT_OVERRIDE.has(special_mode):
			for key in SPECIAL_LOADOUT_OVERRIDE[special_mode]:
				loadout[key] = int(SPECIAL_LOADOUT_OVERRIDE[special_mode][key])
	return loadout
