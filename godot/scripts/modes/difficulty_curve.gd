extends Reference

# Shared balance math for every difficulty ramp in the game, plus the audits
# that keep the shipped tables honest. Pure statics, no scene-tree or mode
# knowledge, so everything here runs headless in tests.
#
# Two families live here:
#   - plateau_int(): the one grow-then-plateau step used by the tree ladder
#     and the endless builder, so "walls grow, then stop" can never diverge
#     between modes again.
#   - audits (campaign_audit / growth_series_audit / endless_audit /
#     override_consistency_violations): each returns an Array of violation
#     strings; empty means the table satisfies the difficulty contract.
#
# Deliberately NOT asserted (they would reject shipped design): tiles and
# kinds are allowed to dip mid-campaign — 闪电战 trades size for a tight
# clock, so the pressure envelope below is the invariant, not raw size.

const VALID_MODES = {
	"classic": true,
	"rush": true,
	"combo": true,
	"endurance": true
}

# Grow-then-plateau step: base + stride per `every` units of progress,
# hard-capped. Even strides with even bases keep tile counts pairable.
static func plateau_int(base: int, cap: int, stride: int, every: int, progress: int) -> int:
	var p := progress
	if p < 0:
		p = 0
	var step := every
	if step < 1:
		step = 1
	var value := base + stride * int(p / float(step))
	if value > cap:
		value = cap
	return value


# How many seconds the clock grants per remaining pair — the one pressure
# metric that stays comparable across board sizes. Lower is tighter.
static func seconds_per_pair(rows: int, cols: int, time_limit: float) -> float:
	var tiles := rows * cols
	if tiles <= 0:
		return 0.0
	return time_limit * 2.0 / float(tiles)


# Contract for the shipped campaign table (res://data/campaign.json):
# sequential ids, sane pairable boards, kinds within the texture capacity,
# positive clocks, known modes, non-shrinking reward multipliers, and two
# pressure rules — no level is ever easier than the opening one, and every
# rush level is a spike against the level right before it.
static func campaign_audit(levels, max_kinds: int = 15) -> Array:
	var violations := []
	if typeof(levels) != TYPE_ARRAY or levels.empty():
		violations.append("campaign table is empty")
		return violations
	var first_pressure := -1.0
	var prev := {"pressure": -1.0, "score": -1.0, "effect": -1.0, "mode": ""}
	for i in range(levels.size()):
		var lv = levels[i]
		violations += _campaign_level_violations(lv, i, max_kinds, prev)
		var rows := int(lv.get("rows", 0))
		var cols := int(lv.get("cols", 0))
		var pressure := seconds_per_pair(rows, cols, float(lv.get("time_limit", 0)))
		if i == 0:
			first_pressure = pressure
		elif pressure > first_pressure + 0.0001:
			violations.append("level %d: easier than the opening level (%.2f vs %.2f s/pair)" % [i + 1, pressure, first_pressure])
		if i > 0 and str(lv.get("mode", "")) == "rush" and prev["mode"] != "rush" and pressure >= prev["pressure"] - 0.0001:
			violations.append("level %d: rush level should be tighter than its predecessor" % [i + 1])
		prev = {
			"pressure": pressure,
			"score": float(lv.get("score_multiplier", 0)),
			"effect": float(lv.get("effect_intensity", 0)),
			"mode": str(lv.get("mode", ""))
		}
	return violations


# Structural checks for one campaign level: id order, board sanity, kinds
# capacity, positive clock, known mode, present name, non-shrinking
# multipliers. `prev` carries the previous level's reward multipliers.
static func _campaign_level_violations(lv, index: int, max_kinds: int, prev: Dictionary) -> Array:
	var violations := []
	var tag := "level %d" % (index + 1)
	var rows := int(lv.get("rows", 0))
	var cols := int(lv.get("cols", 0))
	var kinds := int(lv.get("kinds", 0))
	var mode := str(lv.get("mode", ""))
	if int(lv.get("id", -1)) != index + 1:
		violations.append("%s: id should be %d" % [tag, index + 1])
	if rows < 4 or cols < 4 or (rows * cols) % 2 != 0:
		violations.append("%s: board %dx%d is not sane/pairable" % [tag, rows, cols])
	if kinds < 4 or kinds > max_kinds:
		violations.append("%s: kinds %d outside 4..%d" % [tag, kinds, max_kinds])
	if kinds * 2 > rows * cols:
		violations.append("%s: not enough tiles for %d kinds" % [tag, kinds])
	if float(lv.get("time_limit", 0)) <= 0.0:
		violations.append("%s: time_limit must be positive" % tag)
	if not VALID_MODES.has(mode):
		violations.append("%s: unknown mode '%s'" % [tag, mode])
	if str(lv.get("name", "")) == "":
		violations.append("%s: missing name" % tag)
	if float(lv.get("score_multiplier", 0)) < prev["score"]:
		violations.append("%s: score_multiplier shrinks" % tag)
	if float(lv.get("effect_intensity", 0)) < prev["effect"]:
		violations.append("%s: effect_intensity shrinks" % tag)
	return violations


# Contract for any generated ramp (endless rounds, tree layers): boards stay
# pairable, the ramp never folds back on itself, and the clock only tightens.
static func growth_series_audit(levels) -> Array:
	var violations := []
	if typeof(levels) != TYPE_ARRAY or levels.empty():
		violations.append("growth series is empty")
		return violations
	var prev_rows := -1
	var prev_cols := -1
	var prev_kinds := -1
	var prev_time := -1.0
	for i in range(levels.size()):
		var lv = levels[i]
		var tag := "round %d" % (i + 1)
		var rows := int(lv.get("rows", 0))
		var cols := int(lv.get("cols", 0))
		var kinds := int(lv.get("kinds", 0))
		var time_limit := float(lv.get("time_limit", 0))
		if (rows * cols) % 2 != 0:
			violations.append("%s: odd tile count %dx%d" % [tag, rows, cols])
		if rows < prev_rows or cols < prev_cols:
			violations.append("%s: board shrinks" % tag)
		if kinds < prev_kinds:
			violations.append("%s: kinds shrink" % tag)
		if prev_time >= 0.0 and time_limit > prev_time:
			violations.append("%s: clock loosens" % tag)
		prev_rows = rows
		prev_cols = cols
		prev_kinds = kinds
		prev_time = time_limit
	return violations


# Sanity of the endless scaling config itself: even boards (base and cap so
# the +2 strides can keep tile counts pairable), base within caps, positive
# strides.
static func endless_audit(config) -> Array:
	var violations := []
	var base_rows := int(config.get("base_rows", 10))
	var base_cols := int(config.get("base_cols", 8))
	var max_rows := int(config.get("max_rows", 16))
	var max_cols := int(config.get("max_cols", 14))
	var base_kinds := int(config.get("base_kinds", 6))
	var max_kinds := int(config.get("max_kinds", 20))
	if base_rows % 2 != 0 or base_cols % 2 != 0:
		violations.append("base board %dx%d is odd" % [base_rows, base_cols])
	if max_rows % 2 != 0 or max_cols % 2 != 0:
		violations.append("cap board %dx%d is odd" % [max_rows, max_cols])
	if base_rows > max_rows or base_cols > max_cols:
		violations.append("base board exceeds the cap board")
	if base_kinds > max_kinds:
		violations.append("base kinds exceed the kinds cap")
	if int(config.get("board_expansion_every", 3)) < 1:
		violations.append("board_expansion_every must be >= 1")
	if int(config.get("kinds_increment_every", 1)) < 1:
		violations.append("kinds_increment_every must be >= 1")
	return violations


# Drift gate for the two-layer configuration: every field the shipped JSON
# overrides must agree with the code default, so a missing/corrupt JSON can
# never silently fall back to different balance numbers.
static func override_consistency_violations(defaults, raw) -> Array:
	var violations := []
	if typeof(raw) != TYPE_DICTIONARY or not raw.has("game_modes"):
		return violations
	var modes = raw["game_modes"]
	if typeof(modes) != TYPE_DICTIONARY:
		return violations
	for key in defaults.keys():
		if not modes.has(key) or typeof(modes[key]) != TYPE_DICTIONARY:
			continue
		var base = defaults[key]
		var override = modes[key]
		for field in override.keys():
			if base.has(field) and not _same_scalar(base[field], override[field]):
				violations.append("%s.%s: fallback %s != live %s" % [key, str(field), str(base[field]), str(override[field])])
	return violations


# Numbers compare tolerantly (JSON parses ints as floats), everything else
# as strings.
static func _same_scalar(a, b) -> bool:
	var a_num := typeof(a) == TYPE_INT or typeof(a) == TYPE_REAL
	var b_num := typeof(b) == TYPE_INT or typeof(b) == TYPE_REAL
	if a_num and b_num:
		return abs(float(a) - float(b)) < 0.0001
	return str(a) == str(b)
