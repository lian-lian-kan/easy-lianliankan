extends SceneTree

var failures := 0

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	failures += 1
	push_error(message)
	quit(1)

func _init() -> void:
	var file := File.new()
	var path := "res://scripts/game.gd"
	if not file.file_exists(path):
		failures += 1
		push_error("missing file: " + path)
		quit(1)
		return
	if file.open(path, File.READ) != OK:
		failures += 1
		push_error("failed to open: " + path)
		quit(1)
		return
	var found := false
	for script_path in ["res://scripts/game.gd", "res://scripts/ui/home_screen.gd", "res://scripts/session/session.gd", "res://scripts/board/path_overlay.gd"]:
		if not file.file_exists(script_path):
			continue
		if file.open(script_path, File.READ) != OK:
			continue
		if file.get_as_text().find("path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE") != -1:
			found = true
		file.close()
	_assert_true(
		found,
		"path_overlay must ignore input so board touch events are not blocked"
	)
	quit(1 if failures > 0 else 0)
