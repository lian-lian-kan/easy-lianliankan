extends Control

const CAMPAIGN_PATH = "res://data/campaign.json"
const TUNING_PATH = "res://data/tuning.json"
const ICON_SETS_PATH = "res://data/icon_sets.json"
const GAME_MODES_PATH = "res://data/game_modes.json"
const PROGRESS_SAVE_PATH = "user://campaign_progress.json"

const STATUS_PLAYING = "playing"
const STATUS_PAUSED = "paused"
const STATUS_CLEARED = "cleared"
const STATUS_FAILED = "failed"
const STATUS_COMPLETED = "completed"

const BOARD_ENGINE = preload("res://scripts/board_engine.gd")

const UI_PANELS = preload("res://scripts/ui_panels.gd")

const STATS_HUD = preload("res://scripts/stats_hud.gd")

const DIRS = [
	Vector2(-1, 0),
	Vector2(1, 0),
	Vector2(0, -1),
	Vector2(0, 1)
]

const PATH_COLOR_HINT = Color("74c0fc")
const PATH_COLOR_ELIMINATE = Color("ff6f9c")
const PATH_OVERLAY_SCRIPT = preload("res://scripts/path_overlay.gd")
const PROGRESSION_SCRIPT = preload("res://scripts/progression.gd")
const SPECIAL_MODES_SCRIPT = preload("res://scripts/special_modes.gd")
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
var game_mode_configs = {}

# Special session state ("daily" / "time_attack" / "endless"); empty means
# the normal campaign flow. special_level is the virtual level dict in play.
var special_mode = ""
var special_level = {}
var endless_round = 1

# Memory (盲盒) session state
var memory_previewing = false
var memory_lock = false
var memory_revealed = {}
var memory_pending_hide = []
var memory_preview_timer
var memory_hide_timer

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
var power_ups: Dictionary = {"time_freeze": 0, "auto_match": 0, "reshuffle": 0, "warm_patch": 0}
var time_frozen = false
var time_freeze_timer

# Armed click-targeted power-ups (炸弹/彩虹/暖宝宝): arm -> next board click executes.
var bomb_pending = false
var rainbow_pending = false
var frost_pending = false
# Warm patches used this frost session (gates the 寒冰骑士 achievement).
var frost_uses = 0

# Frost mode: parallel to board, 1 = frozen cell (needs one extra match).
# Ice binds to the POSITION: reshuffles swap tiles under the ice sheet.
var board_armor = []

# 叠层/重力/迷雾/锁链: optional board mechanics on classic rules.
var board_lower = []      # stack: hidden tiles under their covers
var board_chain = []      # chain: 1 = chained (unlock via adjacent clears)
var _fog_layers = 0       # fog: current outer-ring count

# 步数挑战: remaining pair-removals. 竞速对战: AI opponent progress.
var moves_left = 0
var race_ai_pairs = 0
var race_total_pairs = 0
var race_elapsed = 0
var race_timer

# Sakura petals drifting over the background, confetti on stage clear.
var _petal_layer
var _petal_timer

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
var root_vbox
var header_box
var level_progress_caption_label
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
var modes_panel  # 玩法模式面板
var modes_content  # 玩法模式面板行容器
var pause_exit_button  # 特殊模式退出按钮
var modes_button  # 玩法模式入口按钮

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
		match key_event.scancode:
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
			KEY_4:
				_use_power_up("magnifier")
				accept_event()
			KEY_5:
				_use_power_up("time_sand")
				accept_event()
			KEY_6:
				_use_power_up("bomb")
				accept_event()
			KEY_7:
				_use_power_up("rainbow")
				accept_event()
			KEY_8:
				_use_power_up("warm_patch")
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
		onboarding_panel.rect_min_size = Vector2(min(320.0, max_width), min(400.0, max_height))
	if settings_panel:
		settings_panel.rect_min_size = Vector2(min(360.0, max_width), min(320.0, max_height))
	if achievements_panel:
		achievements_panel.rect_min_size = Vector2(min(400.0, max_width), min(480.0, max_height))
	if pause_panel:
		pause_panel.rect_min_size = Vector2(min(320.0, max_width), min(280.0, max_height))
	if modes_panel:
		modes_panel.rect_min_size = Vector2(min(360.0, max_width), min(700.0, max_height))

	# Panels are mounted inside full-rect CenterContainer holders (see
	# _mount_modal_panel), so dynamic content never knocks them off-center.

# A CenterContainer holder keeps dialogs centered whatever their content
# size does; mouse_filter IGNORE lets board clicks pass through when the
# dialog is hidden.
func _mount_modal_panel(panel):
	var holder = CenterContainer.new()
	holder.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.add_child(panel)
	return holder

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
		# Portrait relies on EXPAND_FILL for remaining space; keep the min small to avoid overflow.
		var mobile_ratio = BOARD_RATIO_MOBILE_PORTRAIT if is_portrait else BOARD_RATIO_MOBILE_LANDSCAPE
		var ratio = 0.42 if is_portrait else mobile_ratio
		board_wrapper.rect_min_size = Vector2(0, min(max(BOARD_MIN_HEIGHT, viewport_size.y * ratio), viewport_size.y * 0.62))
	else:
		board_wrapper.rect_min_size = Vector2(0, max(420.0, viewport_size.y * BOARD_RATIO_DESKTOP))

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

	# Power-up shortcut chips only make sense with a keyboard.
	for power_up_id in power_up_labels:
		var labels = power_up_labels[power_up_id]
		if labels.has("shortcut") and labels["shortcut"] != null:
			labels["shortcut"].visible = not is_mobile

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

	var stat_card_size = Vector2(66, 44) if is_mobile and is_portrait else (Vector2(82, 54) if is_mobile else Vector2(100, 64))
	var stat_value_size = 16 if is_mobile and is_portrait else (20 if is_mobile else 22)
	var stat_title_size = 10 if is_mobile else 11
	for key in stat_values.keys():
		var card = stat_values[key]["card"]
		var title_small = stat_values[key]["title"]
		var value_label = stat_values[key]["value"]
		card.rect_min_size = stat_card_size
		title_small.rect_min_size = Vector2(0, stat_title_size + 4)
		value_label.rect_min_size = Vector2(0, stat_value_size + 6)

	var control_min = Vector2(72, 34) if is_mobile and is_compact_height else (Vector2(76, 36) if is_mobile and is_portrait else (Vector2(80, 36) if is_mobile else Vector2(88, 42)))
	if icon_set_option:
		icon_set_option.rect_min_size = Vector2(108 if is_mobile else 122, control_min.y)
	if level_select_option:
		level_select_option.rect_min_size = Vector2(130 if is_mobile else 172, control_min.y)
	for button in [hint_button, auto_button, shuffle_button, pause_button, reset_button, jump_level_button, clear_progress_button, modes_button]:
		if button:
			button.rect_min_size = control_min

	if controls_flow_container:
		controls_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		controls_flow_container.add_constant_override("v_separation", 6 if is_mobile else 8)
	if progression_flow_container:
		progression_flow_container.add_constant_override("h_separation", 4 if is_mobile else 8)
		progression_flow_container.add_constant_override("v_separation", 6 if is_mobile else 8)

	# Portrait phones: compress the header so the board fits the visible canvas.
	if is_mobile and is_portrait:
		if root_vbox:
			root_vbox.add_constant_override("separation", 4)
		if header_box:
			header_box.add_constant_override("separation", 3)
		if level_progress_caption_label:
			level_progress_caption_label.visible = false
		if jump_level_button:
			jump_level_button.visible = false
		if clear_progress_button:
			clear_progress_button.visible = false
		if level_select_option:
			level_select_option.rect_min_size = Vector2(150, control_min.y)
		if combo_progress_bar:
			combo_progress_bar.rect_min_size = Vector2(0, 4)
		# Single row of the 4 essential cards keeps the header to one stat line.
		for hidden_key in ["level_score", "moves", "best_total_score", "best_combo"]:
			if stat_values.has(hidden_key) and stat_values[hidden_key].has("card"):
				stat_values[hidden_key]["card"].visible = false
	else:
		for hidden_key in ["level_score", "moves", "best_total_score", "best_combo"]:
			if stat_values.has(hidden_key) and stat_values[hidden_key].has("card"):
				stat_values[hidden_key]["card"].visible = true
		if level_progress_caption_label:
			level_progress_caption_label.visible = true
		if jump_level_button:
			jump_level_button.visible = true
		if clear_progress_button:
			clear_progress_button.visible = true

	_update_modal_panel_sizes(viewport_size, is_portrait)

const DISPLAY_FONT = preload("res://fonts/ZCOOLKuaiLe-Regular.ttf")
const EMBEDDED_FONT = preload("res://fonts/NotoSansSC-Regular.ttf")
const EMOJI_FONT = preload("res://fonts/NotoColorEmoji.ttf")

var _font_cache = {}

func _font_at_size(px):
	px = int(max(8, px))
	if _font_cache.has(px):
		return _font_cache[px]
	var font = DynamicFont.new()
	# Cute rounded face first; Noto covers glyphs KuaiLe lacks, emoji last.
	font.font_data = DISPLAY_FONT if DISPLAY_FONT else EMBEDDED_FONT
	font.size = px
	font.use_filter = true
	if EMBEDDED_FONT:
		font.add_fallback(EMBEDDED_FONT)
	if EMOJI_FONT:
		font.add_fallback(EMOJI_FONT)
	_font_cache[px] = font
	return font

func _init_font():
	# Web export: bundled CJK font with color-emoji fallback so tiles render everywhere.
	game_font = _font_at_size(16)

	var theme = Theme.new()
	theme.set_font("font", "Label", game_font)
	theme.set_font("font", "Button", game_font)
	theme.set_font("font", "OptionButton", game_font)
	theme.set_font("font", "PopupMenu", game_font)
	theme.set_font("font", "CheckBox", game_font)
	self.theme = theme

func _load_config():
	campaign_levels = _load_campaign_levels()
	tuning = _load_tuning()
	icon_sets = _load_icon_sets()
	game_mode_configs = _load_game_mode_configs()

	if campaign_levels.empty():
		campaign_levels = _default_campaign_levels()
	if icon_sets.empty():
		icon_sets = _default_icon_sets()

func _load_game_mode_configs():
	return SPECIAL_MODES_SCRIPT.normalize_configs(_load_json_file(GAME_MODES_PATH))

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
	# Special sessions only persist their own records, never campaign progress
	# or the campaign best-score/combo candidates.
	if special_mode != "":
		var filtered = patch.duplicate()
		filtered.erase("score_candidate")
		filtered.erase("combo_candidate")
		filtered.erase("current_level_index")
		filtered.erase("highest_unlocked_level_index")
		if filtered.empty():
			return
		patch = filtered
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
	set_anchors_and_margins_preset(Control.PRESET_WIDE)

	# Add gradient background
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	bg_rect.color = Color("fff0f6")
	add_child(bg_rect)

	_petal_layer = Control.new()
	_petal_layer.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_petal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_petal_layer)
	_build_petals()

	var margin = MarginContainer.new()
	margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
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
	root_vbox = root

	# Header panel with glass morphism effect
	var header_panel = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_glass_style(header_panel, Color("ffffff"), 0.9)
	root.add_child(header_panel)

	header_box = VBoxContainer.new()
	header_box.add_constant_override("separation", 8)
	header_panel.add_child(header_box)

	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title_row)

	var title_col = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_col)

	title_label = Label.new()
	title_label.text = "连连看 🎀"
	title_label.add_font_override("font", game_font)
	title_label.add_color_override("font_color", Color("e64980"))
	title_col.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "第1/1关 · 初始化"
	subtitle_label.add_font_override("font", game_font)
	subtitle_label.add_color_override("font_color", Color("8f6b80"))
	title_col.add_child(subtitle_label)

	desc_label = Label.new()
	desc_label.add_font_override("font", game_font)
	desc_label.add_color_override("font_color", Color("c2a3b2"))
	desc_label.text = ""
	title_col.add_child(desc_label)

	status_chip_label = Label.new()
	status_chip_label.text = "进行中"
	status_chip_label.add_font_override("font", game_font)
	status_chip_label.align = Label.ALIGN_CENTER
	status_chip_label.valign = Label.VALIGN_CENTER
	status_chip_label.rect_min_size = Vector2(90, 32)
	status_chip_label.add_color_override("font_color", Color("0ca678"))
	# Add status badge style
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color("e6fcf5")
	status_style.set_corner_radius_all(16)
	status_chip_label.add_stylebox_override("normal", status_style)
	title_row.add_child(status_chip_label)

	level_progress_caption_label = Label.new()
	level_progress_caption_label.text = "闯关进度"
	level_progress_caption_label.add_font_override("font", game_font)
	level_progress_caption_label.add_color_override("font_color", Color("8f6b80"))
	header_box.add_child(level_progress_caption_label)

	level_progress_bar = ProgressBar.new()
	level_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_progress_bar.min_value = 0
	level_progress_bar.max_value = 100
	level_progress_bar.value = 0
	level_progress_bar.percent_visible = false
	level_progress_bar.rect_min_size = Vector2(0, 12)
	# Style progress bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color("ffd9e8")
	progress_bg.set_corner_radius_all(6)
	level_progress_bar.add_stylebox_override("background", progress_bg)
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color("f783ac")
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
	_add_stat_card(stats_flow_container, "对手", "race")

	# Power-ups display container
	# Single row, centered. On phones the [1]-[7] shortcut chips are hidden
	# (keyboard-only affordance) so all 7 power-ups fit a 390px width.
	power_ups_container = HBoxContainer.new()
	power_ups_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	power_ups_container.add_constant_override("separation", 6)
	header_box.add_child(power_ups_container)

	# Create power-up labels
	_create_power_up_label("time_freeze", "⏱️", "1")
	_create_power_up_label("auto_match", "🎯", "2")
	_create_power_up_label("reshuffle", "🔄", "3")
	_create_power_up_label("magnifier", "🔍", "4")
	_create_power_up_label("time_sand", "⏳", "5")
	_create_power_up_label("bomb", "💣", "6")
	_create_power_up_label("rainbow", "🌈", "7")
	_create_power_up_label("warm_patch", "🔥", "8")

	combo_progress_bar = ProgressBar.new()
	combo_progress_bar.min_value = 0
	combo_progress_bar.max_value = 100
	combo_progress_bar.value = 0
	combo_progress_bar.percent_visible = false
	combo_progress_bar.rect_min_size = Vector2(0, 10)
	# Style combo bar
	var combo_bg = StyleBoxFlat.new()
	combo_bg.bg_color = Color("ffd9e8")
	combo_bg.set_corner_radius_all(5)
	combo_progress_bar.add_stylebox_override("background", combo_bg)
	var combo_fill = StyleBoxFlat.new()
	combo_fill.bg_color = Color("ff8fab")
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
	icon_set_option.rect_min_size = Vector2(140, 42)
	icon_set_option.connect("item_selected", self, "_on_icon_set_selected")
	# Style the dropdown
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color("ffffff")
	dropdown_style.set_corner_radius_all(10)
	dropdown_style.shadow_color = Color("00000010")
	dropdown_style.shadow_size = 4
	dropdown_style.shadow_offset = Vector2(0, 2)
	dropdown_style.set_border_width_all(1)
	dropdown_style.border_color = Color("ffd9e8")
	icon_set_option.add_stylebox_override("normal", dropdown_style)
	icon_set_option.add_color_override("font_color", Color("8f6b80"))
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

	modes_button = _create_control_button("🎮 玩法")
	modes_button.connect("pressed", self, "_on_modes_pressed")
	progression_flow_container.add_child(modes_button)

	var level_select_label = Label.new()
	level_select_label.text = "关卡："
	level_select_label.add_font_override("font", game_font)
	level_select_label.add_color_override("font_color", Color("8f6b80"))
	progression_flow_container.add_child(level_select_label)

	level_select_option = OptionButton.new()
	level_select_option.add_font_override("font", game_font)
	level_select_option.rect_min_size = Vector2(172, 42)
	level_select_option.connect("item_selected", self, "_on_level_select_changed")
	level_select_option.add_stylebox_override("normal", dropdown_style)
	level_select_option.add_color_override("font_color", Color("8f6b80"))
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
	message_label.add_color_override("font_color", Color("d6336c"))
	message_label.visible = false
	header_box.add_child(message_label)

	board_wrapper = Control.new()
	board_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_wrapper.rect_min_size = Vector2(0, 400)
	root.add_child(board_wrapper)
	# Let the board absorb ALL remaining height instead of overflowing the canvas.
	board_wrapper.size_flags_stretch_ratio = 1.0

	var board_panel = PanelContainer.new()
	board_panel.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	# Apply game board style
	var board_style = StyleBoxFlat.new()
	board_style.bg_color = Color("ffffff")
	board_style.set_corner_radius_all(26)
	board_style.shadow_color = Color("00000015")
	board_style.shadow_size = 10
	board_style.shadow_offset = Vector2(0, 5)
	board_style.set_border_width_all(2)
	board_style.border_color = Color("ffd9e8")
	board_panel.add_stylebox_override("panel", board_style)
	board_wrapper.add_child(board_panel)

	var board_inner = Control.new()
	board_inner.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	board_panel.add_child(board_inner)

	board_center = CenterContainer.new()
	board_center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
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
	path_overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_inner.add_child(path_overlay)

	effect_layer = Control.new()
	effect_layer.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_inner.add_child(effect_layer)

	stage_panel_label = Label.new()
	stage_panel_label.add_font_override("font", game_font)
	stage_panel_label.align = Label.ALIGN_CENTER
	stage_panel_label.add_color_override("font_color", Color("6d4a5e"))
	stage_panel_label.visible = false
	root.add_child(stage_panel_label)

	combo_burst_label = Label.new()
	combo_burst_label.add_font_override("font", game_font)
	combo_burst_label.align = Label.ALIGN_CENTER
	combo_burst_label.add_color_override("font_color", Color("e67700"))
	combo_burst_label.visible = false
	combo_burst_label.set_anchors_and_margins_preset(Control.PRESET_TOP_WIDE)
	combo_burst_label.margin_top = 88
	combo_burst_label.margin_left = 0
	combo_burst_label.margin_right = 0
	add_child(combo_burst_label)

	_populate_icon_set_options()
	_populate_level_select_options()
	_build_onboarding_panel()
	_build_settings_panel()
	_build_achievements_panel()
	_build_pause_panel()
	_build_modes_panel()
	call_deferred("_update_layout_for_screen_size")

func _build_onboarding_panel():
	UI_PANELS._onboarding_panel(self)

func _build_settings_panel():
	UI_PANELS._settings_panel(self)

func _build_achievements_panel():
	UI_PANELS._achievements_panel(self)

func _build_pause_panel():
	UI_PANELS._pause_panel(self)

func _build_modes_panel():
	UI_PANELS._modes_panel(self)

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

	memory_preview_timer = Timer.new()
	memory_preview_timer.one_shot = true
	memory_preview_timer.connect("timeout", self, "_on_memory_preview_timeout")
	add_child(memory_preview_timer)

	memory_hide_timer = Timer.new()
	memory_hide_timer.one_shot = true
	memory_hide_timer.connect("timeout", self, "_on_memory_hide_timeout")
	add_child(memory_hide_timer)

	race_timer = Timer.new()
	race_timer.wait_time = 1.0
	race_timer.one_shot = false
	race_timer.connect("timeout", self, "_on_race_tick")
	add_child(race_timer)

func _create_chip_label():
	var label = Label.new()
	label.add_font_override("font", game_font)
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

func _create_control_button(text):
	var button = Button.new()
	button.add_font_override("font", game_font)
	button.text = text
	button.rect_min_size = Vector2(88, 42)
	button.add_color_override("font_color", Color("ffffff"))

	# Apply gradient button style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("f06ba8")
	normal.set_corner_radius_all(20)
	normal.shadow_color = Color("f06ba840")
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color("ff9ec4")
	hover.set_corner_radius_all(20)
	hover.shadow_color = Color("f06ba860")
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 4)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color("d6336c")
	pressed.set_corner_radius_all(20)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.connect("pressed", AudioManager, "play_button_click")

	return button

func _add_stat_card(parent, title, key):
	STATS_HUD.add_card(self, parent, title, key)

func _create_power_up_label(power_up_id, icon, shortcut):
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 2)
	power_ups_container.add_child(hbox)

	var icon_label = Label.new()
	icon_label.text = icon
	hbox.add_child(icon_label)

	var count_label = Label.new()
	count_label.text = "x0"
	count_label.add_color_override("font_color", Color("8f6b80"))
	# 12px keeps all 8 slots on one 390px row when frost mode adds the 🔥.
	count_label.add_font_override("font", _font_at_size(12))
	hbox.add_child(count_label)

	var shortcut_label = Label.new()
	shortcut_label.text = "[" + shortcut + "]"
	shortcut_label.add_color_override("font_color", Color("c2a3b2"))
	# Keyboard-only affordance: pointless on touch phones, wastes width.
	shortcut_label.visible = not _viewport_flags(get_viewport_rect().size)["is_mobile"]
	hbox.add_child(shortcut_label)

	power_up_labels[power_up_id] = {
		"icon": icon_label,
		"count": count_label,
		"shortcut": shortcut_label,
		"box": hbox
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
	# Entering a campaign level always leaves any special session.
	special_mode = ""
	special_level = {}
	endless_round = 1
	level_index = clamp(next_index, 0, campaign_levels.size() - 1)
	var level = _current_level()
	_reset_level_session(level, reset_total)
	_patch_progress_state({"current_level_index": level_index})

	var level_id = int(level.get("id", level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	_show_message("进入第" + str(level_id) + "关：" + level_name + "（" + _mode_label(mode) + "） · 快捷键 H/A/S/P/F/R/[ ]/Enter", 1.35)

func _start_special_mode(mode_id):
	var config = game_mode_configs.get(mode_id, {})
	if not SPECIAL_MODES_SCRIPT.is_mode_unlocked(mode_id, config, int(progression_state.get("highest_unlocked_level_index", 0))):
		_show_message(SPECIAL_MODES_SCRIPT.unlock_requirement_text(mode_id, config), 1.8)
		return
	# Build the virtual level first; only touch session state once it exists.
	var level
	if mode_id == "daily":
		var today = SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
		seed(SPECIAL_MODES_SCRIPT.seed_for_day(today))
		level = SPECIAL_MODES_SCRIPT.build_daily_level(today)
	elif mode_id == "time_attack":
		level = SPECIAL_MODES_SCRIPT.build_time_attack_level(config)
	elif mode_id == "memory":
		var tier = SPECIAL_MODES_SCRIPT.memory_tier(config, int(progression_state.get("highest_unlocked_level_index", 0)) + 1)
		level = SPECIAL_MODES_SCRIPT.build_memory_level(config, tier)
	elif mode_id == "frost":
		var tier = SPECIAL_MODES_SCRIPT.frost_tier(config, int(progression_state.get("highest_unlocked_level_index", 0)) + 1)
		level = SPECIAL_MODES_SCRIPT.build_frost_level(config, tier)
	elif mode_id == "zen" or mode_id == "hell" or mode_id == "moves" or mode_id == "race" \
				or mode_id == "stack" or mode_id == "gravity" or mode_id == "fog" or mode_id == "chain":
		level = SPECIAL_MODES_SCRIPT.build_classic_style_level(config, mode_id)
	else:
		level = SPECIAL_MODES_SCRIPT.build_endless_level(config, 1)
	special_mode = mode_id
	endless_round = 1
	special_level = level
	_reset_level_session(level, true)
	print("[Game] special mode started: " + mode_id)
	if mode_id == "memory":
		_show_message("盲盒模式！记住 %d 秒预览，然后凭记忆配对" % int(ceil(float(level.get("memory_preview", 5.0)))), 2.0)
	else:
		var intro = {
			"daily": "每日挑战开始！今天的棋盘人人相同",
			"time_attack": "限时挑战！每次消除加时间，连击 5 触发狂热",
			"endless": "无尽模式第1轮！棋盘会越滚越大",
			"frost": "冰雪挑战！❄️ 结霜的方块要消除两次，🔥暖宝宝可以直接解冻",
			"zen": "休闲模式！没有时限，慢慢享受",
			"hell": "地狱模式！大盘少图案，时间极紧",
			"moves": "步数挑战！每消一对花 1 步，省着用",
			"race": "竞速对战！抢在机器人前面消完全部",
			"stack": "叠层模式！紫色边框的方块下面还压着一块",
			"gravity": "重力模式！消除后上方的方块会掉下来",
			"fog": "迷雾模式！边缘被雾住了，消除推进视野",
			"chain": "锁链模式！消除旁边的方块来解开灰锁"
		}
		_show_message(str(intro.get(mode_id, "特殊模式开始")), 1.8)

func _exit_special_mode():
	_start_level(level_index, false)
	_show_message("已返回关卡模式", 1.0)

func _reset_level_session(level, reset_total = false):
	board = _create_playable_board(level)
	board_armor = _build_frost_armor(board, level)
	board_lower = []
	board_chain = []
	_fog_layers = 0
	if _is_stack_mode():
		_build_stack_layers(float(level.get("stack_ratio", 0.25)))
	if _is_chain_mode():
		_build_chain_locks(float(level.get("chain_ratio", 0.22)))
	frost_pending = false
	frost_uses = 0
	bomb_pending = false
	rainbow_pending = false
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	path_overlay.clear_path()

	for child in effect_layer.get_children():
		child.queue_free()

	moves = 0
	level_score = 0
	time_left = int(level.get("time_limit", 90))
	moves_left = int(level.get("move_budget", 0))
	race_ai_pairs = 0
	race_elapsed = 0
	race_total_pairs = int(_remaining_tiles_count() / 2)
	if race_timer:
		if special_mode == "race":
			race_timer.start()
		else:
			race_timer.stop()
	stage_status = STATUS_PLAYING

	# Reset achievement tracking
	level_start_time = OS.get_ticks_msec()
	level_hints_used = 0
	level_auto_used = 0

	# Initialize power-ups based on level
	_init_power_ups(level)
	time_frozen = false

	# Reset memory-mode state
	memory_previewing = false
	memory_lock = false
	memory_revealed.clear()
	memory_pending_hide.clear()
	if memory_hide_timer:
		memory_hide_timer.stop()
	if memory_preview_timer:
		memory_preview_timer.stop()

	if reset_total:
		total_score = 0

	_reset_combo()
	_hide_message()
	pending_level_index = -1
	stage_panel_label.visible = false

	_render_board()
	_sync_level_select_selection()
	_refresh_ui()
	_refresh_board_visuals()
	if _is_memory_mode():
		_play_level_intro_animation(level)
		_start_memory_preview()
	else:
		_start_second_timer()
		_play_level_intro_animation(level)

func _current_level():
	if special_mode != "":
		return special_level
	return campaign_levels[level_index]

func _create_playable_board(level):
	return BOARD_ENGINE.create_playable_board(level, self, "_is_coord_playable")

func _create_board(rows, cols, kinds):
	return BOARD_ENGINE.create_board(rows, cols, kinds)

func _shuffle_array(arr):
	BOARD_ENGINE.shuffle_array(arr)

func _render_board():
	for child in board_grid.get_children():
		child.queue_free()
	cell_buttons.clear()

	if board.empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	board_grid.columns = cols

	for r in range(rows):
		var row_buttons = []
		for c in range(cols):
			var button = Button.new()
			button.text = ""
			button.rect_min_size = Vector2(52, 52)
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
	if board.empty() or cell_buttons.empty():
		return

	var rows = board.size()
	var cols = board[0].size()
	var h_sep = board_grid.get_constant("h_separation")
	var v_sep = board_grid.get_constant("v_separation")

	# Get available board area and keep a minimum usable size.
	var viewport_size = get_viewport_rect().size
	var flags = _viewport_flags(viewport_size)
	var is_mobile = flags["is_mobile"]
	var is_portrait = flags["is_portrait"]
	var is_compact_height = flags["is_compact_height"]
	var padding = 4 if is_mobile and is_compact_height else (6 if is_mobile and is_portrait else (10 if is_mobile else 24))
	var board_area = board_wrapper.rect_size
	if board_area.x <= 1 or board_area.y <= 1:
		board_area = board_wrapper.rect_min_size
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

	var tile_font = _font_at_size(int(clamp(float(tile) * 0.52, 14.0, 44.0)))
	for r in range(rows):
		for c in range(cols):
			var button = cell_buttons[r][c]
			button.rect_min_size = Vector2(tile, tile)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.add_font_override("font", tile_font)

func _refresh_board_visuals():
	if board.empty() or cell_buttons.empty():
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
				_apply_tile_style(button, Color("fff5f8"), Color("ffc2d4"), false)
				continue

			var face_down = _is_memory_mode() and not memory_previewing 				and not memory_revealed.has(_memory_key(Vector2(r, c))) 				and not (selected.x == r and selected.y == c)
			var bg = _color_for(value)
			var border = Color("ffffff")
			if face_down:
				button.text = "❓"
				bg = Color("ffc2d4")
				border = Color("f09ebb")
			else:
				button.text = _icon_for(value)
			button.disabled = not playing

			var is_selected = (selected.x == r and selected.y == c)
			var frozen = _is_frost_mode() and r < board_armor.size() \
					and c < board_armor[r].size() and int(board_armor[r][c]) > 0
			var fogged = _is_fogged(Vector2(r, c))
			var chained = _is_chain_mode() and r < board_chain.size() \
					and c < board_chain[r].size() and int(board_chain[r][c]) > 0
			var stacked = _is_stack_mode() and r < board_lower.size() \
					and c < board_lower[r].size() and int(board_lower[r][c]) > 0
			if frozen:
				# Ice sheet: cool white-blue face with a frost border.
				bg = bg.linear_interpolate(Color("e7f5ff"), 0.72)
				border = Color("a5d8ff")
			var has_effect = false

			if _contains_coord(error_tiles, Vector2(r, c)):
				bg = Color("ffe3e3")
				border = Color("ff8787")
				has_effect = true
			elif _contains_coord(hint_tiles, Vector2(r, c)):
				bg = Color("d0ebff")
				border = Color("3b82f6")
				has_effect = true
			elif frozen:
				has_effect = true
			elif fogged:
				# Fog hides the icon entirely until the rings recede.
				button.text = "❓"
				bg = Color("e9ecef")
				border = Color("adb5bd")
			elif chained:
				border = Color("868e96")
				bg = bg.linear_interpolate(Color("e9ecef"), 0.35)
				has_effect = true
			elif stacked:
				border = Color("9775fa")
				has_effect = true
			elif bomb_pending:
				# Armed bomb: warm glow on every tile invites the pick.
				bg = bg.linear_interpolate(Color("fff3bf"), 0.45)
				border = Color("ffd43b")
				has_effect = true
			elif rainbow_pending:
				# Armed rainbow: violet shimmer while choosing two tiles.
				bg = bg.linear_interpolate(Color("f3d9fa"), 0.4)
				border = Color("da77f2")
				has_effect = true

			if is_selected:
				border = Color("ff8fab")
				has_effect = true

			_apply_tile_style(button, bg, border, has_effect or is_selected)
			# Cool tint sells the frost at a glance, even on tiny tiles.
			button.modulate = Color(0.86, 0.95, 1.1) if frozen else Color(1, 1, 1)

func _apply_tile_style(button, bg_color, border_color, highlight):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)

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
	style.border_color = Color("ffd9e8")
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
	pressed.set_corner_radius_all(16)

	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("pressed", pressed)
	button.add_stylebox_override("focus", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("disabled", normal)

func _style_dialog_buttons(node):
	# Dialog buttons join the rose palette instead of the default gray.
	if node is Button:
		_apply_button_style(node, Color("f06ba8"), Color("d6336c"))
		node.add_color_override("font_color", Color("ffffff"))
		node.add_color_override("font_hover_color", Color("ffffff"))
		node.add_color_override("font_pressed_color", Color("ffffff"))
		node.add_color_override("font_focus_color", Color("ffffff"))
	for child in node.get_children():
		_style_dialog_buttons(child)

func _icon_for(value):
	if icon_sets.empty():
		return str(value)

	var icon_set: Dictionary = icon_sets[icon_set_index]
	var icons: Array = icon_set.get("icons", [])
	var index = value - 1
	if index >= 0 and index < icons.size():
		return str(icons[index])
	return str(value)

func _color_for(value):
	if icon_sets.empty():
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


func _is_memory_mode():
	return special_mode == "memory"

func _is_frost_mode():
	return special_mode == "frost"

func _is_stack_mode():
	return special_mode == "stack"

func _is_gravity_mode():
	return special_mode == "gravity"

func _is_fog_mode():
	return special_mode == "fog"

func _is_chain_mode():
	return special_mode == "chain"

func _cell_ring(r, c):
	var rows = board.size()
	var cols = board[0].size()
	return BOARD_ENGINE.ring_of(rows, cols, r, c)

func _is_fogged(coord):
	if not _is_fog_mode():
		return false
	return _cell_ring(coord.x, coord.y) < _fog_layers

# 迷雾/锁链 make a tile unselectable; clicks, hints and auto tools skip it.
func _is_coord_playable(coord):
	if _is_fogged(coord):
		return false
	if _is_chain_mode() and coord.x < board_chain.size() and coord.y < board_chain[coord.x].size() \
				and int(board_chain[coord.x][coord.y]) > 0:
		return false
	return true

func _build_frost_armor(new_board, level):
	# Frost levels stamp a ratio of occupied cells as frozen. Ice binds to
	# the position (tiles reshuffle beneath the ice sheet), so it is a plain
	# parallel grid; other modes get all-zero armor.
	var armor = []
	for r in range(new_board.size()):
		var row = []
		for c in range(new_board[r].size()):
			row.append(0)
		armor.append(row)
	var ratio = float(level.get("frost_ratio", 0.0))
	if ratio <= 0.0:
		return armor
	var cells = []
	for r in range(new_board.size()):
		for c in range(new_board[r].size()):
			if int(new_board[r][c]) != 0:
				cells.append(Vector2(r, c))
	cells.shuffle()
	var target = clamp(int(round(cells.size() * ratio)), 0, cells.size())
	for i in range(target):
		var cell = cells[i]
		armor[cell.x][cell.y] = 1
	return armor

func _memory_key(coord):
	return str(int(coord.x)) + "," + str(int(coord.y))

func _start_memory_preview():
	memory_previewing = true
	memory_lock = true
	memory_revealed.clear()
	second_timer.stop()
	_refresh_board_visuals()
	var preview = float(special_level.get("memory_preview", 5.0))
	_show_message("记住所有图案！%d 秒后翻面" % int(ceil(preview)), 2.0)
	memory_preview_timer.wait_time = max(1.0, preview)
	memory_preview_timer.start()

func _on_memory_preview_timeout():
	memory_previewing = false
	memory_lock = false
	_refresh_board_visuals()
	_show_message("翻面！凭记忆消除吧", 1.2)
	if stage_status == STATUS_PLAYING:
		second_timer.start()

func _memory_schedule_hide(coords, delay):
	memory_pending_hide = coords.duplicate()
	memory_lock = true
	memory_hide_timer.stop()
	memory_hide_timer.wait_time = max(0.2, delay)
	memory_hide_timer.start()

func _on_memory_hide_timeout():
	for coord in memory_pending_hide:
		memory_revealed.erase(_memory_key(coord))
	memory_pending_hide.clear()
	memory_lock = false
	_refresh_board_visuals()

func _on_memory_tile_pressed(point, r, c):
	if memory_previewing or memory_lock:
		return
	if selected.x < 0:
		selected = point
		memory_revealed[_memory_key(point)] = true
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
	var target_value = int(board[r][c])

	if selected_value != target_value:
		# Reveal both briefly so the player learns the positions, then hide.
		selected = Vector2(-1, -1)
		memory_revealed[_memory_key(previous)] = true
		memory_revealed[_memory_key(point)] = true
		hint_tiles.clear()
		AudioManager.play_error()
		_flash_error_tiles([previous, point])
		_show_message("不一样，记住位置", 0.8)
		_memory_schedule_hide([previous, point], float(special_level.get("memory_face_up", 1.0)))
		_refresh_ui()
		_refresh_board_visuals()
		return

	var path = _find_path(board, previous, point)
	if path.empty():
		selected = point
		memory_revealed[_memory_key(point)] = true
		hint_tiles.clear()
		AudioManager.play_error()
		_flash_error_tiles([previous, point])
		_show_message("路径不通：最多只能拐2次弯", 0.9)
		_refresh_board_visuals()
		return

	var a = previous
	var b = point
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	memory_revealed.erase(_memory_key(a))
	memory_revealed.erase(_memory_key(b))

	AudioManager.play_eliminate_combo(combo)
	var score_result = _apply_combo_gain(int(tuning.get("base_score", 10)))
	if score_result["combo"] > 1:
		_show_message("连击 x" + str(score_result["combo"]) + " +" + str(score_result["gain"]), 0.88)
		_show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	_show_path(path, "eliminate", int(tuning.get("path_preview_ms", 420)))
	_play_eliminate_effects([a, b])

	_apply_match_damage(a, b)
	_consume_move()

	_refresh_ui()
	_refresh_board_visuals()
	_resolve_after_board_changed()

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

	if not _is_coord_playable(point):
		if _is_fogged(point):
			_show_message("迷雾遮住了这块，先消除里面的方块", 1.0)
		else:
			_show_message("⛓️ 先消除它旁边的方块来解锁", 1.0)
		return

	# Armed click-targeted power-ups take over the next board click.
	if frost_pending:
		_execute_warm_patch(point)
		return
	if bomb_pending:
		_execute_bomb(point)
		return
	if rainbow_pending:
		_execute_rainbow_click(point)
		return

	if _is_memory_mode():
		_on_memory_tile_pressed(point, r, c)
		return

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
	if path.empty():
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

	_apply_match_damage(a, b)
	_consume_move()

	_refresh_ui()
	_refresh_board_visuals()
	_resolve_after_board_changed()


func _on_hint_pressed():
	if stage_status != STATUS_PLAYING:
		return

	level_hints_used += 1
	AudioManager.play_hint()

	var hint = _find_any_hint(board)
	if hint.empty():
		_on_shuffle_pressed()
		return

	if _is_memory_mode():
		memory_revealed[_memory_key(hint["a"])] = true
		memory_revealed[_memory_key(hint["b"])] = true
		hint_tiles = [hint["a"], hint["b"]]
		error_tiles.clear()
		var mem_path: Array = hint["path"]
		_show_path(mem_path, "hint", int(tuning.get("hint_preview_ms", 1400)))
		_animate_hint_tiles(hint_tiles)
		_show_message("已翻开一组可消除方块", 1.1)
		_memory_schedule_hide([hint["a"], hint["b"]], float(special_level.get("memory_face_up", 1.0)) * 1.5)
		_refresh_ui()
		_refresh_board_visuals()
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
	if hint.empty():
		_on_shuffle_pressed()
		return

	var a = hint["a"]
	var b = hint["b"]
	var hint_path: Array = hint["path"]

	var cracked = []
	var removed = []
	_damage_tile(a, cracked, removed)
	_damage_tile(b, cracked, removed)
	_break_chains_around(removed)
	# Frozen tiles survive as blockers, so judge the clear AFTER the damage.
	var will_clear = _remaining_tiles_count() == 0
	_consume_move()

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
		combo_expires_ms = OS.get_ticks_msec() + int(tuning.get("combo_window_ms", 2600))
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
	if special_mode != "":
		_start_special_mode(special_mode)
		return
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
		color = Color("e64980")  # Purple
		particle_color = Color("e64980")
		particle_count = int(24 * effect_intensity)
	elif combo >= 5:
		color = Color("e64980")  # Blue
		particle_color = Color("60a5fa")
		particle_count = int(18 * effect_intensity)
	elif combo >= 3:
		color = Color("0ca678")  # Green
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
		star.rect_position = center
		star.rect_pivot_offset = Vector2(8, 8)
		star.rect_scale = Vector2.ONE
		star.modulate = color
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(star)

		# Tween animation for star effect
		var tween = Tween.new()
		add_child(tween)
		tween.interpolate_property(star, "rect_position", star.rect_position, star.rect_position + Vector2(0, -18 * effect_intensity), 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.interpolate_property(star, "modulate:a", 1.0, 0.0, 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.interpolate_property(star, "rect_scale", Vector2.ONE, Vector2.ONE * (1.35 * effect_intensity), 0.28, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.start()
		tween.connect("tween_all_completed", star, "queue_free")
		tween.connect("tween_all_completed", tween, "queue_free")


func _animate_select(coord):
	var button = _try_get_tile_button(coord)
	if button == null:
		return

	button.rect_pivot_offset = button.rect_size * 0.5
	# Tween animation for select effect
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(button, "rect_scale", button.rect_scale, Vector2(1.08, 1.08), 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.interpolate_property(button, "rect_scale", button.rect_scale, Vector2.ONE, 0.12, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.queue_free()

	var center = _tile_center_in_effect_layer(coord)
	_spawn_ring_effect(center, Color("ff6f9c"), 0.18, 12.0)

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
	return effect_layer.get_global_transform().affine_inverse() * (button.rect_global_position + button.rect_size * 0.5)

func _pulse_tile(coord, peak_scale, half_duration, loops = 1):
	var button = _try_get_tile_button(coord)
	if button == null:
		return
	button.rect_pivot_offset = button.rect_size * 0.5

	# Tween animation for pulse effect
	for _i in range(max(1, loops)):
		var tween1 = Tween.new()
		add_child(tween1)
		tween1.interpolate_property(button, "rect_scale", button.rect_scale, Vector2.ONE * peak_scale, half_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween1.start()
		yield(tween1, "tween_completed")
		tween1.queue_free()
		
		var tween2 = Tween.new()
		add_child(tween2)
		tween2.interpolate_property(button, "rect_scale", button.rect_scale, Vector2.ONE, half_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween2.start()
		yield(tween2, "tween_completed")
		tween2.queue_free()

func _make_fx_tween(node_to_free = null):
	var tween = Tween.new()
	add_child(tween)
	if node_to_free != null:
		tween.connect("tween_all_completed", node_to_free, "queue_free")
	tween.connect("tween_all_completed", tween, "queue_free")
	return tween

func _shake_tile(coord):
	var button = _try_get_tile_button(coord)
	if button == null:
		return
	button.rect_pivot_offset = button.rect_size * 0.5
	button.rect_scale = Vector2(1.04, 1.04)

	var tween = _make_fx_tween()
	tween.interpolate_property(button, "rect_rotation", 0.0, -6.0, 0.04, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.0)
	tween.interpolate_property(button, "rect_rotation", -6.0, 6.0, 0.06, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.04)
	tween.interpolate_property(button, "rect_rotation", 6.0, -4.0, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.10)
	tween.interpolate_property(button, "rect_rotation", -4.0, 0.0, 0.06, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.15)
	tween.interpolate_property(button, "rect_scale", Vector2(1.04, 1.04), Vector2.ONE, 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.15)
	tween.start()

func _animate_hint_tiles(coords):
	for coord in coords:
		_pulse_tile(coord, 1.09, 0.08, 2)
		var center = _tile_center_in_effect_layer(coord)
		_spawn_ring_effect(center, Color("74c0fc"), 0.26, 12.0)

func _animate_shuffle_wave():
	if board.empty():
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

			button.rect_pivot_offset = button.rect_size * 0.5
			var delay = float(r + c) * 0.012 + rand_range(0.0, 0.03)

			var tween = _make_fx_tween()
			tween.interpolate_property(button, "rect_scale", Vector2.ONE, Vector2(0.82, 0.82), 0.07, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
			tween.interpolate_property(button, "rect_scale", Vector2(0.82, 0.82), Vector2(1.08, 1.08), 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay + 0.07)
			tween.interpolate_property(button, "rect_scale", Vector2(1.08, 1.08), Vector2.ONE, 0.08, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay + 0.15)
			tween.start()

func _spawn_ring_effect(center, color, duration, base_size):
	if center == Vector2.ZERO:
		return

	var ring = Panel.new()
	ring.rect_size = Vector2.ONE * base_size
	ring.rect_position = center - ring.rect_size * 0.5
	ring.rect_pivot_offset = ring.rect_size * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(base_size * 0.5))
	ring.add_stylebox_override("panel", style)
	effect_layer.add_child(ring)

	var tween = _make_fx_tween(ring)
	tween.interpolate_property(ring, "rect_scale", Vector2.ONE, Vector2(1.9, 1.9), duration, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(ring, "modulate:a", 1.0, 0.0, duration, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()

func _spawn_particle_burst(center, color, particle_count, intensity):
	var count = int(max(4, particle_count))
	for _i in range(count):
		var particle = Label.new()
		particle.text = "•"
		particle.add_font_override("font", game_font)
		particle.rect_position = center
		particle.modulate = color
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(particle)

		var angle = rand_range(0.0, TAU)
		var distance = rand_range(16.0, 44.0) * intensity
		var target = center + Vector2(cos(angle), sin(angle)) * distance

		var tween = _make_fx_tween(particle)
		tween.interpolate_property(particle, "rect_position", center, target, 0.3, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(particle, "modulate:a", 1.0, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN)
		tween.start()

func _spawn_combo_particle_burst(center, color, particle_count, combo_level):
	var count = int(max(8, particle_count))
	var shapes = ["•", "✦", "★", "◆"]
	var shape_index = int(min(combo_level / 3, shapes.size() - 1))

	for _i in range(count):
		var particle = Label.new()
		particle.text = shapes[shape_index]
		particle.add_font_override("font", game_font)
		particle.rect_position = center
		particle.modulate = color
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(particle)

		var angle = rand_range(0.0, TAU)
		var distance = rand_range(20.0, 60.0 + combo_level * 3.0)
		var target = center + Vector2(cos(angle), sin(angle)) * distance

		var tween = _make_fx_tween(particle)
		tween.interpolate_property(particle, "rect_position", center, target, 0.4, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(particle, "modulate:a", 1.0, 0.0, 0.4, Tween.TRANS_LINEAR, Tween.EASE_IN)
		if combo_level >= 7:
			tween.interpolate_property(particle, "rect_rotation", 0.0, rand_range(-180.0, 180.0), 0.4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.start()

func _spawn_board_particles(count, color, intensity):
	var area = effect_layer.rect_size
	if area.x <= 0 or area.y <= 0:
		return

	for _i in range(count):
		var sparkle = Label.new()
		sparkle.text = "✦"
		sparkle.add_font_override("font", game_font)
		sparkle.rect_position = Vector2(
			rand_range(16.0, max(16.0, area.x - 16.0)),
			rand_range(24.0, max(24.0, area.y - 16.0))
		)
		sparkle.modulate = color
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_layer.add_child(sparkle)

		var drift = Vector2(rand_range(-32.0, 32.0), rand_range(-84.0, -28.0)) * intensity
		var tween = _make_fx_tween(sparkle)
		tween.interpolate_property(sparkle, "rect_position", sparkle.rect_position, sparkle.rect_position + drift, 0.52, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(sparkle, "modulate:a", 1.0, 0.0, 0.52, Tween.TRANS_LINEAR, Tween.EASE_IN)
		tween.start()

func _show_stage_callout(text, color, font_size):
	var label = Label.new()
	label.text = text
	label.add_font_override("font", _font_at_size(font_size))
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.set_anchors_and_margins_preset(Control.PRESET_TOP_WIDE)
	label.margin_top = 150
	label.margin_left = 0
	label.margin_right = 0
	label.margin_bottom = 190
	label.modulate = Color(1, 1, 1, 0.0)
	label.add_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tween = _make_fx_tween(label)
	tween.interpolate_property(label, "margin_top", 150.0, 116.0, 0.35, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(label, "modulate:a", 0.0, 0.95, 0.2, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(label, "modulate:a", 0.95, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.1)
	tween.start()

func _play_level_intro_animation(level):
	if special_mode == "daily":
		var d = OS.get_date()
		_show_stage_callout("每日挑战 · %d月%d日" % [int(d.month), int(d.day)], Color("9775fa"), 19)
	elif special_mode == "endless":
		_show_stage_callout("无尽模式 · 第%d轮" % endless_round, Color("0ca678"), 19)
	elif special_mode == "time_attack":
		_show_stage_callout("限时挑战", Color("f06565"), 19)
	elif special_mode == "memory":
		_show_stage_callout("盲盒模式", Color("3bc9db"), 19)
	elif special_mode == "frost":
		_show_stage_callout("冰雪挑战 · %d%% 方块结了冰" % int(round(float(level.get("frost_ratio", 0.3)) * 100)), Color("4dabf7"), 19)
	else:
		var level_id = int(level.get("id", level_index + 1))
		var level_name = str(level.get("name", "关卡"))
		_show_stage_callout("第" + str(level_id) + "关 · " + level_name, Color("e64980"), 19)
	_animate_board_spawn()

func _animate_board_spawn():
	if board.empty():
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

			button.rect_pivot_offset = button.rect_size * 0.5
			button.rect_scale = Vector2(0.72, 0.72)
			button.modulate.a = 0.0

			var dist = abs(float(r) - center_r) + abs(float(c) - center_c)
			var delay = dist * 0.025
			var tween = _make_fx_tween()
			tween.interpolate_property(button, "modulate:a", 0.0, 1.0, 0.09, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
			tween.interpolate_property(button, "rect_scale", Vector2(0.72, 0.72), Vector2.ONE, 0.09, Tween.TRANS_BACK, Tween.EASE_OUT, delay)
			tween.start()

const FX = preload("res://scripts/fx_layer.gd")

func _build_petals():
	FX.build_petals(self)

func _on_petal_tick():
	FX.petal_tick(self)

func _spawn_petal(start_mid_fall):
	FX.spawn_petal(self, start_mid_fall)

func _spawn_confetti(count):
	FX.spawn_confetti(self, count)

func _play_stage_clear_celebration(is_final_clear):
	var burst_color = Color("ff8fab") if is_final_clear else Color("22c55e")
	var text = "全部通关!" if is_final_clear else "过关!"
	var particle_count = 28 if is_final_clear else 16
	var intensity = 1.2 if is_final_clear else 1.0

	_show_stage_callout(text, burst_color, 24 if is_final_clear else 21)
	_spawn_board_particles(particle_count, burst_color, intensity)
	_spawn_confetti(36 if is_final_clear else 22)

func _show_combo_burst(text):
	# Enhanced combo burst with dynamic styling based on combo level
	var combo_num = combo
	var color = Color("e67700")  # Default amber
	var font_size = 18

	if combo_num >= 10:
		color = Color("f06565")
		font_size = 28
	elif combo_num >= 7:
		color = Color("e64980")
		font_size = 24
	elif combo_num >= 5:
		color = Color("e64980")
		font_size = 22
	elif combo_num >= 3:
		color = Color("0ca678")
		font_size = 20

	combo_burst_label.add_font_override("font", _font_at_size(font_size))
	combo_burst_label.text = text
	combo_burst_label.visible = true
	combo_burst_label.modulate = Color(1, 1, 1, 1)
	combo_burst_label.margin_top = 88
	combo_burst_label.add_color_override("font_color", color)

	var tween = _make_fx_tween()
	tween.interpolate_property(combo_burst_label, "margin_top", 88.0, 68.0, 0.22, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(combo_burst_label, "modulate:a", 1.0, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.6)
	tween.start()

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
	if cell_buttons.empty():
		return result
	if cell_buttons[0].empty():
		return result

	var first_button = cell_buttons[0][0]
	# Control has no to_local(); map the global tile center through the
	# overlay's inverse transform instead.
	var overlay_inv = path_overlay.get_global_transform().affine_inverse()
	var first_center = overlay_inv * (first_button.rect_global_position + first_button.rect_size * 0.5)
	var step_x = first_button.rect_size.x + board_grid.get_constant("h_separation")
	var step_y = first_button.rect_size.y + board_grid.get_constant("v_separation")

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
		_spawn_ring_effect(center, Color("ff8787"), 0.22, 12.0)

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
	power_ups = {"time_freeze": 0, "auto_match": 0, "reshuffle": 0, "magnifier": 0, "time_sand": 0, "bomb": 0, "rainbow": 0, "warm_patch": 0}
	bomb_pending = false
	rainbow_pending = false
	frost_pending = false
	frost_uses = 0

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
	if level_id >= 6:
		power_ups["magnifier"] = 1
	if level_id >= 8:
		power_ups["time_sand"] = 1
	if level_id >= 10:
		power_ups["bomb"] = 1
	if level_id >= 12:
		power_ups["rainbow"] = 1
	if mode == "rush":
		power_ups["time_freeze"] += 1
	if mode == "endurance":
		power_ups["reshuffle"] += 1

	# Special sessions get a friendly fixed loadout.
	if special_mode != "":
		power_ups["time_freeze"] = 2
		power_ups["reshuffle"] = 2
		power_ups["auto_match"] = 1
		power_ups["magnifier"] = 1 if special_mode == "memory" else 0
		power_ups["time_sand"] = 1 if special_mode == "time_attack" else 0
		power_ups["bomb"] = 1
		power_ups["rainbow"] = 1
		power_ups["warm_patch"] = 3 if special_mode == "frost" else 0
	if special_mode == "hell":
		# 地狱: strip back to the bare basics.
		power_ups["time_freeze"] = 1
		power_ups["reshuffle"] = 1
		power_ups["auto_match"] = 0
		power_ups["magnifier"] = 0
		power_ups["time_sand"] = 0
		power_ups["bomb"] = 0
		power_ups["rainbow"] = 0
		power_ups["warm_patch"] = 0

func _use_power_up(power_up_type):
	# Re-press cancels an armed click-targeted power-up and refunds the
	# charge: nothing is spent until the bomb/rainbow/patch actually lands.
	if power_up_type == "bomb" and bomb_pending:
		bomb_pending = false
		power_ups["bomb"] += 1
		_show_message("已收回炸弹", 0.8)
		_refresh_ui()
		_refresh_board_visuals()
		return
	if power_up_type == "rainbow" and rainbow_pending:
		rainbow_pending = false
		selected = Vector2(-1, -1)
		power_ups["rainbow"] += 1
		_show_message("已收回彩虹", 0.8)
		_refresh_ui()
		_refresh_board_visuals()
		return
	if power_up_type == "warm_patch" and frost_pending:
		frost_pending = false
		power_ups["warm_patch"] += 1
		_show_message("已收回暖宝宝", 0.8)
		_refresh_ui()
		_refresh_board_visuals()
		return
	if power_ups.get(power_up_type, 0) <= 0:
		return
	if stage_status != STATUS_PLAYING:
		return
	if power_up_type == "time_sand" and special_mode == "endless":
		_show_message("无尽模式没有时间限制", 1.0)
		return
	if power_up_type == "warm_patch" and not _is_frost_mode():
		_show_message("暖宝宝只有冰雪模式用得上", 1.0)
		return

	match power_up_type:
		"time_freeze":
			_activate_time_freeze()
		"auto_match":
			_activate_auto_match()
		"reshuffle":
			_activate_reshuffle()
		"magnifier":
			_activate_magnifier()
		"time_sand":
			_activate_time_sand()
		"bomb":
			_activate_bomb()
		"rainbow":
			_activate_rainbow()
		"warm_patch":
			_activate_warm_patch()

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
	if hint.empty():
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

func _activate_magnifier():
	# Highlight up to 3 connectable pairs; in memory mode they also flip over.
	var working = []
	for row in board:
		working.append(row.duplicate())
	var coords = []
	for _i in range(3):
		var hint = _find_any_hint(working)
		if hint.empty():
			break
		coords.append(hint["a"])
		coords.append(hint["b"])
		working[hint["a"].x][hint["a"].y] = 0
		working[hint["b"].x][hint["b"].y] = 0
	if coords.empty():
		_show_message("没有可以高亮的对子", 1.0)
		return
	hint_tiles = coords
	for coord in coords:
		if _is_memory_mode():
			memory_revealed[_memory_key(coord)] = true
	_animate_hint_tiles(coords)
	_show_message("🔍 放大镜：高亮 %d 组可消对子" % int(coords.size() / 2.0), 1.4)
	_refresh_board_visuals()

func _activate_time_sand():
	time_left = min(999, time_left + 15)
	_show_message("⏳ 时光沙漏：时间 +15 秒", 1.4)
	_refresh_ui()

func _activate_bomb():
	bomb_pending = true
	rainbow_pending = false
	frost_pending = false
	selected = Vector2(-1, -1)
	_show_message("💥 炸弹已就绪：点击任意方块，与它的同伴一起消失", 2.6)
	_refresh_board_visuals()

func _activate_rainbow():
	rainbow_pending = true
	bomb_pending = false
	frost_pending = false
	selected = Vector2(-1, -1)
	_show_message("🌈 彩虹已就绪：点击两枚方块，图案不同也能消除", 2.6)
	_refresh_board_visuals()

func _activate_warm_patch():
	frost_pending = true
	bomb_pending = false
	rainbow_pending = false
	selected = Vector2(-1, -1)
	_show_message("🔥 暖宝宝已就绪：点一块结霜的方块解冻", 2.6)
	_refresh_board_visuals()

func _execute_warm_patch(point):
	# Not-ice target: stay armed so the charge isn't wasted on a misclick.
	if int(board_armor[point.x][point.y]) <= 0:
		_show_message("这块没有结冰，选一块淡蓝色的冰", 1.3)
		return
	frost_pending = false
	frost_uses += 1
	board_armor[point.x][point.y] = 0
	AudioManager.play_hint()
	_play_eliminate_effects([point])
	_show_message("🔥 冰融化了！", 1.1)
	_refresh_ui()
	_refresh_board_visuals()

# One successful match hits both tiles. Frozen cells (armor 1) crack instead
# of clearing and need a second match; cracked tiles keep blocking paths.
# 步数挑战: every removed pair costs one move; running dry loses.
func _consume_move():
	if special_mode != "moves" or stage_status != STATUS_PLAYING:
		return
	moves_left = max(0, moves_left - 1)
	_refresh_ui()
	if moves_left <= 0 and _remaining_tiles_count() > 0:
		_fail_moves_exhausted()

func _fail_moves_exhausted():
	if stage_status != STATUS_PLAYING:
		return
	stage_status = STATUS_FAILED
	AudioManager.play_fail()
	_reset_combo()
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	second_timer.stop()
	stage_panel_label.text = "步数用完了！还剩 %d 对没消除\n点击「重开」再战，或「暂停」后返回玩法" % int(_remaining_tiles_count() / 2)
	stage_panel_label.visible = true
	_show_message("步数耗尽，挑战失败", 1.8)
	_refresh_ui()
	_refresh_board_visuals()

# 竞速对战: the AI clears one pair per ai_interval seconds.
func _on_race_tick():
	if special_mode != "race" or stage_status != STATUS_PLAYING:
		return
	var interval = max(1.0, float(_current_level().get("ai_interval", 8.5)))
	race_elapsed += 1
	if race_elapsed < int(interval):
		return
	race_elapsed = 0
	race_ai_pairs = min(race_total_pairs, race_ai_pairs + 1)
	AudioManager.play_select()
	_refresh_ui()
	if race_ai_pairs >= race_total_pairs:
		_fail_race_lost()

func _fail_race_lost():
	if stage_status != STATUS_PLAYING:
		return
	stage_status = STATUS_FAILED
	AudioManager.play_fail()
	_reset_combo()
	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	second_timer.stop()
	if race_timer:
		race_timer.stop()
	stage_panel_label.text = "对手先完成了！你消除了 %d/%d 对\n点击「重开」再战" % [race_total_pairs - int(_remaining_tiles_count() / 2), race_total_pairs]
	stage_panel_label.visible = true
	_show_message("惜败！再快一点点", 1.8)
	_refresh_ui()
	_refresh_board_visuals()

# 叠层: lift a share of tiles onto a visible cover with a buried twin.
func _build_stack_layers(ratio):
	board_lower = []
	for r in range(board.size()):
		var row = []
		for c in range(board[r].size()):
			row.append(0)
		board_lower.append(row)
	var filled = []
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) != 0:
				filled.append(Vector2(r, c))
	filled.shuffle()
	var target = clamp(int(round(filled.size() * ratio)), 0, int(filled.size() / 2))
	var used = {}
	var i = 0
	var covered = 0
	while covered < target and i < filled.size():
		var cover_cell = filled[i]
		i += 1
		if used.has(cover_cell):
			continue
		var donor = Vector2(-1, -1)
		for j in range(i, filled.size()):
			var cand = filled[j]
			if cand != cover_cell and not used.has(cand):
				donor = cand
				break
		if donor.x < 0:
			break
		board_lower[cover_cell.x][cover_cell.y] = int(board[cover_cell.x][cover_cell.y])
		board[cover_cell.x][cover_cell.y] = int(board[donor.x][donor.y])
		board[donor.x][donor.y] = 0
		used[cover_cell] = true
		used[donor] = true
		covered += 1

# 锁链: chain a share of tiles; adjacent clears break the chains.
func _build_chain_locks(ratio):
	board_chain = []
	for r in range(board.size()):
		var row = []
		for c in range(board[r].size()):
			row.append(0)
		board_chain.append(row)
	var filled = []
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) != 0:
				filled.append(Vector2(r, c))
	filled.shuffle()
	var target = clamp(int(round(filled.size() * ratio)), 0, filled.size())
	for i in range(target):
		var cell = filled[i]
		board_chain[cell.x][cell.y] = 1

func _chains_remaining():
	var count = 0
	for row in board_chain:
		for value in row:
			count += int(value != 0)
	return count

func _dissolve_all_chains():
	for r in range(board_chain.size()):
		for c in range(board_chain[r].size()):
			board_chain[r][c] = 0
	_show_message("⛓️ 死局解除，锁链全部崩解！", 1.4)
	_refresh_board_visuals()

func _break_chains_around(coords):
	if not _is_chain_mode() or coords == null:
		return
	var broke = false
	for coord in coords:
		for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			var n = coord + dir
			if n.x < 0 or n.y < 0 or n.x >= board.size() or n.y >= board[0].size():
				continue
			if int(board_chain[n.x][n.y]) > 0:
				board_chain[n.x][n.y] = int(board_chain[n.x][n.y]) - 1
				broke = true
	if broke:
		_show_message("⛓️ 邻近的锁链松开了", 0.9)

# 重力: columns compact downward after clears.
func _apply_gravity():
	var moved = BOARD_ENGINE.compact_columns(board)
	if moved:
		selected = Vector2(-1, -1)
		hint_tiles.clear()
		error_tiles.clear()
	return moved

func _update_fog():
	if not _is_fog_mode():
		_fog_layers = 0
		return
	var max_layers = int(_current_level().get("fog_layers", 2))
	_fog_layers = clamp(int(_remaining_tiles_count() / 2 / 12), 0, max_layers)

func _pop_stack_at(coord):
	if not _is_stack_mode() or coord.x >= board_lower.size() or coord.y >= board_lower[coord.x].size():
		return
	if int(board_lower[coord.x][coord.y]) != 0:
		board[coord.x][coord.y] = int(board_lower[coord.x][coord.y])
		board_lower[coord.x][coord.y] = 0

# One successful match hits both tiles. Frozen cells (armor 1) crack instead
# of clearing and need a second match; cracked tiles keep blocking paths.
func _apply_match_damage(a, b):
	var cracked = []
	var removed = []
	_damage_tile(a, cracked, removed)
	_damage_tile(b, cracked, removed)
	_break_chains_around(removed)
	if cracked.size() > 0:
		AudioManager.play_shuffle()
		_show_message("❄️ 冰层碎裂！再消一次", 1.0)
	return cracked

func _damage_tile(coord, cracked, removed = null):
	if _is_frost_mode() and coord.x < board_armor.size() and coord.y < board_armor[coord.x].size() \
			and int(board_armor[coord.x][coord.y]) > 0:
		board_armor[coord.x][coord.y] = int(board_armor[coord.x][coord.y]) - 1
		cracked.append(coord)
		return
	board[coord.x][coord.y] = 0
	if removed != null:
		removed.append(coord)
	_pop_stack_at(coord)

func _execute_bomb(point):
	if not _is_coord_playable(point):
		_show_message("这块消不掉，先解锁/驱雾再炸", 1.2)
		return
	var kind = int(board[point.x][point.y])
	var partner = Vector2(-1, -1)
	for r in range(board.size()):
		for c in range(board[r].size()):
			if int(board[r][c]) == kind and not (r == point.x and c == point.y):
				partner = Vector2(r, c)
				break
		if partner.x >= 0:
			break
	bomb_pending = false
	if partner.x < 0:
		power_ups["bomb"] += 1
		_show_message("没有可配对的方块，炸弹已退回", 1.2)
		return

	selected = Vector2(-1, -1)
	hint_tiles.clear()
	error_tiles.clear()
	moves += 1

	AudioManager.play_shuffle()
	_show_path(_board_edge_path(point, partner), "eliminate", int(tuning.get("path_preview_ms", 420)))
	_play_eliminate_effects([point, partner])
	_show_message("💥 轰！", 0.8)

	var score_result = _apply_combo_gain(int(tuning.get("base_score", 10)))
	if score_result["combo"] > 1:
		_show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	# Explosions shatter ice along with the tile.
	board[point.x][point.y] = 0
	board[partner.x][partner.y] = 0
	if _is_frost_mode():
		board_armor[point.x][point.y] = 0
		board_armor[partner.x][partner.y] = 0
	_pop_stack_at(point)
	_pop_stack_at(partner)
	_break_chains_around([point, partner])
	_consume_move()

	_refresh_ui()
	_refresh_board_visuals()
	_resolve_after_board_changed()

func _execute_rainbow_click(point):
	if not _is_coord_playable(point):
		_show_message("这块消不掉，先解锁/驱雾再选", 1.2)
		return
	if selected.x < 0:
		selected = point
		hint_tiles.clear()
		AudioManager.play_select()
		_animate_select(point)
		_refresh_board_visuals()
		return
	if selected == point:
		selected = Vector2(-1, -1)
		_refresh_board_visuals()
		return

	var a = selected
	var b = point
	selected = Vector2(-1, -1)
	rainbow_pending = false
	hint_tiles.clear()
	error_tiles.clear()
	moves += 1

	AudioManager.play_eliminate_combo(combo)
	_show_path(_board_edge_path(a, b), "eliminate", int(tuning.get("path_preview_ms", 420)))
	_play_eliminate_effects([a, b])
	_show_message("🌈 彩虹消除 +✨", 0.9)

	var score_result = _apply_combo_gain(int(tuning.get("base_score", 10)))
	if score_result["combo"] > 1:
		_show_combo_burst(str(score_result["combo"]) + " 连击 +" + str(score_result["gain"]))

	# Rainbow light pierces ice: board and armor both go.
	board[a.x][a.y] = 0
	board[b.x][b.y] = 0
	if _is_frost_mode():
		board_armor[a.x][a.y] = 0
		board_armor[b.x][b.y] = 0
	_pop_stack_at(a)
	_pop_stack_at(b)
	_break_chains_around([a, b])
	_consume_move()

	_refresh_ui()
	_refresh_board_visuals()
	_resolve_after_board_changed()

func _board_edge_path(a, b):
	# Bomb/rainbow pairs have no connectable path; draw a playful via-top
	# route instead. (-1, col) is the row just above the board, the same
	# edge convention _find_path uses for routes that leave the grid.
	return [a, Vector2(-1, min(a.y, b.y)), b]

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

	# Endless/zen/moves/race have no countdown clock at all.
	if special_mode == "endless" or int(_current_level().get("time_limit", 90)) <= 0:
		return

	time_left = max(0, time_left - 1)
	_refresh_ui()

	if time_left <= 0:
		_on_time_up()

func _on_time_up():
	if stage_status != STATUS_PLAYING:
		return
	if special_mode != "":
		stage_status = STATUS_FAILED
		AudioManager.play_fail()
		_reset_combo()
		selected = Vector2(-1, -1)
		hint_tiles.clear()
		error_tiles.clear()
		second_timer.stop()
		stage_panel_label.text = "挑战失败！得分 " + str(total_score) + "\n点击「重开」再战，或「暂停」后返回关卡"
		stage_panel_label.visible = true
		_refresh_ui()
		_refresh_board_visuals()
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
	# Clockless modes (endless/zen/moves/race) have no time to drain.
	if special_mode == "endless" or int(_current_level().get("time_limit", 90)) <= 0:
		return
	if seconds <= 0 or stage_status != STATUS_PLAYING:
		return

	time_left = max(0, time_left - seconds)
	_refresh_ui()
	if time_left == 0:
		_on_time_up()

func _apply_combo_gain(base_score):
	var now_ms = OS.get_ticks_msec()
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

	# Time attack: matches refund time and a hot streak ignites fever mode.
	if special_mode == "time_attack":
		var attack_cfg = game_mode_configs.get("time_attack", {})
		if combo >= int(attack_cfg.get("fever_mode_threshold", 5)):
			gain = int(round(gain * float(attack_cfg.get("fever_multiplier", 1.5))))
			_show_message("🔥 Fever x" + str(combo), 0.8)
		var refund = int(attack_cfg.get("time_bonus_per_match", 3))
		if combo >= int(attack_cfg.get("fever_mode_threshold", 5)):
			refund += int(attack_cfg.get("combo_time_bonus", 1))
		time_left = min(999, time_left + refund)

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

	var remain = max(0, combo_expires_ms - OS.get_ticks_msec())
	var window_ms = max(1, int(tuning.get("combo_window_ms", 2600)))
	var progress = (float(remain) / float(window_ms)) * 100.0
	combo_progress_bar.value = progress


func _resolve_after_board_changed():
	# 重力模式: compact columns before any win/lose evaluation.
	if _is_gravity_mode() and _apply_gravity():
		_refresh_board_visuals()
	# Special sessions resolve only when the board is actually cleared;
	# partial eliminations still need the deadlock reshuffle check.
	if special_mode != "":
		if _remaining_tiles_count() == 0:
			_resolve_special_clear()
		elif _find_any_hint(board).empty():
			if _is_fog_mode() and _fog_layers > 0:
				# Fog would trap the last tiles: recede a ring instead.
				_fog_layers -= 1
				_show_message("迷雾退散了一层！", 1.2)
				_refresh_board_visuals()
				return
			if _is_chain_mode() and _chains_remaining() > 0:
				_dissolve_all_chains()
				return
			_reshuffle_board(board)
			_show_message("无解，已自动重排", 1.0)
			_refresh_board_visuals()
		return
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

	if _find_any_hint(board).empty():
		_reshuffle_board(board)
		_show_message("无解，已自动重排", 1.0)
		_refresh_board_visuals()

func _resolve_special_clear():
	# 步数挑战: unused moves convert into bonus score.
	if special_mode == "moves":
		var move_bonus = moves_left * 20
		total_score += move_bonus
		level_score += move_bonus
	var time_bonus_multiplier = float(_current_level().get("time_bonus_multiplier", 2.0))
	var time_bonus = int(round(float(time_left) * time_bonus_multiplier))
	total_score += time_bonus
	level_score += time_bonus

	_reset_combo()
	second_timer.stop()
	if race_timer:
		race_timer.stop()
	stage_panel_label.visible = false
	AudioManager.play_win()

	if special_mode == "endless":
		_patch_progress_state({"endless_result": {"round": endless_round, "score": total_score}})
		if endless_round >= 5:
			_unlock_achievements(["endless_round_5"])
		var finished_round = endless_round
		endless_round += 1
		special_level = SPECIAL_MODES_SCRIPT.build_endless_level(game_mode_configs.get("endless", {}), endless_round)
		stage_status = STATUS_CLEARED
		_play_stage_clear_celebration(false)
		_show_message("第" + str(finished_round) + "轮完成！时间奖励 +" + str(time_bonus) + "，下一轮更大", 1.4)
	else:
		_record_special_completion()
		stage_status = STATUS_COMPLETED
		_play_stage_clear_celebration(true)

	_refresh_ui()
	_refresh_board_visuals()

func _unlock_achievements(ids):
	var new_unlocks = []
	for achievement_id in ids:
		if not PROGRESSION_SCRIPT.has_achievement(progression_state, achievement_id):
			progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, achievement_id)
			new_unlocks.append(achievement_id)
	if new_unlocks.size() > 0:
		_save_progress_state()
		for achievement_id in new_unlocks:
			var info = PROGRESSION_SCRIPT.get_achievement_info(achievement_id)
			_show_achievement_notification(info["name"])

func _record_special_completion():
	var today = SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	if special_mode == "stack":
		_patch_progress_state({"stack_result": total_score})
		_unlock_achievements(["stack_first"])
		stage_panel_label.text = "叠层挑战完成！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("stack_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "gravity":
		_patch_progress_state({"gravity_result": total_score})
		_unlock_achievements(["gravity_first"])
		stage_panel_label.text = "重力挑战完成！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("gravity_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "fog":
		_patch_progress_state({"fog_result": total_score})
		_unlock_achievements(["fog_first"])
		stage_panel_label.text = "迷雾散尽！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("fog_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "chain":
		_patch_progress_state({"chain_result": total_score})
		_unlock_achievements(["chain_first"])
		stage_panel_label.text = "锁链尽断！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("chain_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "zen":
		_patch_progress_state({"zen_result": total_score})
		_unlock_achievements(["zen_first"])
		stage_panel_label.text = "休闲一局完成！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("zen_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "hell":
		_patch_progress_state({"hell_result": total_score})
		_unlock_achievements(["hell_first"])
		stage_panel_label.text = "地狱挑战通关！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("hell_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "moves":
		_patch_progress_state({"moves_result": total_score})
		var move_achievements = ["moves_first"]
		if moves_left >= int(_current_level().get("move_budget", 0)) / 5:
			move_achievements.append("moves_saver")
		_unlock_achievements(move_achievements)
		stage_panel_label.text = "步数挑战完成！剩余%d步奖励%d分 · 最佳 %d" % [moves_left, moves_left * 20, int(progression_state.get("moves_best_score", 0))]
		stage_panel_label.visible = true
		return
	if special_mode == "race":
		_patch_progress_state({"race_result": total_score})
		_unlock_achievements(["race_first"])
		stage_panel_label.text = "战胜机器人！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("race_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "frost":
		_patch_progress_state({"frost_result": total_score})
		var frost_achievements = ["frost_first"]
		if frost_uses == 0:
			frost_achievements.append("frost_no_power")
		_unlock_achievements(frost_achievements)
		stage_panel_label.text = "冰雪挑战完成！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("frost_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "memory":
		_patch_progress_state({"memory_result": total_score})
		_unlock_achievements(["memory_first"])
		stage_panel_label.text = "盲盒挑战完成！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("memory_best_score", 0)))
		stage_panel_label.visible = true
		return
	if special_mode == "daily":
		_patch_progress_state({
			"daily_result": {
				"date": today,
				"yesterday": SPECIAL_MODES_SCRIPT.yesterday_string(OS.get_date()),
				"score": total_score
			}
		})
		var daily = progression_state.get("daily_challenge", {})
		stage_panel_label.text = "今日挑战完成！得分 " + str(total_score) + " · 连胜 " + str(int(daily.get("streak", 0))) + " 天\n明天还有新的棋盘，点击「重开」可再玩今日棋盘"
		if int(daily.get("streak", 0)) >= 7:
			_unlock_achievements(["daily_streak_7"])
	elif special_mode == "time_attack":
		_patch_progress_state({"time_attack_result": total_score})
		stage_panel_label.text = "限时挑战结束！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get("time_attack_best_score", 0)))
		if total_score >= 1000:
			_unlock_achievements(["time_attack_1000"])
	else:
		stage_panel_label.text = "挑战完成！得分 " + str(total_score)
	stage_panel_label.visible = true

func _on_level_advance_timeout():
	if stage_status != STATUS_CLEARED:
		return
	if special_mode == "endless":
		# Next endless round keeps the running total score.
		_reset_level_session(special_level, false)
		_show_message("第" + str(endless_round) + "轮开始", 1.2)
		return
	if pending_level_index < 0:
		return

	var next_index = pending_level_index
	pending_level_index = -1
	_start_level(next_index, false)

func _remaining_tiles_count():
	return BOARD_ENGINE.count_tiles(board)

func _refresh_ui():
	var level = _current_level()
	var level_id = int(level.get("id", level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	var description = str(level.get("description", ""))
	var unlocked_level_count = int(progression_state.get("highest_unlocked_level_index", 0)) + 1

	title_label.text = "连连看 🎀"
	if special_mode == "daily":
		var daily = progression_state.get("daily_challenge", {})
		var now_date = OS.get_date()
		var done_today = str(daily.get("last_date", "")) == SPECIAL_MODES_SCRIPT.date_string(now_date)
		subtitle_label.text = "每日挑战 · %d月%d日 · 连胜%d · 最佳%d · %s" % [
			int(now_date.month), int(now_date.day),
			int(daily.get("streak", 0)), int(daily.get("best_score", 0)),
			"今日已完成" if done_today else "今日未完成"
		]
	elif special_mode == "endless":
		var endless_best = progression_state.get("endless_best", {})
		subtitle_label.text = "无尽模式 · 第%d轮 · 最佳第%d轮 · 最高%d分" % [
			endless_round, int(endless_best.get("round", 0)), int(endless_best.get("score", 0))
		]
	elif special_mode == "time_attack":
		subtitle_label.text = "限时挑战 · 最佳%d分" % int(progression_state.get("time_attack_best_score", 0))
	elif special_mode == "memory":
		subtitle_label.text = "盲盒模式 · 最佳%d分" % int(progression_state.get("memory_best_score", 0))
	elif special_mode == "frost":
		subtitle_label.text = "冰雪挑战 · 最佳%d分" % int(progression_state.get("frost_best_score", 0))
	elif special_mode == "zen":
		subtitle_label.text = "休闲模式 · 最佳%d分" % int(progression_state.get("zen_best_score", 0))
	elif special_mode == "hell":
		subtitle_label.text = "地狱模式 · 最佳%d分" % int(progression_state.get("hell_best_score", 0))
	elif special_mode == "moves":
		subtitle_label.text = "步数挑战 · 最佳%d分 · 剩余%d步" % [int(progression_state.get("moves_best_score", 0)), moves_left]
	elif special_mode == "race":
		subtitle_label.text = "竞速对战 · 最佳%d分" % int(progression_state.get("race_best_score", 0))
	elif special_mode == "stack":
		subtitle_label.text = "叠层模式 · 最佳%d分" % int(progression_state.get("stack_best_score", 0))
	elif special_mode == "gravity":
		subtitle_label.text = "重力模式 · 最佳%d分" % int(progression_state.get("gravity_best_score", 0))
	elif special_mode == "fog":
		subtitle_label.text = "迷雾模式 · 最佳%d分" % int(progression_state.get("fog_best_score", 0))
	elif special_mode == "chain":
		subtitle_label.text = "锁链模式 · 最佳%d分" % int(progression_state.get("chain_best_score", 0))
	else:
		subtitle_label.text = "第" + str(level_id) + "/" + str(campaign_levels.size()) + "关 · " + level_name + " · 已解锁" + str(unlocked_level_count) + "/" + str(campaign_levels.size())
	desc_label.text = description

	status_chip_label.text = _status_label(stage_status)
	# Update status chip style based on status
	var status_style = StyleBoxFlat.new()
	status_style.set_corner_radius_all(16)
	if stage_status == STATUS_PLAYING:
		status_chip_label.add_color_override("font_color", Color("0ca678"))
		status_style.bg_color = Color("e6fcf5")
	elif stage_status == STATUS_PAUSED:
		status_chip_label.add_color_override("font_color", Color("e67700"))
		status_style.bg_color = Color("fff3bf")
	elif stage_status == STATUS_CLEARED:
		status_chip_label.add_color_override("font_color", Color("e64980"))
		status_style.bg_color = Color("ffe3ef")
	elif stage_status == STATUS_FAILED:
		status_chip_label.add_color_override("font_color", Color("f06565"))
		status_style.bg_color = Color("ffe3e3")
	else:
		status_chip_label.add_color_override("font_color", Color("0ca678"))
		status_style.bg_color = Color("e6fcf5")
	status_chip_label.add_stylebox_override("normal", status_style)

	mode_chip_label.text = "模式：" + _mode_label(mode)
	kinds_chip_label.text = "图案种类：" + str(level.get("kinds", 0))

	level_progress_bar.value = (float(level_index + 1) / float(max(1, campaign_levels.size()))) * 100.0
	if special_mode != "":
		level_progress_bar.value = 100.0

	_set_stat_text("total_score", str(total_score))
	_set_stat_text("level_score", str(level_score))
	_set_stat_text("moves", str(moves))
	_set_stat_text("remaining", str(_remaining_tiles_count() / 2))
	_set_stat_text("time_left", "∞" if int(_current_level().get("time_limit", 90)) <= 0 else _format_time(time_left))
	_set_stat_text("combo", "x" + str(max(combo, 1)))
	_set_stat_text("best_total_score", str(_progress_best_score()))
	_set_stat_text("best_combo", "x" + str(_progress_best_combo()))

	# 对手 card only shows during the AI race.
	if stat_values.has("race"):
		stat_values["race"]["card"].visible = special_mode == "race"
		_set_stat_text("race", "%d/%d" % [race_ai_pairs, race_total_pairs])

	_update_fog()
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
		# 暖宝宝 is frost-only; hide its slot everywhere else to save width.
		if power_up_id == "warm_patch" and labels.has("box"):
			labels["box"].visible = _is_frost_mode()

func _set_stat_text(key, value):
	STATS_HUD.set_text(self, key, value)

func _is_time_danger():
	if special_mode == "endless" or int(_current_level().get("time_limit", 90)) <= 0:
		return false
	return stage_status == STATUS_PLAYING and time_left <= int(tuning.get("time_danger_seconds", 10))

func _update_time_warning_pulse(_delta):
	STATS_HUD.pulse(self, _is_time_danger(), _delta)

func _set_time_card_state(is_danger):
	STATS_HUD.set_card_state(self, is_danger)

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
		"daily":
			return "每日挑战"
		"time_attack":
			return "限时挑战"
		"endless":
			return "无尽模式"
		"memory":
			return "盲盒模式"
		"frost":
			return "冰雪挑战"
		"zen":
			return "休闲模式"
		"hell":
			return "地狱模式"
		"moves":
			return "步数挑战"
		"race":
			return "竞速对战"
		"stack":
			return "叠层模式"
		"gravity":
			return "重力模式"
		"fog":
			return "迷雾模式"
		"chain":
			return "锁链模式"
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
	return BOARD_ENGINE.format_time(seconds)

func _format_time_seconds(time_seconds):
	var mm = int(time_seconds) / 60
	var ss = int(time_seconds) % 60
	var ms = int((time_seconds - int(time_seconds)) * 100)
	return "%02d:%02d.%02d" % [mm, ss, ms]

# Achievement system

func _check_achievements_on_clear():
	var level_clear_time = (OS.get_ticks_msec() - level_start_time) / 1000.0
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
	notification.set_anchors_and_margins_preset(Control.PRESET_CENTER_TOP)
	notification.margin_top = 60
	_apply_glass_style(notification, Color("fff3bf"), 0.95)
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
	label.add_color_override("font_color", Color("d6336c"))
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
	return BOARD_ENGINE.is_inside(board_state, point)

func _pad_board(board_state):
	return BOARD_ENGINE.pad_board(board_state)

func _find_path(board_state, a, b):
	return BOARD_ENGINE.find_path(board_state, a, b)

func _node_key(r, c, d, t):
	return BOARD_ENGINE.node_key(r, c, d, t)

func _parse_node_key(key):
	return BOARD_ENGINE.parse_node_key(key)

func _reconstruct_path(cur, parent, start):
	return BOARD_ENGINE.reconstruct_path(cur, parent, start)

func _compress_path(points):
	return BOARD_ENGINE.compress_path(points)

func _find_any_hint(board_state):
	return BOARD_ENGINE.find_any_hint(board_state, self, "_is_coord_playable")

func _reshuffle_board(board_state):
	BOARD_ENGINE.reshuffle_board(board_state, self, "_is_coord_playable")

# --- UI 面板回调与状态方法（Round D 从 ui_panels.gd 迁回）---
func _show_onboarding_if_needed():
	var has_seen_onboarding = progression_state.get(ONBOARDING_SEEN_KEY, false)
	if not has_seen_onboarding and onboarding_panel != null:
		onboarding_panel.visible = true
		stage_status = STATUS_PAUSED
		if second_timer:
			second_timer.stop()

func _on_onboarding_dismissed():
	print("[Game] onboarding dismissed")
	if onboarding_panel != null:
		onboarding_panel.visible = false
	_patch_progress_state({ONBOARDING_SEEN_KEY: true})
	stage_status = STATUS_PLAYING
	if second_timer:
		second_timer.start()

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

func _refresh_modes_panel():
	if modes_panel == null:
		return
	# modes_panel content chain: vbox -> margin -> content; content children:
	# [title, rows_box, spacer, close_button]
	var content = modes_panel.get_child(0).get_child(0).get_child(0)
	var rows_box = content.get_child(1).get_child(0)
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()

	var today = SPECIAL_MODES_SCRIPT.date_string(OS.get_date())
	var daily = progression_state.get("daily_challenge", {})
	var endless_best = progression_state.get("endless_best", {})
	var unlocked_index = int(progression_state.get("highest_unlocked_level_index", 0))
	var done_today = str(daily.get("last_date", "")) == today
	var rows = [
		{
			"id": "daily",
			"title": "📅 每日挑战",
			"detail": "全网同一棋盘 · 连胜%d · 最佳%d分 · %s" % [
				int(daily.get("streak", 0)), int(daily.get("best_score", 0)),
				"今日已完成" if done_today else "今日未完成"
			]
		},
		{
			"id": "time_attack",
			"title": "⏱️ 限时挑战",
			"detail": "60秒起，消除得时间 · 最佳%d分" % int(progression_state.get("time_attack_best_score", 0))
		},
		{
			"id": "memory",
			"title": "🎁 盲盒模式",
			"detail": "记忆翻牌配对 · 最佳%d分" % int(progression_state.get("memory_best_score", 0))
		},
		{
			"id": "frost",
			"title": "❄️ 冰雪挑战",
			"detail": "冰冻方块要消除两次 · 最佳%d分" % int(progression_state.get("frost_best_score", 0))
		},
		{
			"id": "zen",
			"title": "🍵 休闲模式",
			"detail": "没有时限，纯享受 · 最佳%d分" % int(progression_state.get("zen_best_score", 0))
		},
		{
			"id": "hell",
			"title": "🔥 地狱模式",
			"detail": "大盘少图案超紧时间 · 最佳%d分" % int(progression_state.get("hell_best_score", 0))
		},
		{
			"id": "moves",
			"title": "🧮 步数挑战",
			"detail": "步数有限精打细算 · 最佳%d分" % int(progression_state.get("moves_best_score", 0))
		},
		{
			"id": "race",
			"title": "🤖 竞速对战",
			"detail": "和机器人抢消·先完成者胜 · 最佳%d分" % int(progression_state.get("race_best_score", 0))
		},
		{
			"id": "stack",
			"title": "🥞 叠层模式",
			"detail": "上层压下层先消上层 · 最佳%d分" % int(progression_state.get("stack_best_score", 0))
		},
		{
			"id": "gravity",
			"title": "🍎 重力模式",
			"detail": "消除后方块掉落补位 · 最佳%d分" % int(progression_state.get("gravity_best_score", 0))
		},
		{
			"id": "fog",
			"title": "🌫️ 迷雾模式",
			"detail": "边缘迷雾随消除退散 · 最佳%d分" % int(progression_state.get("fog_best_score", 0))
		},
		{
			"id": "chain",
			"title": "⛓️ 锁链模式",
			"detail": "相邻消除解锁锁链 · 最佳%d分" % int(progression_state.get("chain_best_score", 0))
		},
		{
			"id": "endless",
			"title": "∞ 无尽模式",
			"detail": "不限时，棋盘越滚越大 · 最佳第%d轮 · 最高%d分" % [
				int(endless_best.get("round", 0)), int(endless_best.get("score", 0))
			]
		}
	]
	for row in rows:
		var config = game_mode_configs.get(row["id"], {})
		var unlocked = SPECIAL_MODES_SCRIPT.is_mode_unlocked(row["id"], config, unlocked_index)
		var button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.rect_min_size = Vector2(0, 52)
		button.add_font_override("font", game_font)
		if unlocked:
			button.text = row["title"] + "\n" + row["detail"]
			button.connect("pressed", self, "_on_special_mode_pressed", [row["id"]])
		else:
			button.text = row["title"] + "\n" + SPECIAL_MODES_SCRIPT.unlock_requirement_text(row["id"], config)
		_style_dialog_buttons(button)
		rows_box.add_child(button)

func _on_modes_pressed():
	_refresh_modes_panel()
	if modes_panel:
		modes_panel.visible = true

func _on_modes_close_pressed():
	if modes_panel:
		modes_panel.visible = false

func _on_special_mode_pressed(mode_id):
	_on_modes_close_pressed()
	_start_special_mode(mode_id)

func _on_exit_special_pressed():
	_hide_pause_panel()
	_exit_special_mode()

func _show_pause_panel():
	if pause_panel == null:
		return
	# Update level info
	var vbox = pause_panel.get_child(0)
	var margin = vbox.get_child(0)
	var content = margin.get_child(0)
	var level_info = content.get_child(1) as Label
	var level = _current_level()
	if special_mode != "":
		level_info.text = str(level.get("name", "特殊模式")) + " · " + _mode_label(special_mode)
	else:
		var level_id = int(level.get("id", level_index + 1))
		var level_name = str(level.get("name", "关卡"))
		level_info.text = "第" + str(level_id) + "关 - " + level_name
	if pause_exit_button:
		pause_exit_button.visible = special_mode != ""

	pause_panel.visible = true

func _hide_pause_panel():
	if pause_panel != null:
		pause_panel.visible = false

func _on_restart_current_level():
	_hide_pause_panel()
	if special_mode != "":
		_start_special_mode(special_mode)
		_show_message("重新开始挑战", 1.0)
		return
	_start_level(level_index, false)
	_show_message("重新开始当前关卡", 1.0)

func _on_back_to_first_level():
	_hide_pause_panel()
	_start_level(0, true)
	_show_message("返回第1关", 1.0)
