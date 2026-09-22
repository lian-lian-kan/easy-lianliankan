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
	_log("[shot] booting desktop")
	var game = yield(_boot_with_title(), "completed")
	yield(_settle(30), "completed")
	var st_title = _shot(game, "title-desktop")
	if st_title != null:
		yield(st_title, "completed")

	_log("[shot] pressing start")
	game._on_start_game_pressed()
	yield(_settle(30), "completed")
	var st_board = _shot(game, "board-desktop")
	if st_board != null:
		yield(st_board, "completed")
	game.queue_free()
	yield(_settle(2), "completed")
	_log("[shot] desktop done")

	if OS.get_environment("SKIP_SHOTS") == "":
		OS.window_size = Vector2(414, 896)
	var game2 = yield(_boot_with_title(), "completed")
	yield(_settle(30), "completed")
	var st_title_p = _shot(game2, "title-portrait")
	if st_title_p != null:
		yield(st_title_p, "completed")
	game2._on_start_game_pressed()
	yield(_settle(30), "completed")
	var st_board_p = _shot(game2, "board-portrait")
	if st_board_p != null:
		yield(st_board_p, "completed")
	game2.queue_free()
	yield(_settle(2), "completed")

	_log("== done")
	quit(0)
