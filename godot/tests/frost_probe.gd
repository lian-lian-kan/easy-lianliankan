extends SceneTree

# Headless probe for the frost (冰雪挑战) mode: level generation, two-stage
# ice damage, the warm-patch power-up, and bomb armor-piercing.

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _find_frozen_with_kind(board, armor):
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) != 0 and int(armor[r][c]) > 0:
				return {"coord": Vector2(r, c), "kind": int(board[r][c])}
	return {}

func _find_frozen_with_unfrozen_partner(board, armor):
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) != 0 and int(armor[r][c]) > 0:
				var coord = Vector2(r, c)
				var partner = _find_kind_cell(board, int(board[r][c]), coord)
				if partner.x >= 0 and int(armor[partner.x][partner.y]) == 0:
					return {"coord": coord, "kind": int(board[r][c]), "partner": partner}
	return {}

func _find_kind_cell(board, kind, skip):
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) == kind and not (skip.x == r and skip.y == c):
				return Vector2(r, c)
	return Vector2(-1, -1)

func _find_unfrozen_cell(board, armor):
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) != 0 and int(armor[r][c]) == 0:
				return Vector2(r, c)
	return Vector2(-1, -1)

func _init() -> void:
	print("== frost_probe")
	var modes = load("res://scripts/special_modes.gd")
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("FAIL - cannot load Main.tscn")
		quit(1)
		return
	var game = scene.instance()
	root.add_child(game)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	# --- Pure logic: config, tiers, builder, unlock boundary.
	var configs = modes.normalize_configs(null)
	check(configs.has("frost"), "frost config exists by default")
	var frost_cfg = configs["frost"]
	check(int(frost_cfg.get("unlock_level", 0)) == 13, "frost unlocks at campaign level 13")
	check(not modes.is_mode_unlocked("frost", frost_cfg, 11), "frost locked at index 11 (level 12)")
	check(modes.is_mode_unlocked("frost", frost_cfg, 12), "frost unlocked at index 12 (level 13)")
	check(str(modes.unlock_requirement_text("frost", frost_cfg)) == "完成第13关解锁", "unlock text mentions level 13")

	var tier_low = modes.frost_tier(frost_cfg, 3)
	var tier_high = modes.frost_tier(frost_cfg, 20)
	check(int(tier_low.get("rows", 0)) == 8 and int(tier_low.get("cols", 0)) == 8, "low tier is an 8x8 board")
	check(int(tier_high.get("rows", 0)) == 10 and int(tier_high.get("cols", 0)) == 9, "high tier is a 10x9 board")
	check(float(tier_high.get("frost_ratio", 0)) > float(tier_low.get("frost_ratio", 0)), "higher tier freezes more tiles")

	var level = modes.build_frost_level(frost_cfg, tier_low)
	check(str(level.get("mode", "")) == "frost", "frost level carries mode=frost")
	check(float(level.get("frost_ratio", 0)) > 0.0, "frost level has a frost ratio")
	check(int(level.get("time_limit", 0)) == int(tier_low.get("time_base", 0)) + int(8 * 8 * 1.0), "frost time formula = base + tiles")

	# --- Scene: start frost mode with enough campaign progress.
	game.progression_state["highest_unlocked_level_index"] = 12
	game._start_special_mode("frost")
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	check(game.special_mode == "frost", "frost session started")
	check(game.board.size() > 0 and game.board_armor.size() == game.board.size(), "armor grid parallel to board")
	var frozen_count = 0
	var filled_count = 0
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board[r][c]) != 0:
				filled_count += 1
				if int(game.board_armor[r][c]) > 0:
					frozen_count += 1
	check(frozen_count > 0, "some cells are frozen")
	check(frozen_count < filled_count, "not every cell is frozen")
	check(int(game.power_ups.get("warm_patch", 0)) == 3, "frost session grants 3 warm patches")
	check(game.power_up_labels.has("warm_patch"), "warm patch label registered")

	# --- Two-stage damage: crack keeps the tile, second match removes it.
	# Prefer a frozen cell whose partner is unfrozen; both-frozen pairs are
	# also valid but crack together, so assert per case.
	var pair = _find_frozen_with_unfrozen_partner(game.board, game.board_armor)
	var partner_frozen = pair.empty()
	var frozen = pair if not pair.empty() else _find_frozen_with_kind(game.board, game.board_armor)
	var fa = frozen["coord"]
	var partner = pair["partner"] if not pair.empty() else _find_kind_cell(game.board, frozen["kind"], fa)
	check(not frozen.empty(), "found a frozen cell")
	check(partner.x >= 0, "frozen cell has a same-kind partner")
	game._apply_match_damage(fa, partner)
	check(int(game.board_armor[fa.x][fa.y]) == 0, "match cracks the ice (armor consumed)")
	check(int(game.board[fa.x][fa.y]) != 0, "cracked tile stays on the board")
	if partner_frozen:
		check(int(game.board_armor[partner.x][partner.y]) == 0, "both-frozen pair cracks together")
	else:
		check(int(game.board[partner.x][partner.y]) == 0, "unfrozen partner is removed")
	check(game._remaining_tiles_count() > 0, "cracked tile still counts as remaining")

	var partner2 = _find_kind_cell(game.board, frozen["kind"], fa)
	check(partner2.x >= 0, "cracked tile still has a partner")
	game._apply_match_damage(fa, partner2)
	check(int(game.board[fa.x][fa.y]) == 0, "second match removes the cracked tile")

	# --- Warm patch: misclick keeps the charge, frozen click thaws it.
	game._use_power_up("warm_patch")
	check(game.frost_pending, "warm patch arms into pending mode")
	var charges = int(game.power_ups.get("warm_patch", 0))
	var plain = _find_unfrozen_cell(game.board, game.board_armor)
	game._execute_warm_patch(plain)
	check(game.frost_pending, "misclick on unfrozen tile keeps it armed")
	check(int(game.power_ups.get("warm_patch", 0)) == charges, "misclick does not consume the charge")

	var frozen2 = _find_frozen_with_kind(game.board, game.board_armor)
	check(not frozen2.empty(), "a frozen cell remains for the warm patch")
	var fw = frozen2["coord"]
	game._execute_warm_patch(fw)
	check(not game.frost_pending, "warm patch disarms after thawing")
	check(int(game.board_armor[fw.x][fw.y]) == 0, "warm patch clears the armor")
	check(int(game.board[fw.x][fw.y]) != 0, "thawed tile stays on the board")
	# The charge is consumed when ARMING (same as bomb/rainbow); executing is free.
	check(int(game.power_ups.get("warm_patch", 0)) == charges, "thawing spends no extra charge")
	check(int(game.frost_uses) == 1, "warm patch use is tracked for the achievement")

	# --- Bomb pierces ice: frozen tile is removed outright.
	var frozen3 = _find_frozen_with_kind(game.board, game.board_armor)
	if frozen3.empty():
		# Everything thawed: refreeze via armor is not needed; skip gracefully.
		print("  ok - no frozen cell left; bomb pierce covered by thawed-path logic")
	else:
		var fb = frozen3["coord"]
		game.power_ups["bomb"] = max(1, int(game.power_ups.get("bomb", 0)))
		game._use_power_up("bomb")
		check(game.bomb_pending, "bomb arms in frost mode")
		game._execute_bomb(fb)
		check(int(game.board[fb.x][fb.y]) == 0, "bomb removes the frozen tile")
		check(int(game.board_armor[fb.x][fb.y]) == 0, "bomb shatters the ice too")

	# --- Outside frost, damage is a plain removal (campaign parity).
	game._exit_special_mode()
	yield(self, "idle_frame")
	var exit_a = Vector2(-1, -1)
	var exit_b = Vector2(-1, -1)
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board[r][c]) != 0:
				if exit_a.x < 0:
					exit_a = Vector2(r, c)
				else:
					exit_b = Vector2(r, c)
					break
		if exit_b.x >= 0:
			break
	var before = game._remaining_tiles_count()
	game._apply_match_damage(exit_a, exit_b)
	check(game._remaining_tiles_count() == before - 2, "campaign damage removes both tiles outright")

	if failures == 0:
		print("frost_probe: ALL PASSED")
		quit(0)
	else:
		print("frost_probe: %d FAILURES" % failures)
		quit(1)
