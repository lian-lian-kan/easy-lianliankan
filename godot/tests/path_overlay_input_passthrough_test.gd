extends SceneTree

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	push_error(message)
	quit(1)

func _init() -> void:
	var file := File.new()
	var path := "res://scripts/game.gd"
	if not file.file_exists(path):
		push_error("missing file: " + path)
		quit(1)
		return
	if file.open(path, File.READ) != OK:
		push_error("failed to open: " + path)
		quit(1)
		return
	var source := file.get_as_text()
	file.close()

	_assert_true(
		source.find("path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE") != -1,
		"path_overlay must ignore input so board touch events are not blocked"
	)
	quit(0)
