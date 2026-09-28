extends SceneTree

# UI 截图工具（开发用，不进 CI 清单）：真实窗口启动游戏，把首页/棋盘在
# 桌面与手机竖屏两档视口下的样子截成 PNG，供界面设计迭代自查。
#
# 用法（会弹一个真实窗口几秒钟）：
#   Godot --path godot -s res://tools/screenshot.gd
#   SKIP_SHOTS=1 同款流程但只跑逻辑不截图（无头流测用）。
# 输出：../output/ui-shots/*.png（相对仓库根）。
#
# 坑位记录：GDScript 3 里协程若在第一个 yield 前就 return，返回值是
# Null——对 Null yield("completed") 会永远挂起，调用侧必须判空。

const OUT_DIR_HINT = "../output/ui-shots"

var _logf = null

func _log(msg):
	if _logf == null:
		_logf = File.new()
		_logf.open("user://shot_progress.log", File.WRITE)
	_logf.store_line(str(OS.get_ticks_msec()) + " " + msg)
	_logf.flush()
	print(msg)

func _settle(frames):
	for _i in range(frames):
		yield(self, "idle_frame")

func _shot(game, name):
	_log("[shot] " + name)
	if OS.get_environment("SKIP_SHOTS") != "":
		return
	yield(_settle(4), "completed")
	var img = root.get_texture().get_data()
	img.flip_y()
	img.convert(Image.FORMAT_RGBA8)
	var dir = ProjectSettings.globalize_path("res://") + OUT_DIR_HINT
	Directory.new().make_dir_recursive(dir)
	var err = img.save_png(dir + "/" + name + ".png")
	_log("[shot] %s saved (%s)" % [name, "ok" if err == OK else "ERR %d" % err])

func _boot_with_title():
	var game = load("res://scenes/Main.tscn").instance()
	root.add_child(game)
	current_scene = game
	yield(_settle(10), "completed")
	return game

func _init() -> void:
	# Black-hole the API (headless runs must stay offline).
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")
	_log("== ui screenshot tool")

	if OS.get_environment("SKIP_SHOTS") == "":
		OS.window_size = Vector2(1600, 960)
		# 窗口尺寸落定后再建盘：board_fit 在关卡创建时读一次视口，竞态会把
		# 上一档窗口的棋盘形状带进新视口（竖屏拍到 8 列残留即此）。
		yield(_settle(8), "completed")
	_log("[shot] booting desktop")
	var game = yield(_boot_with_title(), "completed")
	yield(_settle(30), "completed")
	var st_title = _shot(game, "title-desktop")
	if st_title != null:
		yield(st_title, "completed")

	_log("[shot] pressing start")
	game._on_start_game_pressed()
	# 90 帧：棋盘出生动画（错峰延迟 + 淡入 ≈0.6s）播完再拍，否则瓷片
	# 停在半透明 modulate 上，整盘看着像褪色（旧基线截图即此）。
	yield(_settle(90), "completed")
	var st_board = _shot(game, "board-desktop")
	if st_board != null:
		yield(st_board, "completed")
	# 弹窗样张：暂停 / 设置 / 引导（界面轮的细节证据底座）。
	game._show_pause_panel()
	yield(_settle(6), "completed")
	var st_pause = _shot(game, "panel-pause-desktop")
	if st_pause != null:
		yield(st_pause, "completed")
	game._hide_pause_panel()
	game._on_settings_pressed()
	yield(_settle(6), "completed")
	var st_settings = _shot(game, "panel-settings-desktop")
	if st_settings != null:
		yield(st_settings, "completed")
	game._on_settings_close()
	game.progression_state[game.ONBOARDING_SEEN_KEY] = false
	game._show_onboarding_if_needed()
	yield(_settle(6), "completed")
	var st_onboarding = _shot(game, "panel-onboarding-desktop")
	if st_onboarding != null:
		yield(st_onboarding, "completed")
	game._on_onboarding_dismissed()
	game.queue_free()
	yield(_settle(2), "completed")
	_log("[shot] desktop done")

	if OS.get_environment("SKIP_SHOTS") == "":
		OS.window_size = Vector2(414, 896)
		yield(_settle(8), "completed")
	var game2 = yield(_boot_with_title(), "completed")
	yield(_settle(30), "completed")
	var st_title_p = _shot(game2, "title-portrait")
	if st_title_p != null:
		yield(st_title_p, "completed")
	game2._on_start_game_pressed()
	yield(_settle(90), "completed")
	var st_board_p = _shot(game2, "board-portrait")
	if st_board_p != null:
		yield(st_board_p, "completed")
	# 页面 chrome 样张：玩法大厅（导航浮岛 + 白卡清单）。
	game2._on_modes_pressed()
	yield(_settle(12), "completed")
	var st_modes_p = _shot(game2, "page-modes-portrait")
	if st_modes_p != null:
		yield(st_modes_p, "completed")
	# 页面巡礼：其余一级/二级页逐页截图（界面轮的证据底座）。
	for page_id in ["level_map", "collection", "signin", "shop", "events", "stats", "missions", "achievements"]:
		game2.PAGE_ROUTER.show_page(game2, page_id)
		yield(_settle(10), "completed")
		var st_page = _shot(game2, "page-%s-portrait" % page_id)
		if st_page != null:
			yield(st_page, "completed")
	game2.PAGE_ROUTER.close_page(game2)
	game2.queue_free()
	yield(_settle(2), "completed")

	_log("== done")
	quit(0)
