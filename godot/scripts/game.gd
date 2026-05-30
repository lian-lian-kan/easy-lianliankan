extends Control

const CAMPAIGN_PATH = "res://data/campaign.json"
const TUNING_PATH = "res://data/tuning.json"
const ICON_SETS_PATH = "res://data/icon_sets.json"
const PROGRESS_SAVE_PATH = "user://campaign_progress.json"

const STATUS_PLAYING = "playing"
const STATUS_PAUSED = "paused"
const STATUS_CLEARED = "cleared"
const STATUS_FAILED = "failed"
const STATUS_COMPLETED = "completed"

const DIRS = [
	Vector2(-1, 0),
	Vector2(1, 0),
	Vector2(0, -1),
	Vector2(0, 1)
]

const PATH_COLOR_HINT = Color("0ea5e9")
const PATH_COLOR_ELIMINATE = Color("ff7a00")
const PATH_OVERLAY_SCRIPT = preload("res://scripts/path_overlay.gd")
const PROGRESSION_SCRIPT = preload("res://scripts/progression.gd")
const MOBILE_SHORT_SIDE_MAX = 768.0
const MOBILE_COMPACT_HEIGHT_MAX = 460.0
const BOARD_RATIO_MOBILE_PORTRAIT = 0.60
const BOARD_RATIO_MOBILE_LANDSCAPE = 0.46
const BOARD_RATIO_DESKTOP = 0.52
const BOARD_MIN_HEIGHT = 200.0

var campaign_levels = []
var tuning = {}
var icon_sets = []
var icon_set_index = 0

var board = []
var cell_buttons = []

var selected = Vector2(-1, -1)
var hint_tiles = []
var error_tiles = []

var level_index = 0
var pending_level_index = -1

var total_score = 0
var level_score = 0
var moves = 0
var combo = 0
var combo_expires_ms = 0

var time_left = 0
var stage_status = STATUS_PLAYING
var progression_state = {}

# Achievement tracking
var level_start_time = 0
var level_hints_used = 0
var level_auto_used = 0

# Power-ups system
var power_ups: Dictionary = {"time_freeze": 0, "auto_match": 0, "reshuffle": 0}
var time_frozen = false
var time_freeze_timer

var title_label
var subtitle_label
var desc_label
var status_chip_label
var message_label
var stage_panel_label
var combo_burst_label
var level_progress_bar
var combo_progress_bar
var mode_chip_label
var kinds_chip_label

var board_wrapper
var board_center
var board_grid
var path_overlay
var effect_layer

var margin_container

var icon_set_option
var level_select_option
var hint_button
var auto_button
var shuffle_button
var reset_button
var pause_button
var jump_level_button
var clear_progress_button
var settings_button  # 设置按钮

var stat_values = {}
var stats_flow_container
var controls_flow_container
var progression_flow_container
var power_ups_container  # 道具显示容器
var power_up_labels = {}

var second_timer
var message_timer
var error_timer
var combo_reset_timer
var level_advance_timer

var game_font

var level_highlight_timer
const LEVEL_HIGHLIGHT_COLOR = Color("fbbf24")  # 琥珀色高亮
const LEVEL_NORMAL_COLOR = Color("ffffff")  # 正常白色

var onboarding_panel  # 首次启动引导面板
const ONBOARDING_SEEN_KEY = "onboarding_seen"

var settings_panel  # 设置面板
var achievements_panel  # 成就面板
var pause_panel  # 暂停面板

func _ready():
	print("[Game] _ready() started")
	randomize()
	print("[Game] randomize() done")
	_init_font()
	print("[Game] _init_font() done")
	_load_config()
	print("[Game] _load_config() done, levels: ", campaign_levels.size())
	_load_progress_state()
	print("[Game] _load_progress_state() done")
	_build_ui()
	print("[Game] _build_ui() done")
	_build_timers()
	print("[Game] _build_timers() done")
	var start_level_index = int(progression_state.get("current_level_index", 0))
	print("[Game] Starting level: ", start_level_index)
	_start_level(start_level_index, true)
	print("[Game] _start_level() done")
	set_process(true)
	call_deferred("_show_onboarding_if_needed")
	call_deferred("_start_bgm")
	print("[Game] _ready() completed")

func _process(delta):
	_update_combo_progress()
	_update_time_warning_pulse(delta)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_P:
				_on_pause_pressed()
				accept_event()
			KEY_H:
				if stage_status == STATUS_PLAYING:
					_on_hint_pressed()
					accept_event()
			KEY_A:
				if stage_status == STATUS_PLAYING:
					_on_auto_pressed()
					accept_event()
			KEY_S:
				if stage_status == STATUS_PLAYING:
					_on_shuffle_pressed()
					accept_event()
			KEY_R:
				_on_reset_pressed()
				accept_event()
			KEY_BRACKETLEFT:
				_cycle_level_selection(-1)
				accept_event()
			KEY_BRACKETRIGHT:
				_cycle_level_selection(1)
				accept_event()
			KEY_ENTER, KEY_KP_ENTER:
				_on_jump_level_pressed()
				accept_event()
			KEY_F:
				_toggle_fullscreen_mode()
				accept_event()
			KEY_1:
				_use_power_up("time_freeze")
				accept_event()
			KEY_2:
				_use_power_up("auto_match")
				accept_event()
			KEY_3:
				_use_power_up("reshuffle")
				accept_event()
			KEY_ESCAPE:
				if OS.window_fullscreen:
					OS.window_fullscreen = false
					_show_message("已退出全屏", 0.8)
					accept_event()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_layout_for_screen_size()
		_update_tile_sizes()
		_refresh_board_visuals()

func _viewport_flags(viewport_size):
	var short_side = min(viewport_size.x, viewport_size.y)
	var is_mobile = short_side <= MOBILE_SHORT_SIDE_MAX
	var is_portrait = viewport_size.y >= viewport_size.x
	var is_compact_height = viewport_size.y <= MOBILE_COMPACT_HEIGHT_MAX
	return {
		"is_mobile": is_mobile,
		"is_portrait": is_portrait,
		"is_compact_height": is_compact_height
	}

func _update_modal_panel_sizes(viewport_size, is_portrait):
	var max_width = viewport_size.x * 0.92
	var max_height = viewport_size.y * (0.90 if is_portrait else 0.82)

	if onboarding_panel:
		onboarding_panel.custom_minimum_size = Vector2(min(320.0, max_width), min(400.0, max_height))
	if settings_panel:
		settings_panel.custom_minimum_size = Vector2(min(360.0, max_width), min(320.0, max_height))
	if achievements_panel:
		achievements_panel.custom_minimum_size = Vector2(min(400.0, max_width), min(480.0, max_height))
	if pause_panel:
		pause_panel.custom_minimum_size = Vector2(min(320.0, max_width), min(280.0, max_height))

func _update_layout_for_screen_size():
	if board_wrapper == null or board_grid == null:
		return

	# Get viewport size for responsive layout
	var viewport_size = get_viewport_rect().size
	var flags = _viewport_flags(viewport_size)
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]

	# Give board more vertical room on mobile and wide desktop.
	if is_mobile:
		var mobile_ratio = BOARD_RATIO_MOBILE_PORTRAIT if is_portrait else BOARD_RATIO_MOBILE_LANDSCAPE
		board_wrapper.custom_minimum_size = Vector2(0, max(BOARD_MIN_HEIGHT, viewport_size.y * mobile_ratio))
	else:
		board_wrapper.custom_minimum_size = Vector2(0, max(420.0, viewport_size.y * BOARD_RATIO_DESKTOP))

	# Adjust margins based on screen size
	var margin_value = 6 if is_compact_height else (8 if is_mobile else 16)
	if margin_container:
		margin_container.add_constant_override("margin_left", margin_value)
		margin_container.add_constant_override("margin_right", margin_value)
		margin_container.add_constant_override("margin_top", margin_value)
		margin_container.add_constant_override("margin_bottom", margin_value)

	# Adjust header font sizes
	if title_label:
		pass
	if subtitle_label:
		pass
	if desc_label:
		desc_label.visible = not is_mobile

	# Adjust tile separation based on screen size
	if is_mobile and is_compact_height:
		board_grid.add_constant_override("h_separation", 4)
		board_grid.add_constant_override("v_separation", 4)
	elif is_mobile:
		board_grid.add_constant_override("h_separation", 6)
		board_grid.add_constant_override("v_separation", 6)
	else:
		board_grid.add_constant_override("h_separation", 10)
		board_grid.add_constant_override("v_separation", 10)

	if stats_flow_container:
		stats_flow_container.add_constant_override("h_separation", 4 if is_mobile else 6)
		stats_flow_container.add_constant_override("v_separation", 6 if is_mobile else 6)

	var stat_card_size = Vector2(76, 54) if is_mobile and is_portrait else (Vector2(82, 54) if is_mobile else Vector2(100, 64))
	var stat_value_size = 18 if is_mobile and is_portrait else (20 if is_mobile else 22)
	var stat_title_size = 10 if is_mobile else 11
	for key in stat_values.keys():
		var card = stat_values[key]["card"]
		var title_small = stat_values[key]["title"]
		var value_label = stat_values[key]["value"]
		card.custom_minimum_size = stat_card_size
		title_small.custom_minimum_size = Vector2(0, stat_title_size + 4)
		value_label.custom_minimum_size = Vector2(0, stat_value_size + 6)

	var control_min = Vector2(72, 34) if is_mobile and is_compact_height else (Vector2(76, 36) if is_mobile and is_portrait else (Vector2(80, 36) if is_mobile else Vector2(88, 42)))
	if icon_set_option:
		icon_set_option.custom_minimum_size = Vector2(108 if is_mobile else 122, control_min.y)
	if level_select_option:
		level_select_option.custom_minimum_size = Vector2(130 if is_mobile else 172, control_min.y)
	for button in [hint_button, auto_button, shuffle_button, pause_button, reset_button, jump_level_button, clear_progress_button]:
		if button:
			button.custom_minimum_size = control_min

	if controls_flow_container:
		controls_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		controls_flow_container.add_constant_override("v_separation", 6 if is_mobile else 8)
	if progression_flow_container:
		progression_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		progression_flow_container.add_constant_override("v_separation", 6 if is_mobile else 8)

	_update_modal_panel_sizes(viewport_size, is_portrait)

const EMBEDDED_FONT = preload("res://fonts/NotoSansSC-Regular.ttf")
const EMOJI_FONT = preload("res://fonts/NotoColorEmoji.ttf")

func _init_font():
	# For Web exports, use embedded font files for Chinese and Emoji support
	if EMBEDDED_FONT:
		game_font = EMBEDDED_FONT
		# Add emoji font as fallback
		if EMOJI_FONT:
			var fallbacks = [EMOJI_FONT]
			game_font.fallbacks = fallbacks
	else:
		# Fallback to embedded font if available
		game_font = EMBEDDED_FONT if EMBEDDED_FONT else null

	# Apply font via theme
	var theme = Theme.new()
	theme.set_font("font", "Label", game_font)
	theme.set_font("font", "Button", game_font)
	theme.set_font("font", "OptionButton", game_font)
	self.theme = theme

func _load_config():
	campaign_levels = _load_campaign_levels()
	tuning = _load_tuning()
	icon_sets = _load_icon_sets()

	if campaign_levels.is_empty():
		campaign_levels = _default_campaign_levels()
	if icon_sets.is_empty():
		icon_sets = _default_icon_sets()

func _load_json_file(path: String):
	var file = File.new()
	if not file.file_exists(path):
		return null
	var err = file.open(path, File.READ)
	if err != OK:
		return null
	var content = file.get_as_text()
	file.close()
	if content.strip_edges() == "":
		return null
	var parsed = parse_json(content)
	return parsed

func _load_campaign_levels():
	var root = _load_json_file(CAMPAIGN_PATH)
	if typeof(root) != TYPE_DICTIONARY:
		return []
	var levels: Array = root.get("levels", [])
	return levels

func _load_tuning():
	var root = _load_json_file(TUNING_PATH)
	if typeof(root) != TYPE_DICTIONARY:
		return _default_tuning()
	var defaults = _default_tuning()
	for key in defaults.keys():
		if not root.has(key):
			root[key] = defaults[key]
	return root

func _load_icon_sets():
	var root = _load_json_file(ICON_SETS_PATH)
	if typeof(root) != TYPE_DICTIONARY:
		return []
	return root.get("sets", [])

func _load_progress_state():
	var raw = null
	var file = File.new()
	if file.file_exists(PROGRESS_SAVE_PATH):
		var err = file.open(PROGRESS_SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			if content.strip_edges() != "":
				raw = parse_json(content)
			file.close()
	progression_state = PROGRESSION_SCRIPT.normalize_progress(raw, campaign_levels.size())

func _save_progress_state():
	var normalized = PROGRESSION_SCRIPT.normalize_progress(progression_state, campaign_levels.size())
	var file = File.new()
	var err = file.open(PROGRESS_SAVE_PATH, File.WRITE)
	if err != OK:
		return
	file.store_string(to_json(normalized))
	file.close()
	progression_state = normalized

func _patch_progress_state(patch):
	var prev_current = int(progression_state.get("current_level_index", 0))
	var prev_unlocked = int(progression_state.get("highest_unlocked_level_index", 0))
	var next_state = PROGRESSION_SCRIPT.apply_update(progression_state, campaign_levels.size(), patch)
	if PROGRESSION_SCRIPT.same_progress(next_state, progression_state, campaign_levels.size()):
		progression_state = next_state
		return
	var next_current = int(next_state.get("current_level_index", prev_current))
	var next_unlocked = int(next_state.get("highest_unlocked_level_index", prev_unlocked))
	progression_state = next_state
	_save_progress_state()
	if (next_current != prev_current or next_unlocked != prev_unlocked) and level_select_option != null:
		_populate_level_select_options()

func _progress_best_score():
	return int(progression_state.get("best_total_score", 0))

func _progress_best_combo():
	return int(progression_state.get("best_combo", 0))

func _default_tuning():
	return {
		"base_score": 10,
		"message_timeout_ms": 1000,
		"path_preview_ms": 420,
		"hint_preview_ms": 1400,
		"error_flash_ms": 420,
		"combo_window_ms": 2600,
		"max_combo": 8,
		"combo_burst_ms": 820,
		"level_advance_ms": 1200,
		"time_danger_seconds": 10,
		"hint_time_cost_seconds": 1,
		"auto_eliminate_time_cost_seconds": 2,
		"shuffle_time_cost_seconds": 1
	}


func _default_campaign_levels():
	return [
		{
			"id": 1,
			"name": "热身",
			"mode": "classic",
			"description": "熟悉手感，建立节奏",
			"rows": 8,
			"cols": 6,
			"kinds": 6,
			"time_limit": 90,
			"time_bonus_multiplier": 2.0,
			"score_multiplier": 1.0,
			"effect_intensity": 1.0
		},
		{
			"id": 2,
			"name": "提速",
			"mode": "rush",
			"description": "速度优先，倒计时更紧",
			"rows": 10,
			"cols": 6,
			"kinds": 7,
			"time_limit": 100,
			"time_bonus_multiplier": 2.2,
			"score_multiplier": 1.05,
			"effect_intensity": 1.05
		},
		{
			"id": 3,
			"name": "连击",
			"mode": "combo",
			"description": "鼓励连续消除，吃连击收益",
			"rows": 10,
			"cols": 7,
			"kinds": 8,
			"time_limit": 110,
			"time_bonus_multiplier": 2.4,
			"score_multiplier": 1.15,
			"effect_intensity": 1.1
		},
		{
			"id": 4,
			"name": "压迫",
			"mode": "rush",
			"description": "更大棋盘 + 更快决策",
			"rows": 12,
			"cols": 7,
			"kinds": 8,
			"time_limit": 120,
			"time_bonus_multiplier": 2.5,
			"score_multiplier": 1.2,
			"effect_intensity": 1.15
		},
		{
			"id": 5,
			"name": "终局",
			"mode": "endurance",
			"description": "终章挑战，稳定输出",
			"rows": 12,
			"cols": 8,
			"kinds": 9,
			"time_limit": 130,
			"time_bonus_multiplier": 2.8,
			"score_multiplier": 1.25,
			"effect_intensity": 1.2
		},
		{
			"id": 6,
			"name": "破阵",
			"mode": "combo",
			"description": "方阵压缩，考验连续判断",
			"rows": 10,
			"cols": 10,
			"kinds": 10,
			"time_limit": 136,
			"time_bonus_multiplier": 3.0,
			"score_multiplier": 1.32,
			"effect_intensity": 1.28
		},
		{
			"id": 7,
			"name": "双线冲刺",
			"mode": "rush",
			"description": "更密集棋盘，速度与准确并重",
			"rows": 12,
			"cols": 9,
			"kinds": 10,
			"time_limit": 144,
			"time_bonus_multiplier": 3.2,
			"score_multiplier": 1.38,
			"effect_intensity": 1.32
		},
		{
			"id": 8,
			"name": "迷城",
			"mode": "endurance",
			"description": "长局耐力战，持续稳定清场",
			"rows": 14,
			"cols": 8,
			"kinds": 11,
			"time_limit": 152,
			"time_bonus_multiplier": 3.4,
			"score_multiplier": 1.45,
			"effect_intensity": 1.36
		},
		{
			"id": 9,
			"name": "高压连段",
			"mode": "combo",
			"description": "大棋盘高连击，节奏不能断",
			"rows": 12,
			"cols": 10,
			"kinds": 11,
			"time_limit": 160,
			"time_bonus_multiplier": 3.7,
			"score_multiplier": 1.52,
			"effect_intensity": 1.4
		},
		{
			"id": 10,
			"name": "王座",
			"mode": "endurance",
			"description": "最终试炼：复杂版图与高倍率收益",
			"rows": 13,
			"cols": 10,
			"kinds": 12,
			"time_limit": 168,
			"time_bonus_multiplier": 4.0,
			"score_multiplier": 1.6,
			"effect_intensity": 1.46
		}
	]

func _default_icon_sets():
	return [
		{
			"id": "fruit",
			"name": "水果",
			"icons": ["🍎", "🍊", "🍌", "🍇", "🍓", "🥝", "🍑", "🍒", "🥭", "🍍", "🥥", "🍉"],
			"colors": ["#fef2f2", "#fff7ed", "#fefce8", "#eff6ff", "#fdf2f8", "#f0fdf4", "#fff1f2", "#fef2f2", "#fffbeb", "#ecfdf5", "#f8fafc", "#f0f9ff"]
		}
	]

func _build_ui():
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add gradient background
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color("f8fafc")
	add_child(bg_rect)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_constant_override("margin_left", 16)
	margin.add_constant_override("margin_right", 16)
	margin.add_constant_override("margin_top", 16)
	margin.add_constant_override("margin_bottom", 16)
	add_child(margin)
	margin_container = margin

	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_constant_override("separation", 12)
	margin.add_child(root)

	# Header panel with glass morphism effect
	var header_panel = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_glass_style(header_panel, Color("ffffff"), 0.9)
	root.add_child(header_panel)

	var header_box = VBoxContainer.new()
	header_box.add_constant_override("separation", 8)
	header_panel.add_child(header_box)

	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title_row)

	var title_col = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_col)

	title_label = Label.new()
	title_label.text = "连连看 H5"
	title_label.add_font_override("font", game_font)
	title_label.add_color_override("font_color", Color("7c3aed"))
	title_col.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "第1/1关 · 初始化"
	subtitle_label.add_font_override("font", game_font)
	subtitle_label.add_color_override("font_color", Color("64748b"))
	title_col.add_child(subtitle_label)

	desc_label = Label.new()
	desc_label.add_font_override("font", game_font)
	desc_label.add_color_override("font_color", Color("94a3b8"))
	desc_label.text = ""
	title_col.add_child(desc_label)

	status_chip_label = Label.new()
	status_chip_label.text = "进行中"
	status_chip_label.add_font_override("font", game_font)
	status_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_chip_label.custom_minimum_size = Vector2(90, 32)
	status_chip_label.add_color_override("font_color", Color("059669"))
	# Add status badge style
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color("d1fae5")
	status_style.set_corner_radius_all(16)
	status_chip_label.add_stylebox_override("normal", status_style)
	title_row.add_child(status_chip_label)

	var level_progress_label = Label.new()
	level_progress_label.text = "闯关进度"
	level_progress_label.add_font_override("font", game_font)
	level_progress_label.add_color_override("font_color", Color("64748b"))
	header_box.add_child(level_progress_label)

	level_progress_bar = ProgressBar.new()
	level_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_progress_bar.min_value = 0
	level_progress_bar.max_value = 100
	level_progress_bar.value = 0
	level_progress_bar.show_percentage = false
	level_progress_bar.custom_minimum_size = Vector2(0, 12)
	# Style progress bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color("e2e8f0")
	progress_bg.set_corner_radius_all(6)
	level_progress_bar.add_stylebox_override("background", progress_bg)
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color("8b5cf6")
	progress_fill.set_corner_radius_all(6)
	level_progress_bar.add_stylebox_override("fill", progress_fill)
	header_box.add_child(level_progress_bar)

	var meta_row = HBoxContainer.new()
	meta_row.add_constant_override("separation", 8)
	header_box.add_child(meta_row)

	mode_chip_label = _create_chip_label()
	meta_row.add_child(mode_chip_label)

	kinds_chip_label = _create_chip_label()
	meta_row.add_child(kinds_chip_label)

	stats_flow_container = HFlowContainer.new()
	stats_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_flow_container.add_constant_override("h_separation", 6)
	stats_flow_container.add_constant_override("v_separation", 6)
	header_box.add_child(stats_flow_container)

	_add_stat_card(stats_flow_container, "总分", "total_score")
	_add_stat_card(stats_flow_container, "本关分", "level_score")
	_add_stat_card(stats_flow_container, "步数", "moves")
	_add_stat_card(stats_flow_container, "剩余", "remaining")
	_add_stat_card(stats_flow_container, "倒计时", "time_left")
	_add_stat_card(stats_flow_container, "连击", "combo")
	_add_stat_card(stats_flow_container, "历史高分", "best_total_score")
	_add_stat_card(stats_flow_container, "历史连击", "best_combo")

	# Power-ups display container
	power_ups_container = HBoxContainer.new()
	power_ups_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	power_ups_container.add_constant_override("separation", 16)
	header_box.add_child(power_ups_container)

	# Create power-up labels
	_create_power_up_label("time_freeze", "⏱️", "1")
	_create_power_up_label("auto_match", "🎯", "2")
	_create_power_up_label("reshuffle", "🔄", "3")

	combo_progress_bar = ProgressBar.new()
	combo_progress_bar.min_value = 0
	combo_progress_bar.max_value = 100
	combo_progress_bar.value = 0
	combo_progress_bar.show_percentage = false
	combo_progress_bar.custom_minimum_size = Vector2(0, 10)
	# Style combo bar
	var combo_bg = StyleBoxFlat.new()
	combo_bg.bg_color = Color("e2e8f0")
	combo_bg.set_corner_radius_all(5)
	combo_progress_bar.add_stylebox_override("background", combo_bg)
	var combo_fill = StyleBoxFlat.new()
	combo_fill.bg_color = Color("f59e0b")
	combo_fill.set_corner_radius_all(5)
	combo_progress_bar.add_stylebox_override("fill", combo_fill)
	header_box.add_child(combo_progress_bar)

	controls_flow_container = HFlowContainer.new()
	controls_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_flow_container.add_constant_override("h_separation", 8)
	controls_flow_container.add_constant_override("v_separation", 8)
	header_box.add_child(controls_flow_container)

	icon_set_option = OptionButton.new()
	icon_set_option.add_font_override("font", game_font)
	icon_set_option.custom_minimum_size = Vector2(140, 42)
	icon_set_option.connect("item_selected", self, "_on_icon_set_selected")
	# Style the dropdown
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color("ffffff")
	dropdown_style.set_corner_radius_all(10)
	dropdown_style.shadow_color = Color("00000010")
	dropdown_style.shadow_size = 4
	dropdown_style.shadow_offset = Vector2(0, 2)
	dropdown_style.set_border_width_all(1)
	dropdown_style.border_color = Color("e2e8f0")
	icon_set_option.add_stylebox_override("normal", dropdown_style)
	icon_set_option.add_color_override("font_color", Color("475569"))
	controls_flow_container.add_child(icon_set_option)

	hint_button = _create_control_button("提示")
	hint_button.connect("pressed", self, "_on_hint_pressed")
	controls_flow_container.add_child(hint_button)

	auto_button = _create_control_button("自动消")
	auto_button.connect("pressed", self, "_on_auto_pressed")
	controls_flow_container.add_child(auto_button)

	shuffle_button = _create_control_button("洗牌")
	shuffle_button.connect("pressed", self, "_on_shuffle_pressed")
	controls_flow_container.add_child(shuffle_button)

	pause_button = _create_control_button("暂停")
	pause_button.connect("pressed", self, "_on_pause_pressed")
	controls_flow_container.add_child(pause_button)

	reset_button = _create_control_button("重开")
	reset_button.connect("pressed", self, "_on_reset_pressed")
	controls_flow_container.add_child(reset_button)

	progression_flow_container = HFlowContainer.new()
	progression_flow_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_flow_container.add_constant_override("h_separation", 8)
	progression_flow_container.add_constant_override("v_separation", 8)
	header_box.add_child(progression_flow_container)

	var level_select_label = Label.new()
	level_select_label.text = "关卡："
	level_select_label.add_font_override("font", game_font)
	level_select_label.add_color_override("font_color", Color("64748b"))
	progression_flow_container.add_child(level_select_label)

	level_select_option = OptionButton.new()
	level_select_option.add_font_override("font", game_font)
	level_select_option.custom_minimum_size = Vector2(172, 42)
	level_select_option.connect("item_selected", self, "_on_level_select_changed")
	level_select_option.add_stylebox_override("normal", dropdown_style)
	level_select_option.add_color_override("font_color", Color("475569"))
	progression_flow_container.add_child(level_select_option)

	jump_level_button = _create_control_button("跳转关卡")
	jump_level_button.connect("pressed", self, "_on_jump_level_pressed")
	progression_flow_container.add_child(jump_level_button)

	clear_progress_button = _create_control_button("清除进度")
	clear_progress_button.connect("pressed", self, "_on_clear_progress_pressed")
	progression_flow_container.add_child(clear_progress_button)

	settings_button = _create_control_button("⚙️ 设置")
	settings_button.connect("pressed", self, "_on_settings_pressed")
	progression_flow_container.add_child(settings_button)

	var achievements_button = _create_control_button("🏆 成就")
	achievements_button.connect("pressed", self, "_on_achievements_pressed")
	progression_flow_container.add_child(achievements_button)

	message_label = Label.new()
	message_label.add_font_override("font", game_font)
	message_label.add_color_override("font_color", Color("92400e"))
	message_label.visible = false
	header_box.add_child(message_label)

	board_wrapper = Control.new()
	board_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_wrapper.custom_minimum_size = Vector2(0, 400)
	root.add_child(board_wrapper)

	var board_panel = PanelContainer.new()
	board_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Apply game board style
	var board_style = StyleBoxFlat.new()
	board_style.bg_color = Color("ffffff")
	board_style.set_corner_radius_all(20)
	board_style.shadow_color = Color("00000015")
	board_style.shadow_size = 10
	board_style.shadow_offset = Vector2(0, 5)
	board_style.set_border_width_all(2)
	board_style.border_color = Color("e2e8f0")
	board_panel.add_stylebox_override("panel", board_style)
	board_wrapper.add_child(board_panel)

	var board_inner = Control.new()
	board_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_panel.add_child(board_inner)

	board_center = CenterContainer.new()
	board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_inner.add_child(board_center)

	board_grid = GridContainer.new()
	board_grid.columns = 6
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.add_constant_override("h_separation", 10)
	board_grid.add_constant_override("v_separation", 10)
	board_center.add_child(board_grid)

	path_overlay = PATH_OVERLAY_SCRIPT.new()
	path_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_inner.add_child(path_overlay)

	effect_layer = Control.new()
	effect_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_inner.add_child(effect_layer)

	stage_panel_label = Label.new()
	stage_panel_label.add_font_override("font", game_font)
	stage_panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_panel_label.add_color_override("font_color", Color("374151"))
	stage_panel_label.visible = false
	root.add_child(stage_panel_label)

	combo_burst_label = Label.new()
	combo_burst_label.add_font_override("font", game_font)
	combo_burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_burst_label.add_color_override("font_color", Color("b45309"))
	combo_burst_label.visible = false
	combo_burst_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	combo_burst_label.offset_top = 88
	combo_burst_label.offset_left = 0
	combo_burst_label.offset_right = 0
	add_child(combo_burst_label)

	_populate_icon_set_options()
	_populate_level_select_options()
	_build_onboarding_panel()
	_build_settings_panel()
	_build_achievements_panel()
	_build_pause_panel()
	call_deferred("_update_layout_for_screen_size")

func _build_onboarding_panel():
	onboarding_panel = PanelContainer.new()
	onboarding_panel.set_anchors_preset(Control.PRESET_CENTER)
	onboarding_panel.custom_minimum_size = Vector2(320, 400)
	onboarding_panel.visible = false
	_apply_glass_style(onboarding_panel, Color("ffffff"), 0.95)
	add_child(onboarding_panel)

	var vbox = VBoxContainer.new()
	onboarding_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 20)
	margin.add_constant_override("margin_right", 20)
	margin.add_constant_override("margin_top", 20)
	margin.add_constant_override("margin_bottom", 20)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 12)
	margin.add_child(content)

	var title = Label.new()
	title.text = "🎮 欢迎来到连连看"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_color_override("font_color", Color("1e293b"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	var sections = [
		{"title": "🎯 基本玩法", "content": "点击两个相同图案进行连接消除。路径最多可以拐弯 2 次。"},
		{"title": "🔓 解锁规则", "content": "完成当前关卡即可解锁下一关。已解锁的关卡可以随时切换挑战。"},
		{"title": "⌨️ 快捷键", "content": "H - 提示  |  A - 自动消除  |  S - 洗牌\nR - 重置  |  P - 暂停  |  [ / ] - 切换关卡"}
	]

	for section in sections:
		var section_title = Label.new()
		section_title.text = section.title
		section_title.add_color_override("font_color", Color("334155"))
		section_title.add_font_override("font", game_font)
		content.add_child(section_title)

		var section_content = Label.new()
		section_content.text = section.content
		section_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section_content.add_color_override("font_color", Color("64748b"))
		section_content.add_font_override("font", game_font)
		content.add_child(section_content)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	var got_it_button = Button.new()
	got_it_button.text = "知道了，开始游戏"
	got_it_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	got_it_button.custom_minimum_size = Vector2(0, 44)
	got_it_button.add_font_override("font", game_font)
	got_it_button.connect("pressed", self, "_on_onboarding_dismissed")
	content.add_child(got_it_button)

func _show_onboarding_if_needed():
	var has_seen_onboarding = progression_state.get(ONBOARDING_SEEN_KEY, false)
	if not has_seen_onboarding and onboarding_panel != null:
		onboarding_panel.visible = true
		stage_status = STATUS_PAUSED
		if second_timer:
			second_timer.stop()

func _on_onboarding_dismissed():
	if onboarding_panel != null:
		onboarding_panel.visible = false
	_patch_progress_state({ONBOARDING_SEEN_KEY: true})
	stage_status = STATUS_PLAYING
	if second_timer:
		second_timer.start()

func _build_settings_panel():
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.custom_minimum_size = Vector2(360, 320)
	settings_panel.visible = false
	_apply_glass_style(settings_panel, Color("ffffff"), 0.95)
	add_child(settings_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 16)
	settings_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 16)
	margin.add_child(content)

	# Title
	var title = Label.new()
	title.text = "⚙️ 设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_color_override("font_color", Color("1e293b"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	# Master volume
	var master_row = _create_volume_row("主音量", AudioManager.master_volume)
	master_row.slider.connect("value_changed", self, "_on_master_volume_changed")
	content.add_child(master_row.container)

	# Effects enabled
	var effects_row = _create_toggle_row("音效", AudioManager.effects_enabled)
	effects_row.toggle.connect("toggled", self, "_on_effects_toggled")
	content.add_child(effects_row.container)

	# Music enabled
	var music_row = _create_toggle_row("背景音乐", AudioManager.music_enabled)
	music_row.toggle.connect("toggled", self, "_on_music_toggled")
	content.add_child(music_row.container)

	# Mute all
	var mute_row = _create_toggle_row("静音", AudioManager.muted)
	mute_row.toggle.connect("toggled", self, "_on_mute_toggled")
	content.add_child(mute_row.container)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	# Close button
	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.add_font_override("font", game_font)
	close_button.connect("pressed", self, "_on_settings_close")
	content.add_child(close_button)

func _create_volume_row(label_text, initial_value):
	var container = HBoxContainer.new()
	container.add_constant_override("separation", 12)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	label.add_color_override("font_color", Color("334155"))
	label.add_font_override("font", game_font)
	container.add_child(label)

	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	container.add_child(slider)

	return {"container": container, "slider": slider}

func _create_toggle_row(label_text, initial_value):
	var container = HBoxContainer.new()
	container.add_constant_override("separation", 12)

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_color_override("font_color", Color("334155"))
	label.add_font_override("font", game_font)
	container.add_child(label)

	var toggle = CheckBox.new()
	toggle.button_pressed = initial_value
	container.add_child(toggle)

	return {"container": container, "toggle": toggle}

func _on_settings_pressed():
	if settings_panel == null:
		return
	settings_panel.visible = true
	if stage_status == STATUS_PLAYING:
		stage_status = STATUS_PAUSED
		if second_timer:
			second_timer.stop()

func _on_settings_close():
	if settings_panel != null:
		settings_panel.visible = false
	if stage_status == STATUS_PAUSED:
		stage_status = STATUS_PLAYING
		if second_timer:
			second_timer.start()

func _on_master_volume_changed(value):
	AudioManager.set_master_volume(value)

func _on_effects_toggled(enabled):
	AudioManager.set_effects_enabled(enabled)

func _on_music_toggled(enabled):
	AudioManager.set_music_enabled(enabled)

func _on_mute_toggled(muted):
	AudioManager.set_muted(muted)

func _build_achievements_panel():
	achievements_panel = PanelContainer.new()
	achievements_panel.set_anchors_preset(Control.PRESET_CENTER)
	achievements_panel.custom_minimum_size = Vector2(400, 480)
	achievements_panel.visible = false
	_apply_glass_style(achievements_panel, Color("ffffff"), 0.95)
	add_child(achievements_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 16)
	achievements_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 12)
	margin.add_child(content)

	# Title
	var title = Label.new()
	title.text = "🏆 成就"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_color_override("font_color", Color("1e293b"))
	content.add_child(title)

	var line = HSeparator.new()
	content.add_child(line)

	# Achievement list
	var achievements_list = VBoxContainer.new()
	achievements_list.add_constant_override("separation", 10)
	content.add_child(achievements_list)

	for achievement in PROGRESSION_SCRIPT.ACHIEVEMENTS:
		var item = _create_achievement_item(achievement)
		achievements_list.add_child(item)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	# Close button
	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.add_font_override("font", game_font)
	close_button.connect("pressed", self, "_on_achievements_close")
	content.add_child(close_button)

func _create_achievement_item(achievement):
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 12)

	var unlocked = PROGRESSION_SCRIPT.has_achievement(progression_state, achievement["id"])

	# Icon
	var icon_label = Label.new()
	icon_label.text = "🏆" if unlocked else "🔒"
	hbox.add_child(icon_label)

	# Text content
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label = Label.new()
	name_label.text = achievement["name"]
	name_label.add_color_override("font_color", Color("059669" if unlocked else "94a3b8"))
	name_label.add_font_override("font", game_font)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = achievement["desc"]
	desc_label.add_color_override("font_color", Color("64748b" if unlocked else "cbd5e1"))
	desc_label.add_font_override("font", game_font)
	vbox.add_child(desc_label)

	return hbox

func _on_achievements_pressed():
	if achievements_panel == null:
		return
	# Rebuild to update unlock status
	if achievements_panel.get_child_count() > 0:
		for child in achievements_panel.get_children():
			child.queue_free()
	_build_achievements_panel()
	achievements_panel.visible = true
	if stage_status == STATUS_PLAYING:
		stage_status = STATUS_PAUSED
		if second_timer:
			second_timer.stop()

func _on_achievements_close():
	if achievements_panel != null:
		achievements_panel.visible = false
	if stage_status == STATUS_PAUSED:
		stage_status = STATUS_PLAYING
		if second_timer:
			second_timer.start()

func _build_pause_panel():
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(320, 280)
	pause_panel.visible = false
	_apply_glass_style(pause_panel, Color("ffffff"), 0.98)
	add_child(pause_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 12)
	pause_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 24)
	margin.add_constant_override("margin_right", 24)
	margin.add_constant_override("margin_top", 24)
	margin.add_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_constant_override("separation", 12)
	margin.add_child(content)

	# Title
	var title = Label.new()
	title.text = "⏸️ 游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_color_override("font_color", Color("1e293b"))
	content.add_child(title)

	# Level info
	var level_info = Label.new()
	level_info.text = "当前关卡"
	level_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_info.add_color_override("font_color", Color("64748b"))
	level_info.add_font_override("font", game_font)
	content.add_child(level_info)

	var line = HSeparator.new()
	content.add_child(line)

	# Resume button
	var resume_button = Button.new()
	resume_button.text = "▶️ 继续游戏 (P)"
	resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_button.custom_minimum_size = Vector2(0, 44)
	resume_button.add_font_override("font", game_font)
	resume_button.connect("pressed", self, "_resume_stage")
	content.add_child(resume_button)

	# Restart button
	var restart_button = Button.new()
	restart_button.text = "🔄 重新开始"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.custom_minimum_size = Vector2(0, 44)
	restart_button.add_font_override("font", game_font)
	restart_button.connect("pressed", self, "_on_restart_current_level")
	content.add_child(restart_button)

	# Back to level 1 button
	var back_button = Button.new()
	back_button.text = "🏠 返回第1关"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.custom_minimum_size = Vector2(0, 44)
	back_button.add_font_override("font", game_font)
	back_button.connect("pressed", self, "_on_back_to_first_level")
	content.add_child(back_button)

func _show_pause_panel():
	if pause_panel == null:
		return
	# Update level info
	var vbox = pause_panel.get_child(0)
	var margin = vbox.get_child(0)
	var content = margin.get_child(0)
	var level_info = content.get_child(1) as Label
	var level = _current_level()
	var level_id = int(level.get("id", level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	level_info.text = "第" + str(level_id) + "关 - " + level_name

	pause_panel.visible = true

func _hide_pause_panel():
	if pause_panel != null:
		pause_panel.visible = false

func _on_restart_current_level():
	_hide_pause_panel()
	_start_level(level_index, false)
	_show_message("重新开始当前关卡", 1.0)

func _on_back_to_first_level():
	_hide_pause_panel()
	_start_level(0, true)
	_show_message("返回第1关", 1.0)

func _build_timers():
	second_timer = Timer.new()
	second_timer.wait_time = 1.0
	second_timer.one_shot = false
	second_timer.connect("timeout", self, "_on_second_tick")
	add_child(second_timer)

	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.connect("timeout", self, "_on_message_timeout")
	add_child(message_timer)

	error_timer = Timer.new()
	error_timer.one_shot = true
	error_timer.connect("timeout", self, "_on_error_timeout")
	add_child(error_timer)

	combo_reset_timer = Timer.new()
	combo_reset_timer.one_shot = true
	combo_reset_timer.connect("timeout", self, "_on_combo_reset_timeout")
	add_child(combo_reset_timer)

	level_highlight_timer = Timer.new()
	level_highlight_timer.one_shot = true
	level_highlight_timer.connect("timeout", self, "_on_level_highlight_timeout")
	add_child(level_highlight_timer)

	level_advance_timer = Timer.new()
	level_advance_timer.one_shot = true
	level_advance_timer.connect("timeout", self, "_on_level_advance_timeout")
	add_child(level_advance_timer)

	time_freeze_timer = Timer.new()
	time_freeze_timer.one_shot = true
	time_freeze_timer.connect("timeout", self, "_on_time_freeze_timeout")
	add_child(time_freeze_timer)

func _create_chip_label():
	var label = Label.new()
	label.add_font_override("font", game_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(120, 28)
	label.add_color_override("font_color", Color("7c3aed"))
	# Add subtle background
	var chip_style = StyleBoxFlat.new()
	chip_style.bg_color = Color("ede9fe")
	chip_style.set_corner_radius_all(14)
	label.add_stylebox_override("normal", chip_style)
	return label

func _create_control_button(text):
	var button = Button.new()
	button.add_font_override("font", game_font)
	button.text = text
	button.custom_minimum_size = Vector2(88, 42)
	button.add_color_override("font_color", Color("ffffff"))

	# Apply gradient button style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("6366f1")
	normal.set_corner_radius_all(10)
	normal.shadow_color = Color("6366f140")
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color("818cf8")
	hover.set_corner_radius_all(10)
	hover.shadow_color = Color("6366f160")
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 4)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color("4f46e5")
	pressed.set_corner_radius_all(10)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.connect("pressed", AudioManager, "play_button_click")

	return button

func _add_stat_card(parent, title, key):
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 64)
	parent.add_child(card)

	# Apply card style with gradient
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("ffffff")
	card_style.set_corner_radius_all(12)
	card_style.shadow_color = Color("00000010")
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_style.set_border_width_all(1)
	card_style.border_color = Color("e2e8f0")
	card.add_stylebox_override("panel", card_style)

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_constant_override("separation", 4)
	card.add_child(box)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_font_override("font", game_font)
	title_label.add_color_override("font_color", Color("64748b"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var value_label = Label.new()
	value_label.text = "--"
	value_label.add_font_override("font", game_font)
	value_label.add_color_override("font_color", Color("334155"))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)

	stat_values[key] = {
		"card": card,
		"title": title_label,
		"value": value_label
	}

func _create_power_up_label(power_up_id, icon, shortcut):
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 4)
	power_ups_container.add_child(hbox)

	var icon_label = Label.new()
	icon_label.text = icon
	hbox.add_child(icon_label)

	var count_label = Label.new()
	count_label.text = "x0"
	count_label.add_color_override("font_color", Color("64748b"))
	count_label.add_font_override("font", game_font)
	hbox.add_child(count_label)

	var shortcut_label = Label.new()
	shortcut_label.text = "[" + shortcut + "]"
	shortcut_label.add_color_override("font_color", Color("94a3b8"))
	hbox.add_child(shortcut_label)

	power_up_labels[power_up_id] = {
		"icon": icon_label,
		"count": count_label,
		"shortcut": shortcut_label
	}

func _populate_icon_set_options():
	icon_set_option.clear()
	for i in range(icon_sets.size()):
		var icon_set: Dictionary = icon_sets[i]
		icon_set_option.add_item(icon_set.get("name", "主题" + str(i + 1)))

	if icon_sets.size() > 0:
		icon_set_index = clamp(icon_set_index, 0, icon_sets.size() - 1)
		icon_set_option.select(icon_set_index)

func _on_icon_set_selected(index):
	icon_set_index = clamp(index, 0, max(0, icon_sets.size() - 1))
	_refresh_board_visuals()

func _is_level_unlocked(level_idx):
	return PROGRESSION_SCRIPT.is_level_unlocked(progression_state, level_idx, campaign_levels.size())

func _selected_level_option_index():
	if level_select_option == null or level_select_option.get_item_count() == 0:
		return level_index
	var selected_idx = int(level_select_option.get_selected_id())
	if selected_idx < 0:
		selected_idx = level_index
	return clamp(selected_idx, 0, campaign_levels.size() - 1)

func _sync_level_select_selection():
	if level_select_option == null or level_select_option.get_item_count() == 0:
		return
	level_select_option.select(level_index)

func _level_label_by_index(level_idx):
	var clamped = clamp(level_idx, 0, campaign_levels.size() - 1)
	var level: Dictionary = campaign_levels[clamped]
	return "第" + str(int(level.get("id", clamped + 1))) + "关 · " + str(level.get("name", "关卡"))

func _populate_level_select_options():
	if level_select_option == null:
		return

	level_select_option.clear()
	var best_times = progression_state.get("level_best_times", {})
	for i in range(campaign_levels.size()):
		var level: Dictionary = campaign_levels[i]
		var level_id = int(level.get("id", i + 1))
		var level_name = str(level.get("name", "关卡"))
		var unlocked = _is_level_unlocked(i)
		var label = "第" + str(level_id) + "关 · " + level_name
		# Add best time if available
		if best_times.has(str(i)):
			var best_time = float(best_times[str(i)])
			label += " ⏱️" + _format_time_seconds(best_time)
		if not unlocked:
			label += "（未解锁）"
		level_select_option.add_item(label)
		level_select_option.set_item_disabled(i, not unlocked)

	level_select_option.disabled = campaign_levels.size() <= 1
	_sync_level_select_selection()

func _on_level_select_changed(index):
	if not _is_level_unlocked(index):
		_sync_level_select_selection()
		_show_message("该关卡尚未解锁", 0.9)
		return
	_refresh_ui()

func _cycle_level_selection(step):
	if level_select_option == null or level_select_option.get_item_count() == 0:
		return
	var from_idx = _selected_level_option_index()
	var next_idx = PROGRESSION_SCRIPT.find_next_unlocked(progression_state, from_idx, step, campaign_levels.size())
	level_select_option.select(next_idx)
	_show_message("已选择" + _level_label_by_index(next_idx) + "，按 Enter 跳转", 0.9)
	_refresh_ui()
	_trigger_level_highlight()

func _trigger_level_highlight():
	if level_select_option == null:
		return
	level_select_option.modulate = LEVEL_HIGHLIGHT_COLOR
	level_highlight_timer.stop()
	level_highlight_timer.wait_time = 0.4
	level_highlight_timer.start()

func _on_level_highlight_timeout():
	if level_select_option != null:
		level_select_option.modulate = LEVEL_NORMAL_COLOR

func _start_bgm():
	AudioManager.start_bgm()

func _stop_bgm():
	AudioManager.stop_bgm()

func _on_jump_level_pressed():
	var target = _selected_level_option_index()
	if not _is_level_unlocked(target):
		_show_message("该关卡尚未解锁", 0.9)
		_sync_level_select_selection()
		return
	_start_level(target, true)

func _on_clear_progress_pressed():
	progression_state = PROGRESSION_SCRIPT.default_progress(campaign_levels.size())
	_save_progress_state()
	_populate_level_select_options()
	_start_level(0, true)
	_show_message("本地进度已清除，已回到第1关", 1.3)


func _start_level(next_index, reset_total = false):
	level_index = clamp(next_index, 0, campaign_levels.size() - 1)
	var level = _current_level()

	board = _create_playable_board(level)
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	path_overlay.clear_path()

	for child in effect_layer.get_children():
		child.queue_free()

	moves = 0
	level_score = 0
	time_left = int(level.get("time_limit", 90))
	stage_status = STATUS_PLAYING

	# Reset achievement tracking
	level_start_time = Time.get_ticks_msec()
	level_hints_used = 0
	level_auto_used = 0

	# Initialize power-ups based on level
	_init_power_ups(level)
	time_frozen = false

	if reset_total:
		total_score = 0
	_patch_progress_state({"current_level_index": level_index})

	_reset_combo()
	_hide_message()
	pending_level_index = -1
	stage_panel_label.visible = false

	_render_board()
	_sync_level_select_selection()
	_refresh_ui()
	_start_second_timer()
	_play_level_intro_animation(level)

	var level_id = int(level.get("id", level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	_show_message("进入第" + str(level_id) + "关：" + level_name + "（" + _mode_label(mode) + "） · 快捷键 H/A/S/P/F/R/[ ]/Enter", 1.35)

func _current_level():
	return campaign_levels[level_index]

func _create_playable_board(level):
	var rows = int(level.get("rows", 8))
	var cols = int(level.get("cols", 6))
	var kinds = int(level.get("kinds", 6))
	var created = _create_board(rows, cols, kinds)
	if _find_any_hint(created).is_empty():
		_reshuffle_board(created)
	return created

func _create_board(rows, cols, kinds):
	var total = rows * cols
	if total % 2 != 0:
		total -= 1

	var ids = []
	for i in range(total / 2):
		var id = (i % max(1, kinds)) + 1
		ids.append(id)
		ids.append(id)

	_shuffle_array(ids)

	var created = []
	var index = 0
	for r in range(rows):
		var row = []
		for c in range(cols):
			row.append(ids[index])
			index += 1
		created.append(row)
	return created

func _shuffle_array(arr):
	for i in range(arr.size() - 1, 0, -1):
		var j = int(rand_range(0, i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _render_board():
	for child in board_grid.get_children():
		child.queue_free()
	cell_buttons.clear()

	if board.is_empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	board_grid.columns = cols

	for r in range(rows):
		var row_buttons = []
		for c in range(cols):
			var button = Button.new()
			button.text = ""
			button.custom_minimum_size = Vector2(52, 52)
			button.add_font_override("font", game_font)
			button.focus_mode = Control.FOCUS_NONE
			button.set_meta("row", r)
			button.set_meta("col", c)
			button.connect("pressed", self, "_on_tile_pressed", [button])
			board_grid.add_child(button)
			row_buttons.append(button)
		cell_buttons.append(row_buttons)

	_update_tile_sizes()
	_refresh_board_visuals()

func _update_tile_sizes():
	if board.is_empty() or cell_buttons.is_empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	var h_sep = board_grid.get_theme_constant("h_separation")
	var v_sep = board_grid.get_theme_constant("v_separation")

	# Get available board area and keep a minimum usable size.
	var viewport_size = get_viewport_rect().size
	var flags = _viewport_flags(viewport_size)
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]
	var padding = 4 if is_mobile and is_compact_height else (6 if is_mobile and is_portrait else (10 if is_mobile else 24))
	var board_area = board_wrapper.size
	if board_area.x <= 1 or board_area.y <= 1:
		board_area = board_wrapper.custom_minimum_size
	var available = board_area - Vector2(padding * 2, padding * 2)
	available.x = max(available.x, 120.0)
	available.y = max(available.y, 120.0)

	# Calculate tile size to fit all tiles.
	var by_width = int(floor((available.x - float(cols - 1) * h_sep) / max(1, cols)))
	var by_height = int(floor((available.y - float(rows - 1) * v_sep) / max(1, rows)))

	# Clamp tile size: portrait mobile gets larger minimum tiles for readability.
	var min_tile = 34 if is_mobile and is_portrait else (30 if is_mobile else 34)
	var max_tile = 90 if is_mobile and is_portrait else (76 if is_mobile else 110)
	var tile = clamp(min(by_width, by_height), min_tile, max_tile)

	for r in range(rows):
		for c in range(cols):
			var button = cell_buttons[r][c]
			button.custom_minimum_size = Vector2(tile, tile)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.add_font_override("font", game_font)

func _refresh_board_visuals():
	if board.is_empty() or cell_buttons.is_empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	var playing = stage_status == STATUS_PLAYING

	for r in range(rows):
		for c in range(cols):
			var value = int(board[r][c])
			var button = cell_buttons[r][c]

			if value == 0:
				button.text = ""
				button.disabled = true
				_apply_tile_style(button, Color("f1f5f9"), Color("cbd5e1"), false)
				continue

			button.text = _icon_for(value)
			button.disabled = not playing

			var bg = _color_for(value)
			var border = Color("ffffff")
			var is_selected = (selected.x == r and selected.y == c)
			var has_effect = false

			if _contains_coord(error_tiles, Vector2(r, c)):
				bg = Color("fee2e2")
				border = Color("ef4444")
				has_effect = true
			elif _contains_coord(hint_tiles, Vector2(r, c)):
				bg = Color("dbeafe")
				border = Color("3b82f6")
				has_effect = true

			if is_selected:
				border = Color("f59e0b")
				has_effect = true

			_apply_tile_style(button, bg, border, has_effect or is_selected)

func _apply_tile_style(button, bg_color, border_color, highlight):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)

	if highlight:
		normal.shadow_color = border_color
		normal.shadow_size = 6
		normal.shadow_offset = Vector2(0, 2)
	else:
		normal.shadow_color = Color("00000010")
		normal.shadow_size = 3
		normal.shadow_offset = Vector2(0, 2)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.06)
	hover.border_color = border_color.lightened(0.05)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	hover.shadow_color = Color("00000020")
	hover.shadow_size = 5
	hover.shadow_offset = Vector2(0, 3)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.08)
	pressed.border_color = border_color.darkened(0.05)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("disabled", normal)

func _apply_glass_style(panel, bg_color, alpha):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, alpha)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color("e2e8f0")
	style.shadow_color = Color("00000020")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_stylebox_override("panel", style)

func _apply_button_style(button, bg_color, border_color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color("00000015")
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.08)
	hover.border_color = border_color.lightened(0.1)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(12)
	hover.shadow_color = Color("00000020")
	hover.shadow_size = 6
	hover.shadow_offset = Vector2(0, 3)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.05)
	pressed.border_color = border_color.darkened(0.05)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(12)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("disabled", normal)

func _icon_for(value):
	if icon_sets.is_empty():
		return str(value)

	var icon_set: Dictionary = icon_sets[icon_set_index]
	var icons: Array = icon_set.get("icons", [])
	var index = value - 1
	if index >= 0 and index < icons.size():
		return str(icons[index])
	return str(value)

func _color_for(value):
	if icon_sets.is_empty():
		return Color("ffffff")

	var icon_set: Dictionary = icon_sets[icon_set_index]
	var colors: Array = icon_set.get("colors", [])
	var index = value - 1
	if index >= 0 and index < colors.size():
		return Color(str(colors[index]))
	return Color("ffffff")

func _contains_coord(list, coord):
	for item in list:
		if item == coord:
			return true
	return false


func _on_tile_pressed(button):
	if stage_status != STATUS_PLAYING:
		return
	if button == null:
		return
	var r = int(button.get_meta("row"))
	var c = int(button.get_meta("col"))
	if board[r][c] == 0:
		return

	var point = Vector2(r, c)

	if selected.x < 0:
		selected = point
		hint_tiles.clear()
		error_tiles.clear()
		AudioManager.play_select()
		_animate_select(point)
		_refresh_board_visuals()
		return

	if selected == point:
		selected = Vector2(-1, -1)
		_refresh_board_visuals()
		return

	moves += 1
	var previous = selected

	var selected_value = int(board[previous.x][previous.y])
	var target_value = int(board[point.x][point.y])

	if selected_value != target_value:
		selected = point
		hint_tiles.clear()
		AudioManager.play_error()
		_flash_error_tiles([previous, point])
		_animate_select(point)
		_show_message("请先选择相同图案", 0.7)
		_refresh_ui()
		_refresh_board_visuals()
		return

	var path = _find_path(board, previous, point)
	if path.is_empty():
		selected = point
		hint_tiles.clear()
		AudioManager.play_error()
		_flash_error_tiles([previous, point])
		_animate_select(point)
		_show_message("路径不通：最多只能拐2次弯", 0.9)
		_refresh_ui()
		_refresh_board_visuals()
		return

	var a = previous
	var b = point
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()

	AudioManager.play_eliminate_combo(combo)

	var score_result = _apply_combo_gain(int(tuning.get("base_score", 10)))
	if score_result["combo"] > 1:
		_show_message("连击 x" + str(score_result["combo"]) + " +" + str(score_result["gain"]), 0.88)
		_show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	_show_path(path, "eliminate", int(tuning.get("path_preview_ms", 420)))
	_play_eliminate_effects([a, b])

	board[a.x][a.y] = 0
	board[b.x][b.y] = 0

	_refresh_ui()
	_refresh_board_visuals()
	_resolve_after_board_changed()


func _on_hint_pressed():
	if stage_status != STATUS_PLAYING:
		return

	level_hints_used += 1
	AudioManager.play_hint()

	var hint = _find_any_hint(board)
	if hint.is_empty():
		_on_shuffle_pressed()
		return

	selected = hint["a"]
	hint_tiles = [hint["a"], hint["b"]]
	error_tiles.clear()

	var hint_path: Array = hint["path"]
	_show_path(hint_path, "hint", int(tuning.get("hint_preview_ms", 1400)))
	_animate_hint_tiles(hint_tiles)
	_show_message("已高亮一组可消除方块", 1.1)
	_consume_time_cost(int(tuning.get("hint_time_cost_seconds", 1)))
	_refresh_ui()
	_refresh_board_visuals()

func _on_auto_pressed():
	if stage_status != STATUS_PLAYING:
		return

	level_auto_used += 1

	var hint = _find_any_hint(board)
	if hint.is_empty():
		_on_shuffle_pressed()
		return

	var a = hint["a"]
	var b = hint["b"]
	var hint_path: Array = hint["path"]

	var will_clear = false
	if _remaining_tiles_count() <= 2:
		will_clear = true

	board[a.x][a.y] = 0
	board[b.x][b.y] = 0

	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	moves += 1

	_show_path(hint_path, "eliminate", int(tuning.get("hint_preview_ms", 1400)))
	_play_eliminate_effects([a, b])

	var score_result = _apply_combo_gain(int(tuning.get("base_score", 10)))
	_show_message("自动消除 +" + str(score_result["gain"]), 0.9)
	if score_result["combo"] > 1:
		_show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	if not will_clear:
		_consume_time_cost(int(tuning.get("auto_eliminate_time_cost_seconds", 2)))

	_refresh_ui()
	_refresh_board_visuals()
	_resolve_after_board_changed()


func _on_shuffle_pressed():
	if stage_status != STATUS_PLAYING:
		return

	AudioManager.play_shuffle()

	_animate_shuffle_wave()
	_reshuffle_board(board)
	_spawn_board_particles(14, Color("60a5fa"), 0.9)

	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	_show_message("已洗牌", 0.8)
	_consume_time_cost(int(tuning.get("shuffle_time_cost_seconds", 1)))
	_refresh_ui()
	_refresh_board_visuals()

func _on_pause_pressed():
	if stage_status == STATUS_PLAYING:
		_pause_stage()
	elif stage_status == STATUS_PAUSED:
		_resume_stage()

func _pause_stage():
	if stage_status != STATUS_PLAYING:
		return

	stage_status = STATUS_PAUSED
	second_timer.stop()
	combo_reset_timer.stop()
	_show_pause_panel()
	_refresh_ui()
	_refresh_board_visuals()

func _resume_stage():
	if stage_status != STATUS_PAUSED:
		return

	stage_status = STATUS_PLAYING
	_hide_pause_panel()
	_start_second_timer()
	if combo > 0:
		combo_expires_ms = Time.get_ticks_msec() + int(tuning.get("combo_window_ms", 2600))
		combo_reset_timer.stop()
		combo_reset_timer.wait_time = float(tuning.get("combo_window_ms", 2600)) / 1000.0
		combo_reset_timer.start()
	_show_message("继续游戏", 0.65)
	_refresh_ui()
	_refresh_board_visuals()

func _toggle_fullscreen_mode():
	if OS.window_fullscreen:
		OS.window_fullscreen = false
		_show_message("已退出全屏", 0.8)
	else:
		OS.window_fullscreen = true
		_show_message("已进入全屏", 0.8)

func _on_reset_pressed():
	if stage_status == STATUS_COMPLETED:
		_start_level(0, true)
		return
	_start_level(level_index, false)


func _play_eliminate_effects(coords):
	var effect_intensity = float(_current_level().get("effect_intensity", 1.0))

	# Determine particle color and amount based on combo
	var color = Color("ff7a00")  # Default orange
	var particle_count = int(6 + effect_intensity * 2.0)
	var particle_color = Color("ffffff")  # Default white

	if combo >= 10:
		color = Color("ffd700")  # Gold
		particle_color = Color("ffd700")
		particle_count = int(30 * effect_intensity)
	elif combo >= 7:
		color = Color("7c3aed")  # Purple
		particle_color = Color("a855f7")
		particle_count = int(24 * effect_intensity)
	elif combo >= 5:
		color = Color("2563eb")  # Blue
		particle_color = Color("60a5fa")
		particle_count = int(18 * effect_intensity)
	elif combo >= 3:
		color = Color("059669")  # Green
		particle_color = Color("34d399")
		particle_count = int(12 * effect_intensity)

	for coord in coords:
		var button = _try_get_tile_button(coord)
		if button == null:
			continue

		_pulse_tile(coord, 1.14, 0.08, 1)

		var center = _tile_center_in_effect_layer(coord)
		_spawn_ring_effect(center, color, 0.24, 14.0 * effect_intensity)
		_spawn_combo_particle_burst(center, particle_color, particle_count, combo)

		var star = Label.new()
		star.text = "✦"
		star.add_font_override("font", game_font)
		star.position = center
		star.pivot_offset = Vector2(8, 8)
		star.scale = Vector2.ONE
		star.modulate = color
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(star)

		# Tween animation for star effect
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(star, "position", star.position, star.position + Vector2(0, -18 * effect_intensity), 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property(star, "modulate:a", 1.0, 0.0, 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property(star, "scale", Vector2.ONE, Vector2.ONE * (1.35 * effect_intensity), 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	star.queue_free()
	tween.queue_free()


func _animate_select(coord):
	var button = _try_get_tile_button(coord)
	if button == null:
		return

	button.pivot_offset = button.size * 0.5
	# Tween animation for select effect
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(button, "scale", button.scale, Vector2(1.08, 1.08), 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.interpolate_property(button, "scale", button.scale, Vector2.ONE, 0.12, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.queue_free()

	var center = _tile_center_in_effect_layer(coord)
	_spawn_ring_effect(center, Color("f97316"), 0.18, 12.0)

func _try_get_tile_button(coord):
	if coord.x < 0 or coord.x >= cell_buttons.size():
		return null
	var row_buttons: Array = cell_buttons[coord.x]
	if coord.y < 0 or coord.y >= row_buttons.size():
		return null
	return row_buttons[coord.y]

func _tile_center_in_effect_layer(coord):
	var button = _try_get_tile_button(coord)
	if button == null:
		return Vector2.ZERO
	return effect_layer.to_local(button.global_position + button.size * 0.5)

func _pulse_tile(coord, peak_scale, half_duration, loops = 1):
	var button = _try_get_tile_button(coord)
	if button == null:
		return
	button.pivot_offset = button.size * 0.5

	# Tween animation for pulse effect
	for _i in range(max(1, loops)):
		var tween1 = Tween.new()
		add_child(tween1)
		tween1.interpolate_property(button, "scale", button.scale, Vector2.ONE * peak_scale, half_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween1.start()
		yield(tween1, "tween_completed")
		tween1.queue_free()
		
		var tween2 = Tween.new()
		add_child(tween2)
		tween2.interpolate_property(button, "scale", button.scale, Vector2.ONE, half_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween2.start()
		yield(tween2, "tween_completed")
		tween2.queue_free()

func _shake_tile(coord):
	var button = _try_get_tile_button(coord)
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(1.04, 1.04)

	# Tween animation for shake effect
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(button, "rotation_degrees", button.rotation_degrees, -6.0, 0.04, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.interpolate_property(button, "rotation_degrees", button.rotation_degrees, 6.0, 0.06, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.interpolate_property(button, "rotation_degrees", button.rotation_degrees, -4.0, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.interpolate_property(button, "rotation_degrees", button.rotation_degrees, 0.0, 0.06, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.interpolate_property(button, "scale", button.scale, Vector2.ONE, 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.queue_free()

func _animate_hint_tiles(coords):
	for coord in coords:
		_pulse_tile(coord, 1.09, 0.08, 2)
		var center = _tile_center_in_effect_layer(coord)
		_spawn_ring_effect(center, Color("0ea5e9"), 0.26, 12.0)

func _animate_shuffle_wave():
	if board.is_empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	for r in range(rows):
		for c in range(cols):
			if int(board[r][c]) == 0:
				continue
			var button = _try_get_tile_button(Vector2(r, c))
			if button == null:
				continue

			button.pivot_offset = button.size * 0.5
			var delay = float(r + c) * 0.012 + rand_range(0.0, 0.03)

			var tween = Tween.new()
	add_child(tween)
			# (interval skipped - manual implementation needed)
	tween.interpolate_property(button, "scale", button.scale, Vector2(0.82, 0.82), 0.07, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property(button, "scale", Vector2(0.82, 0.82), Vector2(1.08, 1.08), 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property(button, "scale", Vector2(1.08, 1.08), Vector2.ONE, 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

func _spawn_ring_effect(center, color, duration, base_size):
	if center == Vector2.ZERO:
		return

	var ring = Panel.new()
	ring.size = Vector2.ONE * base_size
	ring.position = center - ring.size * 0.5
	ring.pivot_offset = ring.size * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(base_size * 0.5))
	ring.add_stylebox_override("panel", style)
	effect_layer.add_child(ring)

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(ring, "scale", ring.scale, Vector2(1.9, 1.9, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT), duration)
	tween.connect("tween_completed", self, "_on_tween_done") # was: ring.queue_free

func _spawn_particle_burst(center, color, particle_count, intensity):
	var count = max(4, particle_count)
	for _i in range(count):
		var particle = Label.new()
		particle.text = "•"
		particle.add_font_override("font", game_font)
		particle.position = center
		particle.modulate = color
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(particle)

		var angle = rand_range(0.0, TAU)
		var distance = rand_range(16.0, 44.0) * intensity
		var target = center + Vector2(cos(angle), sin(angle)) * distance

		var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(particle, "position", particle.position, target, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.connect("tween_completed", self, "_on_tween_done") # was: particle.queue_free

func _spawn_combo_particle_burst(center, color, particle_count, combo_level):
	var count = max(8, particle_count)
	var shapes = ["•", "✦", "★", "◆"]
	var shape_index = min(combo_level / 3, shapes.size() - 1)

	for _i in range(count):
		var particle = Label.new()
		particle.text = shapes[shape_index]
		particle.add_font_override("font", game_font)
		particle.position = center
		var size = int(8 + rand_range(0.0, 8.0) + combo_level * 0.5)
		particle.modulate = color
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(particle)

		var angle = rand_range(0.0, TAU)
		var distance = rand_range(20.0, 60.0 + combo_level * 3.0)
		var target = center + Vector2(cos(angle), sin(angle)) * distance

		var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(particle, "position", particle.position, target, 0.4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.connect("tween_completed", self, "_on_tween_done") # was: particle.queue_free

func _spawn_board_particles(count, color, intensity):
	var area = effect_layer.size
	if area.x <= 0 or area.y <= 0:
		return

	for _i in range(count):
		var sparkle = Label.new()
		sparkle.text = "✦"
		sparkle.add_font_override("font", game_font)
		sparkle.position = Vector2(
			rand_range(16.0, max(16.0, area.x - 16.0)),
			rand_range(24.0, max(24.0, area.y - 16.0))
		)
		sparkle.modulate = color
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(sparkle)

		var tween = Tween.new()
	add_child(tween)
	var drift = Vector2(rand_range(-32.0, 32.0), rand_range(-84.0, -28.0))
	tween.interpolate_property(sparkle, "position", sparkle.position, sparkle.position + drift, 0.52, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.connect("tween_completed", self, "_on_tween_done") # was: sparkle.queue_free

func _show_stage_callout(text, color, font_size):
	var label = Label.new()
	label.text = text
	label.add_font_override("font", game_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 108
	label.offset_left = 0
	label.offset_right = 0
	label.modulate = Color(1, 1, 1, 0.95)
	label.add_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(label, "offset_top", label.offset_top, 74.0, 0.35, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.connect("tween_completed", self, "_on_tween_done") # was: label.queue_free

func _play_level_intro_animation(level):
	var level_id = int(level.get("id", level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	_show_stage_callout("第" + str(level_id) + "关 · " + level_name, Color("2563eb"), 19)
	_animate_board_spawn()

func _animate_board_spawn():
	if board.is_empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	var center_r = float(rows - 1) * 0.5
	var center_c = float(cols - 1) * 0.5

	for r in range(rows):
		for c in range(cols):
			if int(board[r][c]) == 0:
				continue
			var button = _try_get_tile_button(Vector2(r, c))
			if button == null:
				continue

			button.pivot_offset = button.size * 0.5
			button.scale = Vector2(0.72, 0.72)
			button.modulate.a = 0.0

			var dist = abs(float(r) - center_r) + abs(float(c) - center_c)
			var tween = Tween.new()
			add_child(tween)
			# (interval skipped - manual implementation needed)
			tween.interpolate_property(button, "modulate:a", button.modulate.a, 1.0, 0.09, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			tween.interpolate_property(button, "scale", button.scale, Vector2.ONE, 0.09, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

func _play_stage_clear_celebration(is_final_clear):
	var burst_color = Color("f59e0b") if is_final_clear else Color("22c55e")
	var text = "全部通关!" if is_final_clear else "过关!"
	var particle_count = 28 if is_final_clear else 16
	var intensity = 1.2 if is_final_clear else 1.0

	_show_stage_callout(text, burst_color, 24 if is_final_clear else 21)
	_spawn_board_particles(particle_count, burst_color, intensity)

func _show_combo_burst(text):
	# Enhanced combo burst with dynamic styling based on combo level
	var combo_num = combo
	var color = Color("b45309")  # Default amber
	var font_size = 18

	if combo_num >= 10:
		color = Color("dc2626")  # Red for 10+ combo
		font_size = 28
	elif combo_num >= 7:
		color = Color("7c3aed")  # Purple for 7+ combo
		font_size = 24
	elif combo_num >= 5:
		color = Color("2563eb")  # Blue for 5+ combo
		font_size = 22
	elif combo_num >= 3:
		color = Color("059669")  # Green for 3+ combo
		font_size = 20

	combo_burst_label.text = text
	combo_burst_label.visible = true
	combo_burst_label.modulate = Color(1, 1, 1, 1)
	combo_burst_label.offset_top = 88
	combo_burst_label.add_color_override("font_color", color)

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(combo_burst_label, "offset_top", combo_burst_label.offset_top, 68.0, 0.22, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.connect("tween_completed", self, "_on_tween_done") # was: func( :

func _show_path(path, preview_type, duration_ms):
	var points = _path_to_overlay_points(path)
	if points.size() < 2:
		return
	var color = PATH_COLOR_ELIMINATE
	if preview_type == "hint":
		color = PATH_COLOR_HINT
	path_overlay.show_path(points, color, float(duration_ms) / 1000.0)

func _path_to_overlay_points(path):
	var result = []
	if cell_buttons.is_empty():
		return result
	if cell_buttons[0].is_empty():
		return result

	var first_button = cell_buttons[0][0]
	var first_center = path_overlay.to_local(first_button.global_position + first_button.size * 0.5)
	var step_x = first_button.size.x + board_grid.get_theme_constant("h_separation")
	var step_y = first_button.size.y + board_grid.get_theme_constant("v_separation")

	for item in path:
		var point = item
		var mapped = Vector2(
			first_center.x + float(point.y) * step_x,
			first_center.y + float(point.x) * step_y
		)
		result.append(mapped)
	return result


func _flash_error_tiles(coords):
	error_tiles.clear()
	for coord in coords:
		var point = coord
		if _contains_coord(error_tiles, point):
			continue
		error_tiles.append(point)
		_shake_tile(point)
		var center = _tile_center_in_effect_layer(point)
		_spawn_ring_effect(center, Color("ef4444"), 0.22, 12.0)

	error_timer.stop()
	error_timer.start(float(tuning.get("error_flash_ms", 420)) / 1000.0)

func _on_error_timeout():
	error_tiles.clear()
	_refresh_board_visuals()

func _show_message(text, duration_sec = 1.0):
	message_label.text = text
	message_label.visible = true
	message_timer.stop()
	message_timer.wait_time = max(0.1, duration_sec)
	message_timer.start()

func _hide_message():
	message_label.visible = false
	message_timer.stop()

func _on_message_timeout():
	message_label.visible = false

func _init_power_ups(level):
	# Reset power-ups
	power_ups = {"time_freeze": 0, "auto_match": 0, "reshuffle": 0}

	# Grant power-ups based on level difficulty
	var level_id = int(level.get("id", 1))
	var mode = str(level.get("mode", "classic"))

	# Base power-ups
	power_ups["time_freeze"] = 1
	power_ups["reshuffle"] = 1

	# Extra power-ups for harder levels
	if level_id >= 3:
		power_ups["auto_match"] = 1
	if level_id >= 5:
		power_ups["time_freeze"] = 2
	if mode == "rush":
		power_ups["time_freeze"] += 1
	if mode == "endurance":
		power_ups["reshuffle"] += 1

func _use_power_up(power_up_type):
	if power_ups.get(power_up_type, 0) <= 0:
		return
	if stage_status != STATUS_PLAYING:
		return

	match power_up_type:
		"time_freeze":
			_activate_time_freeze()
		"auto_match":
			_activate_auto_match()
		"reshuffle":
			_activate_reshuffle()

	power_ups[power_up_type] -= 1
	_refresh_ui()
	AudioManager.play_button_click()

func _activate_time_freeze():
	time_frozen = true
	_show_message("⏱️ 时间冻结！", 1.5)
	if time_freeze_timer:
		time_freeze_timer.stop()
		time_freeze_timer.wait_time = 5.0
		time_freeze_timer.start()

func _activate_auto_match():
	var hint = _find_any_hint(board)
	if hint.is_empty():
		_show_message("没有可自动消除的对子", 1.0)
		return
	var a = hint["a"]
	var b = hint["b"]
	var button_a = _try_get_tile_button(a)
	var button_b = _try_get_tile_button(b)
	if button_a == null or button_b == null:
		return
	selected = a
	_on_tile_pressed(button_a)
	yield(get_tree().create_timer(0.2), "timeout")
	_on_tile_pressed(button_b)

func _activate_reshuffle():
	_reshuffle_board(board)
	_show_message("🔄 棋盘已重排", 1.0)
	_refresh_board_visuals()

func _on_time_freeze_timeout():
	time_frozen = false
	_show_message("时间恢复流逝", 1.0)

func _start_second_timer():
	second_timer.stop()
	second_timer.start()

func _on_second_tick():
	if stage_status != STATUS_PLAYING:
		return

	if time_frozen:
		return

	time_left = max(0, time_left - 1)
	_refresh_ui()

	if time_left <= 0:
		_on_time_up()

func _on_time_up():
	if stage_status != STATUS_PLAYING:
		return
	_patch_progress_state({
		"current_level_index": level_index,
		"score_candidate": total_score,
		"combo_candidate": combo
	})

	stage_status = STATUS_FAILED
	AudioManager.play_fail()
	_reset_combo()
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()

	second_timer.stop()
	stage_panel_label.text = "本关失败，点击\"重开\"重试"
	stage_panel_label.visible = true
	_show_message("时间到！第" + str(_current_level().get("id", level_index + 1)) + "关失败", 1.8)

	_refresh_ui()
	_refresh_board_visuals()

func _consume_time_cost(seconds):
	if seconds <= 0 or stage_status != STATUS_PLAYING:
		return

	time_left = max(0, time_left - seconds)
	_refresh_ui()
	if time_left == 0:
		_on_time_up()

func _apply_combo_gain(base_score):
	var now_ms = Time.get_ticks_msec()
	var combo_window = int(tuning.get("combo_window_ms", 2600))
	var max_combo = int(tuning.get("max_combo", 8))
	var score_multiplier = float(_current_level().get("score_multiplier", 1.0))

	if now_ms <= combo_expires_ms:
		combo = min(combo + 1, max_combo)
	else:
		combo = 1

	combo_expires_ms = now_ms + combo_window
	combo_reset_timer.stop()
	combo_reset_timer.wait_time = float(combo_window) / 1000.0
	combo_reset_timer.start()

	var scaled_base = max(1, int(round(base_score * score_multiplier)))
	# New combo formula: base 1.5x, +0.5x per combo level
	var combo_multiplier = 1.5 + (combo - 1) * 0.5
	var gain = int(scaled_base * combo_multiplier)

	total_score += gain
	level_score += gain
	_patch_progress_state({
		"score_candidate": total_score,
		"combo_candidate": combo
	})

	return {
		"combo": combo,
		"gain": gain
	}

func _on_combo_reset_timeout():
	_reset_combo()
	_refresh_ui()

func _reset_combo():
	combo = 0
	combo_expires_ms = 0
	combo_progress_bar.value = 0
	combo_reset_timer.stop()

func _update_combo_progress():
	if stage_status != STATUS_PLAYING or combo <= 0:
		combo_progress_bar.value = 0
		return

	var remain = max(0, combo_expires_ms - Time.get_ticks_msec())
	var window_ms = max(1, int(tuning.get("combo_window_ms", 2600)))
	var progress = (float(remain) / float(window_ms)) * 100.0
	combo_progress_bar.value = progress


func _resolve_after_board_changed():
	if _remaining_tiles_count() == 0:
		var time_bonus_multiplier = float(_current_level().get("time_bonus_multiplier", 2.0))
		var time_bonus = int(round(float(time_left) * time_bonus_multiplier))
		total_score += time_bonus
		level_score += time_bonus

		var progress_patch := {
			"score_candidate": total_score,
			"combo_candidate": combo
		}
		if level_index >= campaign_levels.size() - 1:
			progress_patch["current_level_index"] = 0
			progress_patch["highest_unlocked_level_index"] = max(0, campaign_levels.size() - 1)
		else:
			progress_patch["current_level_index"] = level_index + 1
			progress_patch["highest_unlocked_level_index"] = level_index + 1
		_patch_progress_state(progress_patch)

		_reset_combo()
		second_timer.stop()
		stage_panel_label.visible = false

		if level_index >= campaign_levels.size() - 1:
			stage_status = STATUS_COMPLETED
			stage_panel_label.text = "全部关卡已完成，点击'再来一轮'"
			stage_panel_label.visible = true
			AudioManager.play_win()
			_show_message("全部通关！时间奖励 +" + str(time_bonus), 2.5)
			_play_stage_clear_celebration(true)
		else:
			stage_status = STATUS_CLEARED
			pending_level_index = level_index + 1
			stage_panel_label.text = "过关结算中，准备进入下一关"
			stage_panel_label.visible = true
			AudioManager.play_win()
			_show_message("第" + str(_current_level().get("id", level_index + 1)) + "关通过！时间奖励 +" + str(time_bonus), 1.2)
			_play_stage_clear_celebration(false)
			level_advance_timer.stop()
			level_advance_timer.wait_time = float(tuning.get("level_advance_ms", 1200)) / 1000.0
			level_advance_timer.start()

		_refresh_ui()
		_refresh_board_visuals()
		_check_achievements_on_clear()
		return

	if _find_any_hint(board).is_empty():
		_reshuffle_board(board)
		_show_message("无解，已自动重排", 1.0)
		_refresh_board_visuals()

func _on_level_advance_timeout():
	if stage_status != STATUS_CLEARED:
		return
	if pending_level_index < 0:
		return

	var next_index = pending_level_index
	pending_level_index = -1
	_start_level(next_index, false)

func _remaining_tiles_count():
	var count = 0
	for row in board:
		for value in row:
			if int(value) != 0:
				count += 1
	return count

func _refresh_ui():
	var level = _current_level()
	var level_id = int(level.get("id", level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	var description = str(level.get("description", ""))
	var unlocked_level_count = int(progression_state.get("highest_unlocked_level_index", 0)) + 1

	title_label.text = "连连看 H5"
	subtitle_label.text = "第" + str(level_id) + "/" + str(campaign_levels.size()) + "关 · " + level_name + " · 已解锁" + str(unlocked_level_count) + "/" + str(campaign_levels.size())
	desc_label.text = description

	status_chip_label.text = _status_label(stage_status)
	# Update status chip style based on status
	var status_style = StyleBoxFlat.new()
	status_style.set_corner_radius_all(16)
	if stage_status == STATUS_PLAYING:
		status_chip_label.add_color_override("font_color", Color("059669"))
		status_style.bg_color = Color("d1fae5")
	elif stage_status == STATUS_PAUSED:
		status_chip_label.add_color_override("font_color", Color("b45309"))
		status_style.bg_color = Color("fef3c7")
	elif stage_status == STATUS_CLEARED:
		status_chip_label.add_color_override("font_color", Color("7c3aed"))
		status_style.bg_color = Color("ede9fe")
	elif stage_status == STATUS_FAILED:
		status_chip_label.add_color_override("font_color", Color("dc2626"))
		status_style.bg_color = Color("fee2e2")
	else:
		status_chip_label.add_color_override("font_color", Color("059669"))
		status_style.bg_color = Color("d1fae5")
	status_chip_label.add_stylebox_override("normal", status_style)

	mode_chip_label.text = "模式：" + _mode_label(mode)
	kinds_chip_label.text = "图案种类：" + str(level.get("kinds", 0))

	level_progress_bar.value = (float(level_index + 1) / float(max(1, campaign_levels.size()))) * 100.0

	_set_stat_text("total_score", str(total_score))
	_set_stat_text("level_score", str(level_score))
	_set_stat_text("moves", str(moves))
	_set_stat_text("remaining", str(_remaining_tiles_count() / 2))
	_set_stat_text("time_left", _format_time(time_left))
	_set_stat_text("combo", "x" + str(max(combo, 1)))
	_set_stat_text("best_total_score", str(_progress_best_score()))
	_set_stat_text("best_combo", "x" + str(_progress_best_combo()))

	_set_time_card_state(_is_time_danger())

	var input_enabled = stage_status == STATUS_PLAYING
	hint_button.disabled = not input_enabled
	auto_button.disabled = not input_enabled
	shuffle_button.disabled = not input_enabled
	if level_select_option:
		level_select_option.disabled = campaign_levels.size() <= 1
	var selected_level_index = _selected_level_option_index()
	var can_jump = selected_level_index != level_index and _is_level_unlocked(selected_level_index)
	if jump_level_button:
		jump_level_button.disabled = not can_jump
	if clear_progress_button:
		clear_progress_button.disabled = false
	var pause_enabled = stage_status == STATUS_PLAYING or stage_status == STATUS_PAUSED
	pause_button.disabled = not pause_enabled
	pause_button.text = "继续" if stage_status == STATUS_PAUSED else "暂停"

	if stage_status == STATUS_COMPLETED:
		reset_button.text = "再来一轮"
	else:
		reset_button.text = "重开"

	# Update power-ups display
	_update_power_ups_display()

func _update_power_ups_display():
	for power_up_id in power_up_labels.keys():
		var count = power_ups.get(power_up_id, 0)
		var labels = power_up_labels[power_up_id]
		labels["count"].text = "x" + str(count)
		# Gray out if no power-ups available
		var has_power_up = count > 0
		labels["icon"].modulate = Color(1, 1, 1, 1.0 if has_power_up else 0.4)
		labels["count"].add_color_override("font_color", Color("059669" if has_power_up else "94a3b8"))

func _set_stat_text(key, value):
	if not stat_values.has(key):
		return
	var value_label = stat_values[key]["value"]
	value_label.text = value


func _is_time_danger():
	return stage_status == STATUS_PLAYING and time_left <= int(tuning.get("time_danger_seconds", 10))

func _update_time_warning_pulse(_delta):
	if not stat_values.has("time_left"):
		return

	var card = stat_values["time_left"]["card"]
	if not _is_time_danger():
		return

	var tick = float(Time.get_ticks_msec()) / 1000.0
	var pulse = 0.5 + 0.5 * sin(tick * 8.0)
	var intensity = 0.8 + pulse * 0.2

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, intensity * 0.89, intensity * 0.89, 1.0)
	card_style.set_corner_radius_all(12)
	card_style.shadow_color = Color("00000010")
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_style.set_border_width_all(1)
	card_style.border_color = Color("fecaca")
	card.add_stylebox_override("panel", card_style)

func _set_time_card_state(is_danger):
	if not stat_values.has("time_left"):
		return
	var card = stat_values["time_left"]["card"]
	var card_style = StyleBoxFlat.new()
	card_style.set_corner_radius_all(12)
	card_style.shadow_color = Color("00000010")
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_style.set_border_width_all(1)

	if is_danger:
		card_style.bg_color = Color("fee2e2")
		card_style.border_color = Color("fecaca")
	else:
		card_style.bg_color = Color("ffffff")
		card_style.border_color = Color("e2e8f0")

	card.add_stylebox_override("panel", card_style)

func _mode_label(mode):
	match mode:
		"classic":
			return "经典"
		"rush":
			return "冲刺"
		"combo":
			return "连击"
		"endurance":
			return "耐力"
		_:
			return "未知"

func _status_label(status):
	match status:
		STATUS_PLAYING:
			return "进行中"
		STATUS_PAUSED:
			return "已暂停"
		STATUS_CLEARED:
			return "过关中"
		STATUS_FAILED:
			return "失败"
		STATUS_COMPLETED:
			return "全通关"
		_:
			return "未知"

func _format_time(seconds):
	var mm = seconds / 60
	var ss = seconds % 60
	return "%02d:%02d" % [mm, ss]

func _format_time_seconds(time_seconds):
	var mm = int(time_seconds) / 60
	var ss = int(time_seconds) % 60
	var ms = int((time_seconds - int(time_seconds)) * 100)
	return "%02d:%02d.%02d" % [mm, ss, ms]

# Achievement system

func _check_achievements_on_clear():
	var level_clear_time = (Time.get_ticks_msec() - level_start_time) / 1000.0
	var new_unlocks = []

	# Check and update level best time
	var current_best = float(progression_state.get("level_best_times", {}).get(str(level_index), 999999.0))
	var is_new_record = level_clear_time < current_best
	if is_new_record:
		_patch_progress_state({"level_best_time": {"level_index": level_index, "time": level_clear_time}})
		_show_message("🎉 新纪录！用时 " + _format_time_seconds(level_clear_time), 2.0)

	# first_clear: Complete level 1 (index 0)
	if level_index == 0 and not PROGRESSION_SCRIPT.has_achievement(progression_state, "first_clear"):
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, "first_clear")
		new_unlocks.append("first_clear")

	# combo_novice: Reach 3+ combo
	if combo >= 3 and not PROGRESSION_SCRIPT.has_achievement(progression_state, "combo_novice"):
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, "combo_novice")
		new_unlocks.append("combo_novice")

	# combo_master: Reach 10+ combo
	if combo >= 10 and not PROGRESSION_SCRIPT.has_achievement(progression_state, "combo_master"):
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, "combo_master")
		new_unlocks.append("combo_master")

	# speed_star: Clear level in 30 seconds
	if level_clear_time <= 30.0 and not PROGRESSION_SCRIPT.has_achievement(progression_state, "speed_star"):
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, "speed_star")
		new_unlocks.append("speed_star")

	# perfect_clear: No hints and no auto used
	if level_hints_used == 0 and level_auto_used == 0 and not PROGRESSION_SCRIPT.has_achievement(progression_state, "perfect_clear"):
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, "perfect_clear")
		new_unlocks.append("perfect_clear")

	# completionist: All levels cleared (handled in _on_last_level_completed)
	if level_index >= campaign_levels.size() - 1 and not PROGRESSION_SCRIPT.has_achievement(progression_state, "completionist"):
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, "completionist")
		new_unlocks.append("completionist")

	# Save progress and show notifications
	if new_unlocks.size() > 0:
		_save_progress_state()
		for achievement_id in new_unlocks:
			var info = PROGRESSION_SCRIPT.get_achievement_info(achievement_id)
			_show_achievement_notification(info["name"])

func _show_achievement_notification(achievement_name):
	# Create floating achievement notification
	var notification = PanelContainer.new()
	notification.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification.offset_top = 60
	_apply_glass_style(notification, Color("fef3c7"), 0.95)
	add_child(notification)

	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 8)
	notification.add_child(hbox)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 16)
	margin.add_constant_override("margin_right", 16)
	margin.add_constant_override("margin_top", 12)
	margin.add_constant_override("margin_bottom", 12)
	hbox.add_child(margin)

	var label = Label.new()
	label.text = "🏆 成就解锁：" + achievement_name
	label.add_color_override("font_color", Color("92400e"))
	label.add_font_override("font", game_font)
	margin.add_child(label)

	# Auto-dismiss after animation
	var dismiss_timer = Timer.new()
	dismiss_timer.one_shot = true
	dismiss_timer.wait_time = 2.5
	dismiss_timer.connect("timeout", self, "_on_achievement_dismiss", [notification])
	add_child(dismiss_timer)
	dismiss_timer.start()

func _on_achievement_dismiss(notification):
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(notification, "modulate", notification.modulate, Color(1, 1, 1, 0), 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	notification.queue_free()
	tween.queue_free()

func _is_inside(board_state, point):
	return point.x >= 0 and point.x < board_state.size() and point.y >= 0 and point.y < board_state[0].size()

func _pad_board(board_state):
	var rows = board_state.size()
	var cols = board_state[0].size()
	var padded = []

	for r in range(rows + 2):
		var row = []
		for c in range(cols + 2):
			row.append(0)
		padded.append(row)

	for r in range(rows):
		for c in range(cols):
			padded[r + 1][c + 1] = board_state[r][c]

	return padded

func _find_path(board_state, a, b):
	if not _is_inside(board_state, a) or not _is_inside(board_state, b):
		return []
	if a == b:
		return []

	var value_a = int(board_state[a.x][a.y])
	var value_b = int(board_state[b.x][b.y])
	if value_a == 0 or value_b == 0 or value_a != value_b:
		return []

	var padded = _pad_board(board_state)
	var start = Vector2(a.x + 1, a.y + 1)
	var target = Vector2(b.x + 1, b.y + 1)

	var p_rows = padded.size()
	var p_cols = padded[0].size()

	var visited = []
	for r in range(p_rows):
		var row = []
		for c in range(p_cols):
			row.append([999, 999, 999, 999])
		visited.append(row)

	var queue = []
	var head = 0
	var parent = {}

	for d in range(4):
		var np = start + DIRS[d]
		if np.x < 0 or np.x >= p_rows or np.y < 0 or np.y >= p_cols:
			continue
		if int(padded[np.x][np.y]) != 0 and np != target:
			continue
		visited[np.x][np.y][d] = 0
		var node = {"r": np.x, "c": np.y, "dir": d, "turns": 0}
		queue.append(node)
		parent[_node_key(np.x, np.y, d, 0)] = _node_key(start.x, start.y, -1, 0)

	while head < queue.size():
		var cur: Dictionary = queue[head]
		head += 1

		if int(cur["r"]) == target.x and int(cur["c"]) == target.y:
			var path_padded = _reconstruct_path(cur, parent, start)
			var compressed = _compress_path(path_padded)

			var unpadded = []
			for p in compressed:
				unpadded.append(Vector2(p.x - 1, p.y - 1))
			return unpadded

		for nd in range(4):
			var nr = int(cur["r"]) + DIRS[nd].x
			var nc = int(cur["c"]) + DIRS[nd].y
			if nr < 0 or nr >= p_rows or nc < 0 or nc >= p_cols:
				continue
			if int(padded[nr][nc]) != 0 and not (nr == target.x and nc == target.y):
				continue

			var turns = int(cur["turns"])
			var nturns = turns + (0 if int(cur["dir"]) == nd else 1)
			if nturns > 2:
				continue
			if int(visited[nr][nc][nd]) <= nturns:
				continue

			visited[nr][nc][nd] = nturns
			var next_node = {"r": nr, "c": nc, "dir": nd, "turns": nturns}
			queue.append(next_node)
			parent[_node_key(nr, nc, nd, nturns)] = _node_key(int(cur["r"]), int(cur["c"]), int(cur["dir"]), turns)

	return []

func _node_key(r, c, d, t):
	return str(r) + "," + str(c) + "," + str(d) + "," + str(t)

func _parse_node_key(key):
	var parts = key.split(",")
	return [int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])]

func _reconstruct_path(cur, parent, start):
	var steps = []
	var key = _node_key(int(cur["r"]), int(cur["c"]), int(cur["dir"]), int(cur["turns"]))

	while parent.has(key):
		var parsed = _parse_node_key(key)
		steps.append(Vector2(parsed[0], parsed[1]))
		key = parent[key]

	steps.reverse()
	var path: Array = [start]
	for item in steps:
		path.append(item)
	return path

func _compress_path(points):
	if points.size() <= 2:
		return points.duplicate()

	var result: Array = [points[0]]
	for i in range(1, points.size() - 1):
		var prev = result[result.size() - 1]
		var current = points[i]
		var next = points[i + 1]

		var v1 = current - prev
		var v2 = next - current
		if v1 != v2:
			result.append(current)

	result.append(points[points.size() - 1])
	return result

func _find_any_hint(board_state):
	var rows = board_state.size()
	var cols = board_state[0].size()

	for r1 in range(rows):
		for c1 in range(cols):
			var value = int(board_state[r1][c1])
			if value == 0:
				continue

			for r2 in range(r1, rows):
				var start_c = c1 + 1 if r2 == r1 else 0
				for c2 in range(start_c, cols):
					if int(board_state[r2][c2]) != value:
						continue

						var path = _find_path(board_state, Vector2(r1, c1), Vector2(r2, c2))
						if not path.is_empty():
							return {
								"a": Vector2(r1, c1),
								"b": Vector2(r2, c2),
								"path": path
							}

	return {}

func _reshuffle_board(board_state):
	var rows = board_state.size()
	var cols = board_state[0].size()

	var tiles = []
	for r in range(rows):
		for c in range(cols):
			var value = int(board_state[r][c])
			if value != 0:
				tiles.append(value)

	if tiles.size() % 2 != 0:
		return

	for _attempt in range(20):
		_shuffle_array(tiles)
		var index = 0
		for r in range(rows):
			for c in range(cols):
				if int(board_state[r][c]) != 0:
					board_state[r][c] = tiles[index]
					index += 1

		if not _find_any_hint(board_state).is_empty():
			return
