extends Reference

# Shared page scaffolding: the common header (back button + title) and the
# scrolling content area every meta page is built from. Kept dependency-free
# so both page_router.gd and economy.gd can use it without cycles.

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const UI_PAINT = preload("res://scripts/ui/ui_paint.gd")

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
	# 页面内容列（Round 39 宽屏适配）：宽屏收进 PAGE_COLUMN_MAX_WIDTH 并
	# 居中，窄屏自适应全宽——没有它，有礼/活动/小铺的内容顶着左上角、
	# 右侧一大片空粉，数据/任务的行被拉到 1280 宽像散架的表格。
	# side 边距存到 game.page_column_outer，窗口缩放时 hud_layout 重算。
	var outer = MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)
	# 内容宽度：优先用 page_content 自身已布局的宽度（探针假体没有
	# get_viewport_rect，宽度拿不到时留白为 0，只断言子节点不受影响）。
	var view_w = 0.0
	if page_content.rect_size.x > 1.0:
		view_w = page_content.rect_size.x - 28.0
	elif game.has_method("get_viewport_rect"):
		view_w = game.get_viewport_rect().size.x - 28.0
	view_w = max(0.0, view_w)
	var side = _column_side(view_w)
	outer.add_constant_override("margin_left", side)
	outer.add_constant_override("margin_right", side)
	# set() 而非直接赋值：探针的 FakeGame 是裸 Node，直接 set 成员会炸，
	# set() 对无此属性的假体是静默空操作。
	game.set("page_column_outer", outer)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_constant_override("separation", 10)
	outer.add_child(box)
	return box

# 内容列的左右留白：内容区宽度超过 PAGE_COLUMN_MAX_WIDTH 时居中，否则 0。
static func _column_side(view_w):
	return max(0.0, (view_w - min(UI_STYLE.PAGE_COLUMN_MAX_WIDTH, view_w)) * 0.5)

# 网格列数：按内容列宽估算（每列目标 ~150px），宽屏 4-5 列、窄屏回落
# min_columns。小铺这类定宽卡片网格在内容列里不再缩成两小条。
static func grid_columns(page_content, min_columns = 2, cell_target = 150.0):
	var w = page_content.rect_size.x
	if w <= 1.0:
		w = UI_STYLE.PAGE_COLUMN_MAX_WIDTH
	var usable = min(w, UI_STYLE.PAGE_COLUMN_MAX_WIDTH) - 28.0
	return clamp(int(usable / cell_target), min_columns, 6)

# 区块标题：玫瑰短棒 + 标题行（可选右侧进度尾巴）。旅程章节/玩法分类/
# 氛围主题等所有页面分区的统一开头——以前是几处裸 Label，各写各的。
static func section_header(game, text, tail_text = ""):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_constant_override("separation", 8)
	row.add_child(UI_PAINT.accent_bar())
	var label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_font_override("font", game._font_at_size(15))
	label.add_color_override("font_color", Color("9c6b7f"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	if tail_text != "":
		var tail = Label.new()
		tail.text = tail_text
		tail.add_font_override("font", game._font_at_size(12))
		tail.add_color_override("font_color", Color("d6336c"))
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tail)
	return row

static func clear_page(game, page_content):
	for child in page_content.get_children():
		page_content.remove_child(child)
		child.queue_free()
