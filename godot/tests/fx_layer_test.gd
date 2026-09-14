extends SceneTree

# Unit tests for fx_layer.gd's pure combo-tier visuals: color/particle
# escalation per combo band and intensity scaling. (The node-bound effects —
# rings, star tweens, petals — stay covered by the scene probes.)

const FX = preload("res://scripts/ui/fx_layer.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== fx_layer_test")

	# --- baseline: below the first tier
	var low = FX._combo_visuals(0, 1.0)
	check(low["color"].to_html() == Color("ff7a00").to_html(), "low combo keeps the orange ring")
	check(low["particle_color"].to_html() == Color("ffffff").to_html(), "low combo keeps white particles")
	check(low["particle_count"] == 8, "baseline particle count scales with intensity (6 + 2x)")

	# --- every tier boundary lands on its band
	var gold = FX._combo_visuals(10, 1.0)
	check(gold["color"].to_html() == Color("ffd700").to_html() and gold["particle_count"] == 30,
		"combo 10 ignites gold at full particle count")
	var purple = FX._combo_visuals(7, 1.0)
	check(purple["color"].to_html() == Color("e64980").to_html() and purple["particle_count"] == 24,
		"combo 7 shifts to magenta at 24 particles")
	var blue = FX._combo_visuals(5, 1.0)
	check(blue["particle_color"].to_html() == Color("60a5fa").to_html() and blue["particle_count"] == 18,
		"combo 5 uses blue particles at 18")
	var green = FX._combo_visuals(3, 1.0)
	check(green["color"].to_html() == Color("0ca678").to_html() and green["particle_count"] == 12,
		"combo 3 shifts to green at 12")

	# --- just below each boundary stays in the lower band
	check(FX._combo_visuals(9, 1.0)["particle_count"] == 24, "combo 9 is still the 7-band")
	check(FX._combo_visuals(6, 1.0)["particle_count"] == 18, "combo 6 is still the 5-band")
	check(FX._combo_visuals(4, 1.0)["particle_count"] == 12, "combo 4 is still the 3-band")
	check(FX._combo_visuals(2, 1.0)["particle_count"] == 8, "combo 2 is still the baseline")

	# --- effect_intensity scales the tier particle counts
	var hot = FX._combo_visuals(10, 0.5)
	check(hot["particle_count"] == 15, "intensity halves the tier count")
	var mild = FX._combo_visuals(3, 1.5)
	check(mild["particle_count"] == 18, "intensity above 1 scales up too")
	var scaled_base = FX._combo_visuals(0, 1.5)
	check(scaled_base["particle_count"] == 9, "the baseline scales with intensity as well")

	# --- combo 11+ stays gold (no runaway tiers)
	var over = FX._combo_visuals(25, 1.0)
	check(over["particle_count"] == 30 and over["color"].to_html() == Color("ffd700").to_html(),
		"combo beyond the table holds the top band")

	if failures == 0:
		print("fx_layer_test: ALL PASSED")
		quit(0)
	else:
		print("fx_layer_test: %d FAILURES" % failures)
		quit(1)
