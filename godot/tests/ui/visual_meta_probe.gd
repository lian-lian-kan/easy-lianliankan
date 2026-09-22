extends SceneTree
func _init() -> void:
	OS.window_position = Vector2(-4000, -4000)
	OS.window_size = Vector2(780, 1688)
	var scene = load("res://scenes/Main.tscn").instance()
	root.add_child(scene)
	for _i in range(8):
		yield(self, "idle_frame")
	# journey page
	scene._on_nav_pressed("level_map")
	for _i in range(3):
		yield(self, "idle_frame")
	var img = root.get_texture().get_data(); img.flip_y()
	img.save_png("/tmp/meta_journey.png")
	# collection page
	scene._on_nav_pressed("collection")
	for _i in range(3):
		yield(self, "idle_frame")
	img = root.get_texture().get_data(); img.flip_y()
	img.save_png("/tmp/meta_collection.png")
	# sign-in page
	scene._on_nav_pressed("signin")
	for _i in range(3):
		yield(self, "idle_frame")
	img = root.get_texture().get_data(); img.flip_y()
	img.save_png("/tmp/meta_signin.png")
	# shop page
	scene._on_nav_pressed("shop")
	for _i in range(3):
		yield(self, "idle_frame")
	img = root.get_texture().get_data(); img.flip_y()
	img.save_png("/tmp/meta_shop.png")
	print("SAVED 4 pages")
	quit(0)
