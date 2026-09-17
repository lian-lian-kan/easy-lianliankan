extends Reference

# 关卡工坊 UI：编辑器面板、调色板/网格重绘与分享码导入导出。Pure grid math
# lives in ../modes/level_editor.gd; the modal shell helpers come from
# ui_panels.gd.

const UI_PANELS = preload("res://scripts/ui/ui_panels.gd")
const LEVEL_EDITOR = preload("res://scripts/modes/level_editor.gd")

const EDITOR_DIM_VALUES = [4, 6, 8, 10]
const EDITOR_KIND_VALUES = [2, 3, 4, 5, 6, 8, 10, 12]

static func _editor_panel(game):
	if game.editor_panel != null:
		return
	game.editor_state = LEVEL_EDITOR.default_state()
	game.editor_panel = PanelContainer.new()
	var content = UI_PANELS._modal_content_shell(game, game.editor_panel, Vector2(380, 0), 8)

	var title = Label.new()
	title.text = "🎨 关卡工坊"
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", game.game_font)
	title.add_color_override("font_color", Color("5c3a4d"))
	content.add_child(title)

	_editor_body(game, content)

static func _editor_body(game, content):
	var hint = Label.new()
	hint.text = "选图案点格子涂牌，再点一次擦除。关卡要成对且有解才能试玩/分享。"
	hint.autowrap = true
	hint.add_font_override("font", game._font_at_size(12))
	hint.add_color_override("font_color", Color("8f6b80"))
	content.add_child(hint)

	game.editor_dims_row = HBoxContainer.new()
	game.editor_dims_row.add_constant_override("separation", 8)
	content.add_child(game.editor_dims_row)
	_editor_build_dim_options(game)

	game.editor_palette = HBoxContainer.new()
	game.editor_palette.add_constant_override("separation", 6)
	content.add_child(game.editor_palette)

	game.editor_grid = GridContainer.new()
	game.editor_grid.add_constant_override("h_separation", 4)
	game.editor_grid.add_constant_override("v_separation", 4)
	game.editor_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(game.editor_grid)

	game.editor_validation = Label.new()
	game.editor_validation.autowrap = true
	game.editor_validation.add_font_override("font", game._font_at_size(12))
	content.add_child(game.editor_validation)

	_editor_actions(game, content)

static func _editor_build_dim_options(game):
	for child in game.editor_dims_row.get_children():
		game.editor_dims_row.remove_child(child)
		child.queue_free()
	for spec in [
		{"label": "行", "key": "rows", "values": EDITOR_DIM_VALUES, "handler": "_on_editor_rows_changed"},
		{"label": "列", "key": "cols", "values": EDITOR_DIM_VALUES, "handler": "_on_editor_cols_changed"},
		{"label": "图案", "key": "kinds", "values": EDITOR_KIND_VALUES, "handler": "_on_editor_kinds_changed"},
	]:
		var label = Label.new()
		label.text = str(spec["label"])
		label.add_font_override("font", game._font_at_size(13))
		game.editor_dims_row.add_child(label)
		var option = OptionButton.new()
		for value in spec["values"]:
			option.add_item(str(value))
		option.select(spec["values"].find(int(game.editor_state[spec["key"]])))
		option.add_font_override("font", game._font_at_size(13))
		option.connect("item_selected", game, spec["handler"])
		game.editor_dims_row.add_child(option)

static func _editor_action_button(game, text, handler):
	var button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.rect_min_size = Vector2(0, 38)
	button.add_font_override("font", game.game_font)
	button.connect("pressed", game, handler)
	return button

# Full repaint of palette + grid + validation from editor_state.
static func refresh_editor(game):
	if game.editor_panel == null or game.editor_state == null:
		return
	var state: Dictionary = game.editor_state
	for child in game.editor_palette.get_children():
		game.editor_palette.remove_child(child)
		child.queue_free()
	var eraser = Button.new()
	eraser.text = "🧽"
	eraser.rect_min_size = Vector2(38, 38)
	eraser.add_font_override("font", game.game_font)
	eraser.connect("pressed", game, "_on_editor_kind_pressed", [0])
	if int(state["active_kind"]) == 0:
		eraser.disabled = true
	game.editor_palette.add_child(eraser)
	var icons: Array = game.icon_sets[game.icon_set_index].get("icons", [])
	for kind in range(1, int(state["kinds"]) + 1):
		var kind_button = Button.new()
		kind_button.text = game._icon_for(kind)
		kind_button.rect_min_size = Vector2(38, 38)
		kind_button.add_font_override("font", game.game_font)
		kind_button.connect("pressed", game, "_on_editor_kind_pressed", [kind])
		if int(state["active_kind"]) == kind:
			kind_button.disabled = true
		game.editor_palette.add_child(kind_button)

	game.editor_grid.columns = int(state["cols"])
	for child in game.editor_grid.get_children():
		game.editor_grid.remove_child(child)
		child.queue_free()
	for r in range(int(state["rows"])):
		for c in range(int(state["cols"])):
			var value = int(state["grid"][r][c])
			var cell = Button.new()
			cell.text = game._icon_for(value) if value > 0 else "·"
			cell.rect_min_size = Vector2(34, 34)
			cell.add_font_override("font", game._font_at_size(16))
			cell.connect("pressed", game, "_on_editor_cell_pressed", [r, c])
			game.editor_grid.add_child(cell)

	var verdict = LEVEL_EDITOR.validate_layout(state["grid"], int(state["kinds"]))
	if verdict["ok"]:
		game.editor_validation.text = "✅ 关卡可玩，可以试玩或分享"
		game.editor_validation.add_color_override("font_color", Color("2f9e44"))
	else:
		game.editor_validation.text = "⚠️ " + str(verdict["reason"])
		game.editor_validation.add_color_override("font_color", Color("e03131"))

# Resize preserves the overlapping region; kinds shrink clears out-of-range cells.
static func editor_resize(game, rows, cols, kinds):
	var old: Dictionary = game.editor_state
	var new_grid = LEVEL_EDITOR.blank_grid(rows, cols)
	for r in range(min(int(old["rows"]), rows)):
		for c in range(min(int(old["cols"]), cols)):
			var v = int(old["grid"][r][c])
			new_grid[r][c] = v if v <= kinds else 0
	game.editor_state["rows"] = rows
	game.editor_state["cols"] = cols
	game.editor_state["kinds"] = kinds
	game.editor_state["grid"] = new_grid
	game.editor_state["active_kind"] = min(int(old["active_kind"]), kinds)
	refresh_editor(game)



static func _editor_actions(game, content):
	var actions = HBoxContainer.new()
	actions.add_constant_override("separation", 8)
	content.add_child(actions)
	actions.add_child(_editor_action_button(game, "🎲 随机", "_on_editor_random_pressed"))
	actions.add_child(_editor_action_button(game, "🎮 试玩", "_on_editor_play_pressed"))
	actions.add_child(_editor_action_button(game, "📤 分享码", "_on_editor_share_pressed"))

	game.editor_share_label = Label.new()
	game.editor_share_label.autowrap = true
	game.editor_share_label.add_font_override("font", game._font_at_size(12))
	game.editor_share_label.add_color_override("font_color", Color("7048e8"))
	content.add_child(game.editor_share_label)

	var import_row = HBoxContainer.new()
	import_row.add_constant_override("separation", 8)
	game.editor_import_input = LineEdit.new()
	game.editor_import_input.placeholder_text = "粘贴好友的 LK1 分享码"
	game.editor_import_input.max_length = 160
	game.editor_import_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.editor_import_input.add_font_override("font", game._font_at_size(12))
	import_row.add_child(game.editor_import_input)
	import_row.add_child(_editor_action_button(game, "📥 导入", "_on_editor_import_pressed"))
	content.add_child(import_row)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.rect_min_size = Vector2(0, 40)
	close_button.add_font_override("font", game.game_font)
	close_button.connect("pressed", game, "_on_editor_close")
	content.add_child(close_button)
	game._style_dialog_buttons(game.editor_panel)
