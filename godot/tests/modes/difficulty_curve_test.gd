extends SceneTree

# Difficulty-contract gates: the shared plateau math, the live campaign
# table's pressure invariants, the endless/tree ramps, and the consistency
# of the two-layer configuration (code defaults vs data/game_modes.json)
# plus the generated campaign mirror vs data/campaign.json. A violation
# string anywhere here means the shipped difficulty drifted from its design.

const CURVE = preload("res://scripts/modes/difficulty_curve.gd")
const CL = preload("res://scripts/modes/campaign_levels.gd")
const SPECIAL_MODES_SCRIPT = preload("res://scripts/modes/special_modes.gd")
const TREE_LADDER = preload("res://scripts/modes/tree_ladder.gd")

var failures := 0


func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)


func _load_json(path: String):
	var file = File.new()
	if not file.file_exists(path):
		return null
	file.open(path, File.READ)
	var parsed = parse_json(file.get_as_text())
	file.close()
	return parsed


func _same_number(a, b) -> bool:
	return abs(float(a) - float(b)) < 0.0001


func _tables_match(live_levels, mirror_levels) -> bool:
	if live_levels.size() != mirror_levels.size():
		return false
	for i in range(live_levels.size()):
		var a = live_levels[i]
		var b = mirror_levels[i]
		for key in a.keys():
			if not b.has(key):
				return false
			var va = a[key]
			var vb = b[key]
			if typeof(va) == TYPE_REAL or typeof(va) == TYPE_INT:
				if not _same_number(va, vb):
					return false
			elif str(va) != str(vb):
				return false
	return true


func _init() -> void:
	# --- plateau_int: one grow-then-plateau step for every ramp
	check(CURVE.plateau_int(8, 14, 2, 12, 0) == 8, "plateau at zero progress is the base")
	check(CURVE.plateau_int(8, 14, 2, 12, 12) == 10, "one full stride period adds the stride")
	check(CURVE.plateau_int(8, 14, 2, 12, 24) == 12, "two periods compound")
	check(CURVE.plateau_int(8, 14, 2, 12, 9999) == 14, "the cap holds no matter the progress")
	check(CURVE.plateau_int(8, 14, 2, 12, -5) == 8, "negative progress clamps to the base")
	check(CURVE.plateau_int(6, 20, 5, 0, 10) == 20, "a zero/negative period means the stride applies every round")
	check(CURVE.plateau_int(10, 8, 2, 3, 99) == 8, "a cap below the base clamps immediately")

	# --- plateau_int reproduces the retired hand-rolled tree formulas
	var equiv := true
	for h in [1, 2, 12, 13, 24, 25, 40, 61, 100, 160, 161, 999, 5000]:
		var progress = h - 1
		var rows_old = min(8 + 2 * int(progress / 12.0), 14)
		var cols_old = min(6 + 2 * int(progress / 20.0), 10)
		var kinds_old = min(6 + int(progress / 8.0), 12)
		if CURVE.plateau_int(8, 14, 2, 12, progress) != int(rows_old) \
				or CURVE.plateau_int(6, 10, 2, 20, progress) != int(cols_old) \
				or CURVE.plateau_int(6, 12, 1, 8, progress) != int(kinds_old):
			equiv = false
	check(equiv, "plateau_int matches the retired inline tree math")

	# --- seconds_per_pair: the cross-board pressure metric
	check(_same_number(CURVE.seconds_per_pair(8, 6, 90), 3.75), "level 1 grants 3.75 s/pair")
	check(CURVE.seconds_per_pair(0, 0, 90) == 0.0, "an empty board has no pressure metric")

	# --- live campaign table satisfies the difficulty contract
	var live = _load_json("res://data/campaign.json")
	var live_levels = live.get("levels", []) if typeof(live) == TYPE_DICTIONARY else []
	var violations = CURVE.campaign_audit(live_levels)
	check(violations.empty(), "live campaign.json passes the difficulty audit: %s" % str(violations))

	# --- the generated mirror stays in lockstep with the live table
	var mirror = CL.default_campaign_levels()
	check(_tables_match(live_levels, mirror), "campaign_levels.gd mirror equals campaign.json")
	check(CURVE.campaign_audit(mirror).empty(), "the mirror passes the same audit")

	# --- endless config: sane scaling + a 60-round ramp that never folds
	var raw_modes = _load_json("res://data/game_modes.json")
	var endless_config = SPECIAL_MODES_SCRIPT.normalize_configs(raw_modes)["endless"]
	check(CURVE.endless_audit(endless_config).empty(), "endless config audit passes")
	var rounds := []
	for round_index in range(1, 61):
		rounds.append(SPECIAL_MODES_SCRIPT.build_endless_level(endless_config, round_index))
	check(CURVE.growth_series_audit(rounds).empty(), "60 endless rounds ramp monotonically and stay pairable")
	check(int(rounds[59]["kinds"]) <= int(endless_config["max_kinds"]), "endless kinds respect the cap")

	# --- consistency gate: shipped JSON overrides equal the code defaults
	check(CURVE.override_consistency_violations(SPECIAL_MODES_SCRIPT.DEFAULT_CONFIGS, raw_modes).empty(),
		"game_modes.json overrides agree with the code defaults")

	# --- tree ladder: the shared math keeps its ramp contract over 400 layers
	var layers := []
	for h in range(1, 401):
		layers.append(TREE_LADDER.level_for(h))
	check(CURVE.growth_series_audit(layers).empty(), "400 tree layers ramp monotonically, pairable, clock tightens")

	if failures == 0:
		print("difficulty_curve_test: ALL PASSED")
		quit(0)
	else:
		print("difficulty_curve_test: %d FAILURES" % failures)
		quit(1)
