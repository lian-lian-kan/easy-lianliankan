extends SceneTree

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	push_error(message)
	quit(1)

func _extract_set_status_mode_block(source: String) -> String:
	var start := source.find("function setStatusMode(mode)")
	if start == -1:
		return ""
	var hidden_pos := source.find("if (mode === 'hidden')", start)
	var guard_pos := source.find("if (statusMode === mode || !initializing)", start)
	if hidden_pos == -1 or guard_pos == -1:
		return ""
	return "hidden=%d,guard=%d" % [hidden_pos - start, guard_pos - start]

func _init() -> void:
	var file := File.new()
	var path := "res://../public/godot/index.html"
	if not file.file_exists(path):
		push_error("missing file: " + path)
		quit(1)
		return
	if file.open(path, File.READ) != OK:
		push_error("failed to open: " + path)
		quit(1)
		return
	var html := file.get_as_text()
	file.close()

	var block := _extract_set_status_mode_block(html)
	_assert_true(block != "", "setStatusMode missing hidden/guard branches")

	var parts := block.split(",")
	var hidden_offset := int(parts[0].split("=")[1])
	var guard_offset := int(parts[1].split("=")[1])
	_assert_true(hidden_offset < guard_offset, "hidden branch must appear before initializing guard")

	quit(0)
