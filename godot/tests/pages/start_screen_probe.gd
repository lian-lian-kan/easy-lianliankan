extends SceneTree

# 首页探针：启动标题页三条路径——
# A) 探针环境（current_scene 为空）：老行为直达棋盘，首页不弹（既有探针
#    零改动的契约）；
# B) 真实启动（Main::start 会把 current_scene 指向主场景，这里等价模拟）：
#    首页自动展开并暂停时钟，开始游戏落回棋盘、键盘不穿底、快捷入口进
#    页面、关页回棋盘、暂停面板回首页再落回；
# C) start_screen_suppressed 显式压制：同 A。

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _settle(frames):
	for _i in range(frames):
		yield(self, "idle_frame")

func _init() -> void:
	# Black-hole the API (headless runs must stay offline): a live cloud
	# save adopting mid-probe would replace the board under assertion.
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")
	print("== start_screen_probe")

	# --- A: probe boot keeps the legacy board-first path ---
	var game_a = load("res://scenes/Main.tscn").instance()
	root.add_child(game_a)
	yield(_settle(8), "completed")
	check(not game_a.start_screen_open, "A: probe boot (no current_scene) keeps the title closed")
	check(game_a.start_screen_root == null, "A: no title surface built in probe boot")
	check(game_a.stage_status == game_a.STATUS_PLAYING, "A: probe boot lands PLAYING (legacy)")
	check(game_a.board.size() > 0, "A: board still boots under legacy path")
	game_a.queue_free()
	yield(_settle(2), "completed")

	# --- B: real-boot title flow ---
	# current_scene 必须在入树后赋值（setter 拒绝树外节点）；启动门是
	# call_deferred，下一帧才读，此刻赋好即可等价模拟 Main::start。
	var game_b = load("res://scenes/Main.tscn").instance()
	root.add_child(game_b)
	current_scene = game_b
	yield(_settle(8), "completed")
	check(game_b.start_screen_open, "B: real boot auto-opens the title")
	check(game_b.start_screen_root != null and game_b.start_screen_root.visible, "B: title surface visible")
	check(game_b.stage_status == game_b.STATUS_PAUSED, "B: title pauses the stage")
	check(game_b.second_timer != null and game_b.second_timer.is_stopped(), "B: clock stopped under the title")
	game_b.progression_state[game_b.ONBOARDING_SEEN_KEY] = true
	game_b._on_start_game_pressed()
	check(not game_b.start_screen_open, "B: start button closes the title")
	check(game_b.stage_status == game_b.STATUS_PLAYING, "B: start button resumes PLAYING")
	check(game_b.start_screen_root != null and not game_b.start_screen_root.visible, "B: title surface hidden after start")
	check(game_b.onboarding_panel == null or not game_b.onboarding_panel.visible, "B: seen onboarding stays closed")

	# 回首页 + 键盘不穿底
	game_b._show_start_screen()
	check(game_b.start_screen_open and game_b.stage_status == game_b.STATUS_PAUSED, "B: re-open pauses again")
	var key_p = InputEventKey.new()
	key_p.pressed = true
	key_p.scancode = KEY_P
	game_b.GAME_INPUT._unhandled_input(game_b, key_p)
	check(game_b.pause_panel == null or not game_b.pause_panel.visible, "B: keyboard P does not pierce the title")

	# 快捷入口 → 页面 → 关页回棋盘
	game_b._on_start_open_page("modes")
	check(game_b.pages_root.visible and not game_b.start_screen_open, "B: quick entry opens modes page and closes the title")
	check(game_b.stage_status == game_b.STATUS_PAUSED, "B: page keeps the clock paused")
	game_b._on_nav_home_pressed()
	check(not game_b.pages_root.visible and game_b.stage_status == game_b.STATUS_PLAYING, "B: closing the page lands on the board PLAYING")

	# 暂停面板回首页再落回
	game_b._on_pause_home_pressed()
	check(game_b.start_screen_open and game_b.stage_status == game_b.STATUS_PAUSED, "B: pause-panel home re-opens the title paused")
	game_b._on_start_game_pressed()
	check(game_b.stage_status == game_b.STATUS_PLAYING, "B: start button lands back on the board")
	game_b.queue_free()
	yield(_settle(2), "completed")

	# --- C: explicit suppression flag ---
	var game_c = load("res://scenes/Main.tscn").instance()
	game_c.set("start_screen_suppressed", true)
	root.add_child(game_c)
	current_scene = game_c
	yield(_settle(8), "completed")
	check(not game_c.start_screen_open and game_c.stage_status == game_c.STATUS_PLAYING, "C: suppressed flag keeps legacy boot even as main scene")
	game_c.queue_free()
	yield(_settle(2), "completed")

	# --- D: 首页红点状态（Round 36）——三个只读判据的真假两侧 ---
	var game_d = load("res://scenes/Main.tscn").instance()
	root.add_child(game_d)
	yield(_settle(8), "completed")
	var start_screen = load("res://scripts/pages/start_screen.gd")
	# 签到：没签 → 亮点；签了 → 熄灭。
	game_d.progression_state["last_signin"] = ""
	check(start_screen._has_unsigned_signin(game_d), "D: empty last_signin lights the signin dot")
	game_d.progression_state["last_signin"] = game_d.SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	check(not start_screen._has_unsigned_signin(game_d), "D: signing today clears the signin dot")
	# 周任务：本周桶里有完成未领 → 亮点；跨周桶（未滚动）与新周空白 → 熄灭。
	var week_state = {
		"week_key": game_d.MISSIONS.current_week_key(game_d),
		"progress": {game_d.MISSIONS.MISSIONS.keys()[0]: int(game_d.MISSIONS.MISSIONS[game_d.MISSIONS.MISSIONS.keys()[0]]["target"])},
		"claimed": [],
	}
	game_d.progression_state["weekly_missions"] = week_state
	check(start_screen._has_claimable_mission(game_d), "D: done-but-unclaimed weekly task lights the missions dot")
	week_state["claimed"] = [game_d.MISSIONS.MISSIONS.keys()[0]]
	check(not start_screen._has_claimable_mission(game_d), "D: claiming the task clears the missions dot")
	game_d.progression_state["weekly_missions"] = {"week_key": "W0", "progress": {}, "claimed": []}
	check(not start_screen._has_claimable_mission(game_d), "D: stale week bucket stays dark (no write during title build)")
	# 大树里程碑：够高未领 → 亮点；领过 → 熄灭。
	game_d.progression_state["tree_best_height"] = 8
	game_d.progression_state["tree_milestones"] = []
	check(start_screen._has_unclaimed_milestone(game_d), "D: reached milestone lights the stats dot")
	game_d.progression_state["tree_milestones"] = [8]
	check(not start_screen._has_unclaimed_milestone(game_d), "D: claimed milestone clears the stats dot")
	game_d.queue_free()

	if failures == 0:
		print("start_screen_probe: ALL PASSED")
		quit(0)
	else:
		print("start_screen_probe: %d FAILURES" % failures)
		quit(1)
