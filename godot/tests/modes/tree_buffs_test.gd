extends SceneTree

# 攀登树 roguelike 增益：offer 去重、效果钩子纯函数、buff 定义完整性。

const TREE_BUFFS = preload("res://scripts/modes/tree_buffs.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== tree_buffs_test")

	# --- definitions: unique ids, complete copy
	var ids := {}
	var defs_ok := true
	for buff in TREE_BUFFS.BUFF_POOL:
		if ids.has(buff["id"]) or str(buff["icon"]) == "" or str(buff["name"]) == "" or str(buff["desc"]) == "":
			defs_ok = false
		ids[buff["id"]] = true
	check(defs_ok, "buff pool carries unique ids with icon/name/desc")
	check(TREE_BUFFS.BUFF_POOL.size() >= TREE_BUFFS.OFFER_SIZE, "pool is at least offer-sized")
	check(TREE_BUFFS.buff_by_id("time_gift").size() > 0, "buff_by_id finds a real buff")
	check(TREE_BUFFS.buff_by_id("nope").empty(), "buff_by_id misses unknown ids")

	# --- roll_offer: right size, distinct, always from the pool (seeded loop)
	var rolls_ok := true
	for seed_value in range(40):
		seed(seed_value * 7919 + 13)
		var offer = TREE_BUFFS.roll_offer()
		if offer.size() != TREE_BUFFS.OFFER_SIZE:
			rolls_ok = false
			break
		var seen := {}
		for buff_id in offer:
			if seen.has(buff_id) or not ids.has(buff_id):
				rolls_ok = false
			seen[buff_id] = true
	check(rolls_ok, "40 seeded rolls all return distinct in-pool ids")

	# --- roll_offer exclusions: clockless endless drops the time-bound buffs
	var excluded_ok := true
	for seed_value in range(40):
		seed(seed_value * 104729 + 7)
		var filtered = TREE_BUFFS.roll_offer(["time_gift", "tool_breeze"])
		if filtered.size() != TREE_BUFFS.OFFER_SIZE:
			excluded_ok = false
		for buff_id in filtered:
			if buff_id == "time_gift" or buff_id == "tool_breeze":
				excluded_ok = false
	check(excluded_ok, "excluded ids never surface in 40 seeded endless rolls")

	# --- effect hooks
	check(TREE_BUFFS.combo_window_mult({}) == 1.0, "no buffs keep the stock combo window")
	check(abs(TREE_BUFFS.combo_window_mult({"combo_ember": true}) - 1.4) < 0.001, "combo_ember widens the window 1.4x")
	check(not TREE_BUFFS.tools_free({}), "no buffs keep tool time costs")
	check(TREE_BUFFS.tools_free({"tool_breeze": true}), "tool_breeze lifts tool time costs")
	check(TREE_BUFFS.has_time_gift({"time_gift": true}), "time gift detected")
	check(not TREE_BUFFS.has_time_gift({}), "no time gift by default")

	var level = {"score_multiplier": 1.5}
	TREE_BUFFS.apply_score_mult(level, {})
	check(abs(float(level["score_multiplier"]) - 1.5) < 0.001, "no score buff keeps the level multiplier")
	TREE_BUFFS.apply_score_mult(level, {"score_prism": true})
	check(abs(float(level["score_multiplier"]) - 1.875) < 0.001, "score_prism multiplies by 1.25")

	var bonus = TREE_BUFFS.bonus_loadout({"bomb_gift": true, "shuffle_gift": true})
	check(int(bonus.get("bomb", 0)) == 1 and int(bonus.get("reshuffle", 0)) == 1 and not bonus.has("time"),
		"powerup gifts map onto loadout keys 1:1")
	check(TREE_BUFFS.bonus_loadout({"time_gift": true}).empty(), "the time gift is not a loadout grant")
	check(TREE_BUFFS.bonus_loadout("junk").empty(), "non-dict buffs yield no grants")

	if failures == 0:
		print("tree_buffs_test: ALL PASSED")
		quit(0)
	else:
		print("tree_buffs_test: %d FAILURES" % failures)
		quit(1)
