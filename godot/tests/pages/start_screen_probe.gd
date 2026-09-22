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

	if failures == 0:
		print("start_screen_probe: ALL PASSED")
		quit(0)
	else:
		print("start_screen_probe: %d FAILURES" % failures)
		quit(1)
