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
const BOARD_VIEW = preload("res://scripts/board_view.gd")
const POWERUPS = preload("res://scripts/powerups.gd")
const UI_HUD = preload("res://scripts/ui_hud.gd")

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
const CAMPAIGN_LEVELS_SCRIPT = preload("res://scripts/campaign_levels.gd")
const MOBILE_SHORT_SIDE_MAX = 860.0
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
	UI_HUD.update_layout(self)


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
	return PROGRESSION_SCRIPT.best_score(progression_state)

func _progress_best_combo():
	return PROGRESSION_SCRIPT.best_combo(progression_state)

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
	return CAMPAIGN_LEVELS_SCRIPT.default_campaign_levels()

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
	UI_HUD.build_main_ui(self)


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
		_show_message(SPECIAL_MODES_SCRIPT.intro_text(mode_id), 1.8)

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


func _color_for(value):
	if icon_sets.empty():
		return Color("ffffff")

	var icon_set: Dictionary = icon_sets[icon_set_index]
	var colors: Array = icon_set.get("colors", [])
	var index = value - 1
	if index >= 0 and index < colors.size():
		return Color(str(colors[index]))
	return Color("ffffff")

func _refresh_board_visuals():
	return BOARD_VIEW._refresh_board_visuals(self)

func _update_tile_sizes():
	return BOARD_VIEW._update_tile_sizes(self)

func _apply_tile_style(button, bg_color, border_color, highlight):
	return BOARD_VIEW._apply_tile_style(self, button, bg_color, border_color, highlight)

func _icon_for(value):
	return BOARD_VIEW._icon_for(self, value)

func _contains_coord(list, coord):
	return BOARD_ENGINE.contains_coord(list, coord)


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
	return BOARD_ENGINE.build_frost_armor_grid(new_board, float(level.get("frost_ratio", 0.0)))

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
	board_lower = BOARD_ENGINE.bury_stack_layer(board, ratio)

# 锁链: chain a share of tiles; adjacent clears break the chains.
func _build_chain_locks(ratio):
	board_chain = BOARD_ENGINE.build_chain_grid(board, ratio)

func _chains_remaining():
	return BOARD_ENGINE.count_chains(board_chain)

func _dissolve_all_chains():
	BOARD_ENGINE.zero_grid(board_chain)
	_show_message("⛓️ 死局解除，锁链全部崩解！", 1.4)
	_refresh_board_visuals()

func _break_chains_around(coords):
	if not _is_chain_mode() or coords == null:
		return
	if BOARD_ENGINE.break_chains_around(board_chain, coords) > 0:
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
	_fog_layers = BOARD_ENGINE.fog_layers(_remaining_tiles_count(), max_layers)

func _pop_stack_at(coord):
	if not _is_stack_mode():
		return
	BOARD_ENGINE.pop_stack(board, board_lower, coord)

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



func _board_edge_path(a, b):
	# Bomb/rainbow pairs have no connectable path; draw a playful via-top
	# route instead. (-1, col) is the row just above the board, the same
	# edge convention _find_path uses for routes that leave the grid.
	return [a, Vector2(-1, min(a.y, b.y)), b]

func _init_power_ups(level):
	return POWERUPS._init_power_ups(self, level)

func _use_power_up(power_up_type):
	return POWERUPS._use_power_up(self, power_up_type)

func _activate_time_freeze():
	return POWERUPS._activate_time_freeze(self)

func _activate_auto_match():
	return POWERUPS._activate_auto_match(self)

func _activate_reshuffle():
	return POWERUPS._activate_reshuffle(self)

func _activate_magnifier():
	return POWERUPS._activate_magnifier(self)

func _activate_time_sand():
	return POWERUPS._activate_time_sand(self)

func _activate_bomb():
	return POWERUPS._activate_bomb(self)

func _activate_rainbow():
	return POWERUPS._activate_rainbow(self)

func _activate_warm_patch():
	return POWERUPS._activate_warm_patch(self)

func _execute_warm_patch(point):
	return POWERUPS._execute_warm_patch(self, point)

func _execute_bomb(point):
	return POWERUPS._execute_bomb(self, point)

func _execute_rainbow_click(point):
	return POWERUPS._execute_rainbow_click(self, point)

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
	var record = SPECIAL_MODES_SCRIPT.RECORD_MODES.get(special_mode, {})
	if not record.empty():
		_patch_progress_state({record["patch_key"]: total_score})
		var achievements = record["achievements"].duplicate()
		achievements.append_array(SPECIAL_MODES_SCRIPT.bonus_achievements(special_mode, {
			"frost_uses": frost_uses,
			"moves_left": moves_left,
			"move_budget": int(_current_level().get("move_budget", 0)),
		}))
		_unlock_achievements(achievements)
		stage_panel_label.text = record["label"] + "完成！得分 " + str(total_score) + " · 最佳 " + str(int(progression_state.get(record["best_key"], 0)))
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
	UI_HUD.refresh_ui(self)


func _update_power_ups_display():
	for power_up_id in power_up_labels.keys():
		STATS_HUD.update_power_up(self, power_up_id, power_ups.get(power_up_id, 0))

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
	return SPECIAL_MODES_SCRIPT.mode_label(mode)

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
	return BOARD_ENGINE.format_time_seconds(time_seconds)

# Achievement system

func _check_achievements_on_clear():
	var level_clear_time = (OS.get_ticks_msec() - level_start_time) / 1000.0
	var current_best = float(progression_state.get("level_best_times", {}).get(str(level_index), 999999.0))
	if level_clear_time < current_best:
		_patch_progress_state({"level_best_time": {"level_index": level_index, "time": level_clear_time}})
		_show_message("🎉 新纪录！用时 " + _format_time_seconds(level_clear_time), 2.0)
	var new_unlocks = PROGRESSION_SCRIPT.clear_unlocked_ids(progression_state, {
		"level_index": level_index,
		"combo": combo,
		"clear_time": level_clear_time,
		"hints_used": level_hints_used,
		"auto_used": level_auto_used,
		"level_count": campaign_levels.size(),
	})
	for achievement_id in new_unlocks:
		progression_state = PROGRESSION_SCRIPT.unlock_achievement(progression_state, achievement_id)
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

	var rows = SPECIAL_MODES_SCRIPT.modes_panel_rows(progression_state)
	var unlocked_index = int(progression_state.get("highest_unlocked_level_index", 0))
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
