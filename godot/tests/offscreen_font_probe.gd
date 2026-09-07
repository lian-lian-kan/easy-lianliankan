extends SceneTree

# Offscreen font-sharpness probe: boots the real game in a phone-canvas-sized
# window parked offscreen, then dumps the viewport texture so the text can be
# inspected at native pixel density (stretch 2d + hidpi rendering check).

func _init() -> void:
	OS.window_position = Vector2(-2600, -2600)
	OS.window_size = Vector2(780, 1688)
	var scene = load("res://scenes/Main.tscn").instance()
	root.add_child(scene)
	for _i in range(8):
		yield(self, "idle_frame")
	print("logical_viewport=", scene.get_viewport_rect().size)
	print("window_size=", OS.window_size)
	var img = root.get_texture().get_data()
	img.flip_y()
	img.save_png("/tmp/offscreen_capture.png")
	print("SAVED /tmp/offscreen_capture.png")
	quit(0)
