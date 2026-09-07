extends Reference

# 统计 HUD：卡片构建、文本设置与超时告警脉冲（从 game.gd 抽出）。
# 卡片最小尺寸恒定（数值文本放在固定 88x24 裁剪容器里），任何数值都不会
# 撑爆布局导致页面跳动（详见 progress.md 2026-09-07 布局抖动修复）。

const PASTEL_BY_KEY = {
	"total_score": Color("fff0f6"), "level_score": Color("ffe9f0"),
	"moves": Color("f3f0ff"), "remaining": Color("e7f5ff"),
	"time_left": Color("fff4e6"), "combo": Color("fff0f6"),
	"best_total_score": Color("fff9db"), "best_combo": Color("ffe9f0"),
	"race": Color("e6fcf5")
}

const CARD_MIN_SIZE = Vector2(100, 64)

static func add_card(game, parent, title, key):
	var card = PanelContainer.new()
	card.rect_min_size = CARD_MIN_SIZE
	parent.add_child(card)

	# Apply macaron pastel card style
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = PASTEL_BY_KEY.get(key, Color("ffffff"))
	card_style.set_corner_radius_all(16)
	card_style.shadow_color = Color("00000010")
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_style.set_border_width_all(1)
	card_style.border_color = Color("ffd9e8")
	card.add_stylebox_override("panel", card_style)

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGN_CENTER
	box.add_constant_override("separation", 4)
	card.add_child(box)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_font_override("font", game.game_font)
	title_label.add_color_override("font_color", Color("8f6b80"))
	title_label.align = Label.ALIGN_CENTER
	box.add_child(title_label)

	# The value lives in a fixed-size clipped holder: a Label's minimum
	# width grows with its text, and a wider card rewraps the stat flow
	# and shoves the board around on every score change.
	var value_holder = Control.new()
	value_holder.rect_min_size = Vector2(88, 24)
	value_holder.rect_clip_content = true
	box.add_child(value_holder)

	var value_label = Label.new()
	value_label.text = "--"
	value_label.add_font_override("font", game.game_font)
	value_label.add_color_override("font_color", Color("7a5064"))
	value_label.align = Label.ALIGN_CENTER
	value_label.valign = Label.VALIGN_CENTER
	value_label.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	value_holder.add_child(value_label)

	game.stat_values[key] = {
		"card": card,
		"title": title_label,
		"value": value_label
	}

# 道具槽显示：数量文本、可用性着色与暖宝宝始终的冰雪专属隐藏。
static func update_power_up(game, power_up_id, count):
	var labels = game.power_up_labels[power_up_id]
	labels["count"].text = "x" + str(count)
	# Gray out if no power-ups available
	var has_power_up = count > 0
	labels["icon"].modulate = Color(1, 1, 1, 1.0 if has_power_up else 0.4)
	labels["count"].add_color_override("font_color", Color("059669" if has_power_up else "94a3b8"))
	# 暖宝宝 is frost-only; hide its slot everywhere else to save width.
	if power_up_id == "warm_patch" and labels.has("box"):
		labels["box"].visible = game._is_frost_mode()

static func set_text(game, key, value):
	if not game.stat_values.has(key):
		return
	game.stat_values[key]["value"].text = value

# Normal (non-pulsing) look of the countdown card. Returns the applied bg.
static func set_card_state(game, is_danger):
	if not game.stat_values.has("time_left"):
		return Color("fff4e6")
	var card = game.stat_values["time_left"]["card"]
	var card_style = StyleBoxFlat.new()
	card_style.set_corner_radius_all(12)
	card_style.shadow_color = Color("00000010")
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_style.set_border_width_all(1)

	if is_danger:
		card_style.bg_color = Color("ffe3e3")
		card_style.border_color = Color("ffc9c9")
	else:
		card_style.bg_color = Color("fff4e6")
		card_style.border_color = Color("ffd9e8")

	card.add_stylebox_override("panel", card_style)
	return card_style.bg_color

# Frame pulse while the clock is in danger. Returns whether pulsing applied.
static func pulse(game, is_danger, delta):
	if not is_danger:
		return false
	if not game.stat_values.has("time_left"):
		return false

	var card = game.stat_values["time_left"]["card"]
	var tick = float(OS.get_ticks_msec()) / 1000.0
	var wave = 0.5 + 0.5 * sin(tick * 8.0)
	var intensity = 0.8 + wave * 0.2

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, intensity * 0.89, intensity * 0.89, 1.0)
	card_style.set_corner_radius_all(12)
	card_style.shadow_color = Color("00000010")
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_style.set_border_width_all(1)
	card_style.border_color = Color("ffc9c9")
	card.add_stylebox_override("panel", card_style)
	return true

# --- HUD label factories (migrated from game.gd) ---

static func _create_power_up_label(game, power_up_id, icon, shortcut):
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 2)
	game.power_ups_container.add_child(hbox)

	var icon_label = Label.new()
	icon_label.text = icon
	hbox.add_child(icon_label)

	var count_label = Label.new()
	count_label.text = "x0"
	count_label.add_color_override("font_color", Color("8f6b80"))
	# 12px keeps all 8 slots on one 390px row when frost mode adds the 🔥.
	count_label.add_font_override("font", game._font_at_size(12))
	hbox.add_child(count_label)

	var shortcut_label = Label.new()
	shortcut_label.text = "[" + shortcut + "]"
	shortcut_label.add_color_override("font_color", Color("c2a3b2"))
	# Keyboard-only affordance: pointless on touch phones, wastes width.
	shortcut_label.visible = not game._viewport_flags(game.get_viewport_rect().size)["is_mobile"]
	hbox.add_child(shortcut_label)

	game.power_up_labels[power_up_id] = {
		"icon": icon_label,
		"count": count_label,
		"shortcut": shortcut_label,
		"box": hbox
	}

static func _create_chip_label(game):
	var label = Label.new()
	label.add_font_override("font", game.game_font)
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.rect_min_size = Vector2(120, 28)
	label.add_color_override("font_color", Color("e64980"))
	# Add subtle background
	var chip_style = StyleBoxFlat.new()
	chip_style.bg_color = Color("ffe3ef")
	chip_style.set_corner_radius_all(18)
	label.add_stylebox_override("normal", chip_style)
	return label

