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
