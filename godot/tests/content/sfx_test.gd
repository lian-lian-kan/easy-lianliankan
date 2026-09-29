extends SceneTree

# Unit tests for scripts/content/sfx.gd — the sound-effect catalog. The
# catalog is pure data: pools of note-recipes per event, drawn through
# shuffled decks (no repeats until dry). Playback itself stays in the
# AudioManager autoload; here we lock the data invariants.

const SFX = preload("res://scripts/content/sfx.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")
	print("== sfx_test")

	# --- data invariants: every pool non-empty, every note well-formed
	check(SFX.pools_valid(), "every pool is non-empty with well-formed notes")

	# --- all events the play_* wrappers rely on actually exist
	for key in ["select", "eliminate", "combo_3", "combo_5", "combo_7", "combo_10",
			"error", "hint", "win", "fail", "shuffle", "click", "time_warning", "coin"]:
		check(SFX.POOLS.has(key), "pool exists: %s" % key)

	# --- combo tier mapping
	check(SFX.key_for_combo(0) == "eliminate" and SFX.key_for_combo(2) == "eliminate",
			"combos below 3 fall back to the base eliminate dyad")
	check(SFX.key_for_combo(3) == "combo_3" and SFX.key_for_combo(5) == "combo_5"
			and SFX.key_for_combo(7) == "combo_7" and SFX.key_for_combo(10) == "combo_10"
			and SFX.key_for_combo(25) == "combo_10",
			"combo tiers map onto their arpeggio pools")

	# --- draw returns well-formed recipes and the deck never repeats early
	# 持有者直接用真 audio_manager 类实例（draw 只碰 sfx_decks，不依赖树）。
	var holder = load("res://scripts/audio_manager.gd").new()
	var pool_size: int = SFX.POOLS["eliminate"].size()
	var seen := {}
	var repeats := 0
	for _i in range(pool_size):
		var recipe = SFX.draw(holder, "eliminate")
		check(not recipe.empty(), "draw returns a recipe")
		var signature = str(recipe)
		if seen.has(signature):
			repeats += 1
		seen[signature] = true
	check(repeats == 0, "no variant repeats before the deck runs dry")
	# One more draw past the dry deck reshuffles and still serves a recipe.
	check(not SFX.draw(holder, "eliminate").empty(), "drawing past a dry deck reshuffles cleanly")
	check(holder.sfx_decks.has("eliminate"), "the deck state lives on the holder")
	holder.free()

	if failures == 0:
		print("sfx_test: ALL PASSED")
		quit(0)
	else:
		print("sfx_test: %d FAILURES" % failures)
		quit(1)
