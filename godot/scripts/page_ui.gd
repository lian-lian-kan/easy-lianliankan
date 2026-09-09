extends Reference

# Shared page scaffolding: the common header (back button + title) and the
# scrolling content area every meta page is built from. Kept dependency-free
# so both page_router.gd and economy.gd can use it without cycles.

# Common header: back arrow + page title + optional subtitle line.
static func page_frame(game, page_content, title, subtitle):
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content.add_child(header)
	var back = Button.new()
	back.text = "‹ 返回"
	back.rect_min_size = Vector2(72, 34)
	back.add_font_override("font", game._font_at_size(13))
	game._apply_button_style(back, Color("f06ba8"), Color("d6336c"))
	back.add_color_override("font_color", Color("ffffff"))
	back.connect("pressed", game, "_on_nav_home_pressed")
	header.add_child(back)
	var title_label = Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.align = Label.ALIGN_CENTER
	title_label.add_font_override("font", game._font_at_size(18))
	title_label.add_color_override("font_color", Color("d6336c"))
	header.add_child(title_label)
	if subtitle != "":
		var subtitle_label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.align = Label.ALIGN_CENTER
		subtitle_label.add_font_override("font", game._font_at_size(12))
		subtitle_label.add_color_override("font_color", Color("8f6b80"))
		page_content.add_child(subtitle_label)

static func scroll_area(game, page_content):
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_horizontal_enabled = false
	page_content.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_constant_override("separation", 10)
	scroll.add_child(box)
	return box

static func clear_page(game, page_content):
	for child in page_content.get_children():
		page_content.remove_child(child)
		child.queue_free()
