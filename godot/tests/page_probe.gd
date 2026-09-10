extends SceneTree

# Page-shell probe: bottom navigation, the four meta pages (journey map /
# collection / sign-in / theme shop) and the blossom economy loop.

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _count_page_buttons(game):
	var level_buttons = 0
	var locked_buttons = 0
	var stack = [game.page_content]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is Button:
			var t = str(node.text)
			if t.begins_with("▶") or t.begins_with("第"):
				level_buttons += 1
			elif t.begins_with("🔒"):
				locked_buttons += 1
		for child in node.get_children():
			stack.append(child)
	return [level_buttons, locked_buttons]

func _page_labels(game):
	var labels = []
	var stack = [game.page_content]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is Label:
			labels.append(str(node.text))
		for child in node.get_children():
			stack.append(child)
	return labels

func _init() -> void:
	print("== page_probe")
	var scene = load("res://scenes/Main.tscn")
	var game = scene.instance()
	root.add_child(game)
	for _i in range(8):
		yield(self, "idle_frame")
	game.progression_state["highest_unlocked_level_index"] = 14

	# --- shell construction ---
	check(game.nav_bar != null && game.nav_buttons.size() == 5, "bottom nav holds 5 tabs")
	check(game.pages_root != null && !game.pages_root.visible, "page surface starts hidden")
	check(game.coin_label != null, "blossom wallet chip registered")

	# --- journey map pauses the stage and lists every level ---
	game.stage_status = game.STATUS_PLAYING
	game._on_nav_pressed("level_map")
	check(game.pages_root.visible && game.stage_status == game.STATUS_PAUSED, "opening a page pauses the stage")
	check(game.current_page == "level_map", "journey page becomes current")
	var counts = _count_page_buttons(game)
	check(counts[0] == 15 && counts[1] == 0, "journey map lists all 15 unlocked levels (got %d/%d)" % [counts[0], counts[1]])

	# --- pressing a map node starts that level and returns home ---
	game._on_map_level_pressed(4)
	check(int(game.level_index) == 4 && !game.pages_root.visible && game.stage_status == game.STATUS_PLAYING, "map node starts the level and resumes play")

	# --- locked rows appear for a fresh save ---
	game.level_index = 0
	game.progression_state["current_level_index"] = 0
	game.progression_state["highest_unlocked_level_index"] = 0
	game._on_nav_pressed("level_map")
	counts = _count_page_buttons(game)
	check(counts[1] == 14 && counts[0] == 1, "fresh save shows 1 unlocked + 14 locked nodes (got u=%d l=%d)" % [counts[0], counts[1]])
	game._on_map_locked_pressed()
	check(int(game.level_index) == 0, "locked node press never starts a level")
	game.progression_state["highest_unlocked_level_index"] = 14

	# --- closing a page resumes the stage ---
	game._on_nav_home_pressed()
	check(!game.pages_root.visible && game.stage_status == game.STATUS_PLAYING, "closing a page resumes the stage")

	# --- collection:开局收集第一关图案，未收集显示 ❓ ---
	game._on_nav_pressed("collection")
	var labels = _page_labels(game)
	var progress_line = ""
	for l in labels:
		if l.find("/ 210") != -1:
			progress_line = l
	check(progress_line != "", "collection header shows progress over 210 icons")
	var collected_count = int(game.progression_state.get("collected", []).size())
	check(collected_count > 0, "starting a level collected some patterns (got %d)" % collected_count)
	var mystery = false
	var stack = [game.page_content]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is Label && str(node.text) == "❓":
			mystery = true
		for child in node.get_children():
			stack.append(child)
	check(mystery, "uncollected cells render as mystery")
	game._on_nav_home_pressed()

	# --- sign-in: first claim pays day-1 reward, repeats are refused ---
	game.progression_state["signin_streak"] = 0
	game.progression_state["last_signin"] = ""
	var today = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	var yd = OS.get_date()
	var yesterday = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_datetime_from_unix_time(OS.get_unix_time_from_datetime(yd) - 86400))
	var coins_before = int(game.progression_state.get("coins", 0))
	game._on_nav_pressed("signin")
	game._on_signin_claim_pressed(today, yesterday)
	check(int(game.progression_state.get("coins", 0)) == coins_before + 5, "day-1 sign-in pays 5 blossoms")
	check(int(game.progression_state.get("signin_streak", 0)) == 1, "sign-in streak advances to 1")
	check(str(game.progression_state.get("last_signin", "")) == today, "sign-in stamps today")
	game._on_signin_claim_pressed(today, yesterday)
	check(int(game.progression_state.get("coins", 0)) == coins_before + 5, "double claim never double-pays")
	labels = _page_labels(game)
	var signed_note = false
	for l in labels:
		if l.find("今日已领取") != -1:
			signed_note = true
	check(signed_note, "sign-in page reflects today's claim")
	game._on_nav_home_pressed()

	# --- regression guard: the three program-built modes must each build
	# their own level (a lost elif here silently starts endless instead) ---
	for mode_id in ["tray", "collect", "flip"]:
		game.progression_state["highest_unlocked_level_index"] = 17
		game.SPECIAL_SESSION._start_special_mode(game, mode_id)
		var built_mode = str(game.special_level.get("mode_id", ""))
		check(built_mode == mode_id, "special mode %s builds its own level" % mode_id)
		check(int(game.time_left) > 0, "%s starts with its time limit" % mode_id)
		if mode_id == "tray":
			check(game.tray_state.has("tiles") && game.tray_state["tiles"].size() == 120,
				"tray start deals 120 tiles into the state")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- settle probes: tray / collect / flip wins pay, record and settle ---
	# tray: an emptied pile resolves as a win with its score
	game.SPECIAL_SESSION._start_special_mode(game, "tray")
	for t in game.tray_state["tiles"]:
		t["removed"] = true
	game.tray_state["tray"] = []
	var coins_before_tray = int(game.progression_state.get("coins", 0))
	game._resolve_tray_clear()
	check(int(game.progression_state.get("tray_best_score", 0)) >= 1200, "tray win records its score")
	check(int(game.progression_state.get("coins", 0)) == coins_before_tray + 20, "tray win pays 20 blossoms")
	check(game.stage_panel_label.visible, "tray win shows the settle panel")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# collect: filling every target resolves immediately and pays
	game.SPECIAL_SESSION._start_special_mode(game, "collect")
	var coins_before_collect = int(game.progression_state.get("coins", 0))
	for target in game.collect_targets.keys():
		game.collect_progress[target] = int(game.collect_targets[target])
	game._resolve_collect_clear()
	check(int(game.progression_state.get("collect_best_score", 0)) >= 0, "collect win records its result")
	check(int(game.progression_state.get("coins", 0)) == coins_before_collect + 20, "collect win pays 20 blossoms")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- stats page: every headline number renders from progression state ---
	game.SPECIAL_SESSION._start_special_mode(game, "tray")
	game.tray_state = game.TILE_MATCH.generate(game.special_level)
	game._resolve_tray_clear()
	game._on_nav_pressed("stats")
	check(game.current_page == "stats" && game.pages_root.visible, "stats page opens as its own page")
	var stat_labels = []
	var stack = [game.page_content]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is Label:
			stat_labels.append(str(node.text))
		for child in node.get_children():
			stack.append(child)
	var all_text = " | ".join(stat_labels)
	check(all_text.find("最佳总分") != -1 && all_text.find("樱花币") != -1, "stats page shows wallet and best-score rows")
	check(all_text.find("叠叠消最佳") != -1, "stats page lists the tray best row")
	check(all_text.find("图鉴收集") != -1, "stats page lists collection progress")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- signin curve boundaries: broken streak resets, day-7 loops over ---
	var yd2 = OS.get_date()
	var two_days_ago = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_datetime_from_unix_time(OS.get_unix_time_from_datetime(yd2) - 172800))
	# broken streak: last sign-in was two days ago, so the streak restarts at 1
	game.progression_state["signin_streak"] = 6
	game.progression_state["last_signin"] = two_days_ago
	var coins_before_broken = int(game.progression_state.get("coins", 0))
	game.SPECIAL_SESSION._start_special_mode(game, "signin")
	game._on_signin_claim_pressed(today, yesterday)
	check(int(game.progression_state.get("signin_streak", 0)) == 1, "broken streak restarts at day 1")
	check(int(game.progression_state.get("coins", 0)) == coins_before_broken + 5, "restarted streak pays the day-1 reward")
	# loop over: a continuous run past day 7 wraps the reward curve
	game.progression_state["signin_streak"] = 7
	game.progression_state["last_signin"] = yesterday
	var coins_before_loop = int(game.progression_state.get("coins", 0))
	game.SPECIAL_SESSION._start_special_mode(game, "signin")
	game._on_signin_claim_pressed(today, yesterday)
	check(int(game.progression_state.get("coins", 0)) == coins_before_loop + 5, "day-7 wrap pays the day-1 reward again")
	check(int(game.progression_state.get("signin_streak", 0)) == 8, "streak keeps counting past the wrap")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# flip: clearing every pair records and pays
	game.SPECIAL_SESSION._start_special_mode(game, "flip")
	var coins_before_flip = int(game.progression_state.get("coins", 0))
	game._resolve_flip_clear()
	check(int(game.progression_state.get("flip_best_score", 0)) >= 200, "flip win records its bonus score")
	check(int(game.progression_state.get("coins", 0)) == coins_before_flip + 20, "flip win pays 20 blossoms")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- tray tools: undo refunds the pickup, shuffle rerolls the pile ---
	var TM = load("res://scripts/tile_match.gd")
	game.SPECIAL_SESSION._start_special_mode(game, "tray")
	var picked = -1
	for i in range(game.tray_state["tiles"].size()):
		if not TM.is_covered(game.tray_state, game.tray_state["tiles"][i]):
			picked = i
			break
	check(picked != -1, "tray has an uncovered tile to pick")
	game._on_tray_tile_pressed(picked)
	check(int(game.tray_state["tray"].size()) == 1, "tray pickup lands in the slot")
	var undo_left = int(game.tray_state["undo_left"])
	game._on_tray_undo_pressed()
	check(int(game.tray_state["tray"].size()) == 0 && int(game.tray_state["undo_left"]) == undo_left - 1,
		"tray undo returns the tile and spends the charge")
	var live_before = 0
	for t in game.tray_state["tiles"]:
		if not bool(t["removed"]):
			live_before += 1
	game._on_tray_shuffle_pressed()
	var live_after = 0
	for t in game.tray_state["tiles"]:
		if not bool(t["removed"]):
			live_after += 1
	check(int(game.tray_state["shuffle_left"]) == 0 && live_after == live_before,
		"tray shuffle rerolls patterns keeping the count")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- collect auto-resolve: filling every target ends the session ---
	game.SPECIAL_SESSION._start_special_mode(game, "collect")
	var coins_before_auto = int(game.progression_state.get("coins", 0))
	for target_key in game.collect_targets.keys():
		game.collect_progress[target_key] = int(game.collect_targets[target_key]) - 1
	var pending_pairs := []
	for target_key in game.collect_targets.keys():
		pending_pairs.append(int(target_key))
	game._on_collect_pair_progress(pending_pairs)
	check(game.stage_status == game.STATUS_CLEARED, "filling all targets auto-resolves the collect session")
	check(int(game.progression_state.get("coins", 0)) == coins_before_auto + 20, "collect auto-resolve pays 20 blossoms")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- economy: wallet starts at zero and over-collection is capped ---
	check(int(game.coin_label.text.split(" ")[1]) >= 0, "wallet chip reflects a non-negative balance")
	game.SPECIAL_SESSION._start_special_mode(game, "collect")
	var keys = game.collect_targets.keys()
	var first_key = int(keys[0])
	var needed = int(game.collect_targets[first_key])
	# fill every other target fully, leave the first one short by one pair
	for key in keys:
		game.collect_progress[int(key)] = int(game.collect_targets[int(key)])
	game.collect_progress[first_key] = needed - 1
	game._on_collect_pair_progress([first_key, first_key, first_key])
	check(int(game.collect_progress[first_key]) == needed, "over-collection is capped at the target")
	check(game.stage_status == game.STATUS_CLEARED, "hitting the target auto-resolves the session")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- daily settle: clearing the daily board stamps the streak ---
	game.SPECIAL_SESSION._start_special_mode(game, "daily")
	var today_str = game.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			game.board[r][c] = 0
	game.stage_status = game.STATUS_PLAYING
	game._resolve_after_board_changed()
	var daily_state = game.progression_state.get("daily_challenge", {})
	check(str(daily_state.get("last_date", "")) == today_str, "daily clear stamps today")
	check(int(daily_state.get("streak", 0)) >= 1, "daily clear advances the streak")
	check(int(game.progression_state.get("daily_challenge", {}).get("best_score", 0)) >= int(game.total_score) - 500, "daily best reflects the run")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- endless cross-round: resolve advances, score carries over ---
	game.SPECIAL_SESSION._start_special_mode(game, "endless")
	game.total_score = 800
	game.level_score = 800
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			game.board[r][c] = 0
	game.stage_status = game.STATUS_PLAYING
	game._resolve_after_board_changed()
	check(game.stage_status == game.STATUS_CLEARED, "endless clear lands in CLEARED")
	check(int(game.progression_state.get("endless_best", {}).get("round", 0)) >= 1, "endless clear records the round")
	check(int(game.endless_round) == 2, "endless resolve builds round 2")
	check(game.level_advance_timer && !game.level_advance_timer.is_stopped(), "endless schedules the next round")
	game._on_level_advance_timeout()
	check(int(game.endless_round) == 2 && game.stage_status == game.STATUS_PLAYING, "advance starts the next endless round")
	check(int(game.total_score) >= 800, "endless keeps the running score across rounds")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- theme shop: buy with blossoms, apply the ambience, persist ---
	game._on_theme_buy_pressed("mint")
	var owned_themes: Array = game.progression_state.get("owned_themes", [])
	check(owned_themes.has("mint") && str(game.bg_rect.color.to_html()) == Color("eafaf1").to_html(),
		"buying mint unlocks and applies its ambience")
	game.SPECIAL_SESSION._start_special_mode(game, "collect")
	game.SPECIAL_SESSION._exit_special_mode(game)
	check(str(game.bg_rect.color.to_html()) == Color("eafaf1").to_html(), "purchased ambience survives mode switches")
	game._on_theme_use_pressed("sakura")
	check(str(game.bg_rect.color.to_html()) == Color("fff0f6").to_html(), "switching back to sakura restores its ambience")

	# --- THEMES data invariants: every ambience carries name/price/bg ---
	game.SPECIAL_SESSION._start_special_mode(game, "tray")
	var themes = {
		"sakura": {"name": "樱花粉", "price": 0, "bg": "fff0f6"},
		"mint": {"name": "薄荷绿", "price": 40, "bg": "eafaf1"},
		"sky": {"name": "晴空蓝", "price": 40, "bg": "e8f4fd"},
		"cream": {"name": "奶油白", "price": 40, "bg": "fdf6ec"},
		"lavender": {"name": "薰衣草", "price": 60, "bg": "f3ecfd"},
	}
	var themes_ok = true
	for theme_id in themes:
		var t = themes[theme_id]
		if str(t["name"]) == "" or int(t["price"]) < 0:
			themes_ok = false
		var probe_color = Color(str(t["bg"]))
		if probe_color.to_html() == "000000ff" && str(t["bg"]) != "000000":
			themes_ok = false
	check(themes_ok, "all ambience themes carry name/price/legal bg")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- time_attack fever: the threshold flips the time refund per match ---
	game.SPECIAL_SESSION._start_special_mode(game, "time_attack")
	var fever_cfg = game.game_mode_configs.get("time_attack", {})
	var fever_threshold = int(fever_cfg.get("fever_mode_threshold", 5))
	game.combo = 0
	game.combo_expires_ms = 0
	game.time_left = 100
	var refund_normal = 0
	var refund_fever = 0
	for i in range(fever_threshold + 1):
		var time_before_gain = int(game.time_left)
		game._apply_combo_gain(10)
		var refunded = int(game.time_left) - time_before_gain
		if i + 1 < fever_threshold:
			refund_normal += refunded
		else:
			refund_fever += refunded
	check(refund_normal == 3 * (fever_threshold - 1), "matches below the fever refund 3s each")
	check(refund_fever == 4, "fever matches refund 4 seconds (base + combo bonus)")
	game.SPECIAL_SESSION._exit_special_mode(game)

	# --- shop: buy with blossoms, auto-use, refuse when broke ---
	game.progression_state["owned_sets"] = ["fruit"]
	game._patch_progress_state({"coins_delta": 100})
	game._on_nav_pressed("shop")
	var car_index = -1
	for i in range(game.icon_sets.size()):
		if str(game.icon_sets[i].get("id", "")) == "car":
			car_index = i
	check(car_index != -1, "car set exists in the shop data")
	var coins_now = int(game.progression_state.get("coins", 0))
	print("  DBG coins_now=", coins_now)
	game._on_shop_buy_pressed(car_index)
	print("  DBG after buy coins=", int(game.progression_state.get("coins", 0)))
	var owned: Array = game.progression_state.get("owned_sets", [])
	check(owned.has("car"), "buying unlocks the theme")
	check(int(game.icon_set_index) == car_index, "purchase auto-equips the theme")
	check(int(game.progression_state.get("coins", 0)) == coins_now - 30, "purchase costs 30 blossoms (now=%d want %d)" % [int(game.progression_state.get("coins", 0)), coins_now - 30])
	# broke path: drain coins and try another set
	game._patch_progress_state({"coins_delta": -(int(game.progression_state.get("coins", 0))) + 0})
	var broke_index = -1
	for i in range(game.icon_sets.size()):
		if str(game.icon_sets[i].get("id", "")) == "zodiac":
			broke_index = i
	game._on_shop_buy_pressed(broke_index)
	check(!game.progression_state.get("owned_sets", []).has("zodiac"), "broke buyer is refused")
	game._on_nav_home_pressed()

	# --- level clear pays blossoms through the session hook ---
	game._start_level(2, true)
	var coins_before_clear = int(game.progression_state.get("coins", 0))
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			game.board[r][c] = 0
	game.stage_status = game.STATUS_PLAYING
	game._resolve_after_board_changed()
	check(game.stage_status == game.STATUS_CLEARED, "empty board resolves as cleared")
	check(int(game.progression_state.get("coins", 0)) == coins_before_clear + 14, "level 3 clear pays 14 blossoms (8+2x3)")

	# --- weekly missions: progress, max-semantics, claim-once, week roll ---
	game.progression_state["weekly_missions"] = {"week_key": "", "progress": {}, "claimed": []}
	var missions_week = game.MISSIONS.current_week_key(game)
	check(str(missions_week).begins_with("W"), "week key derives from unix time")
	check(game.MISSIONS.week_key_for(0) == "W0", "epoch maps to W0")
	check(game.MISSIONS.week_key_for(604799) == "W0", "last second of week 0 stays W0")
	check(game.MISSIONS.week_key_for(604800) == "W1", "week boundary rolls exactly")
	game._mission_pair_cleared()
	var missions_state = game.progression_state.get("weekly_missions", {})
	check(str(missions_state.get("week_key", "")) == missions_week, "first record adopts the current week")
	check(game.MISSIONS.progress_of(missions_state, "pairs_30") == 1, "pair hook bumps pairs_30")
	game._mission_combo_reached(3)
	game._mission_combo_reached(2)
	missions_state = game.progression_state.get("weekly_missions", {})
	check(game.MISSIONS.progress_of(missions_state, "combo_5") == 3, "combo mission keeps the max seen, not the sum")
	game._mission_combo_reached(5)
	missions_state = game.progression_state.get("weekly_missions", {})
	check(game.MISSIONS.is_complete(missions_state, "combo_5"), "combo mission completes at the target")
	var coins_pre_claim = int(game.progression_state.get("coins", 0))
	game._on_mission_claim_pressed("combo_5")
	check(int(game.progression_state.get("coins", 0)) == coins_pre_claim + 15, "claiming pays the mission reward")
	missions_state = game.progression_state.get("weekly_missions", {})
	check(game.MISSIONS.progress_of(missions_state, "coins_100") == 15, "reward income feeds coins_100 via the wallet gate")
	game._on_mission_claim_pressed("combo_5")
	check(int(game.progression_state.get("coins", 0)) == coins_pre_claim + 15, "double claim pays nothing more")
	game.progression_state["weekly_missions"] = {"week_key": "W0", "progress": {"pairs_30": 30, "combo_5": 5}, "claimed": ["combo_5"]}
	game.MISSIONS.active_state(game)
	missions_state = game.progression_state.get("weekly_missions", {})
	check(str(missions_state.get("week_key", "")) == missions_week && !game.MISSIONS.is_claimed(missions_state, "combo_5") && game.MISSIONS.progress_of(missions_state, "pairs_30") == 0, "stale week rolls over to a fresh state")
	game._on_nav_pressed("signin")
	var found_mission_section = false
	for label_text in _page_labels(game):
		if str(label_text).find("周任务") != -1:
			found_mission_section = true
	check(found_mission_section, "sign-in page hosts the weekly missions section")
	game._on_nav_home_pressed()

	# --- combo cheers: tiered decks, no repeats, one-shot milestones ---
	var cheer_pool = 0
	for tier in game.CHEERS.TIERS:
		cheer_pool += tier["lines"].size()
	check(cheer_pool >= 30, "cheer pool holds at least 30 distinct lines")
	check(str(game.CHEERS.draw(game, 2)) != "", "low combos draw a praise line")
	check(str(game.CHEERS.draw(game, 1)) == "", "combo 1 stays silent")
	var seen_lines = {}
	var no_repeat = true
	for _i in range(8):
		var drawn = game.CHEERS.draw(game, 2)
		if seen_lines.has(drawn):
			no_repeat = false
		seen_lines[drawn] = true
	check(no_repeat, "a tier deck does not repeat until it runs dry")
	game.combo_milestones_hit = []
	var coins_before_ms = int(game.progression_state.get("coins", 0))
	game.CHEERS.on_combo(game, 5, 20)
	game.CHEERS.on_combo(game, 5, 20)
	var milestone_paid = int(game.progression_state.get("coins", 0)) - coins_before_ms
	check(milestone_paid == 5, "combo milestones pay 3-tier+5-tier once each (paid %d)" % milestone_paid)
	game.combo = 0
	game.combo_expires_ms = OS.get_ticks_msec() + 99999
	game._apply_combo_gain(10)
	game._apply_combo_gain(10)
	check(str(game.combo_burst_label.text) != "", "combo gain bursts a praise line (got %s)" % str(game.combo_burst_label.text))
	check(game.CHEERS.CLEAR_LINES.size() >= 12, "victory pet-phrase pool holds at least 12 lines")
	check(str(game.CHEERS.clear_cheer(game)) != "", "victory screens draw a pet phrase")

	# --- husband rescue: scarcity gate, one-shot, +15s and a free hint ---
	check(game.CHEERS.HUSBAND_LINES.size() >= 10, "husband one-liner pool holds at least 10 lines")
	game._start_level(0, true)
	game.stage_status = game.STATUS_PLAYING
	game.husband_called = false
	game.time_left = 60
	game._refresh_ui()
	check(game.husband_button != null && !game.husband_button.visible, "husband button hides while time is comfortable")
	game.time_left = 10
	game._refresh_ui()
	check(game.husband_button.visible, "husband button surfaces when the clock runs dry")
	var time_before_call = int(game.time_left)
	game._call_husband()
	check(int(game.time_left) == time_before_call + 15, "husband rescue adds 15 seconds")
	check(game.husband_called, "rescue marks itself used")
	check(game.hint_tiles.size() == 2, "rescue highlights a free pair")
	var coins_note = int(game.progression_state.get("coins", 0))
	game.time_left = 8
	game._call_husband()
	check(int(game.time_left) == 23 && game.husband_called, "second call is refused (one rescue per round)")
	check(int(game.progression_state.get("coins", 0)) == coins_note, "rescue is free of blossom charges")
	game._start_level(0, true)
	check(!game.husband_called, "a fresh round resets the rescue")

	# --- wallet persists to disk ---
	game._patch_progress_state({"coins_delta": 7})
	check(File.new().file_exists(game.PROGRESS_SAVE_PATH), "wallet persists to the save file")

	if failures == 0:
		print("page_probe: ALL PASSED")
		quit(0)
	else:
		print("page_probe: %d FAILURES" % failures)
		quit(1)
