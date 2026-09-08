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
const PROGRESS_STORE = preload("res://scripts/progress_store.gd")
const GAME_CONFIG = preload("res://scripts/game_config.gd")
const SESSION = preload("res://scripts/session.gd")
const GAME_INPUT = preload("res://scripts/game_input.gd")
const FX = preload("res://scripts/fx_layer.gd")
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

func _animate_select(coord):
	return BOARD_VIEW._animate_select(self, coord)

func _pulse_tile(coord, peak_scale, half_duration, loops = 1):
	return BOARD_VIEW._pulse_tile(self, coord, peak_scale, half_duration, loops)

func _shake_tile(coord):
	return BOARD_VIEW._shake_tile(self, coord)

func _ready():
	print("[Game] boot: ready")
	randomize()
	_init_font()
	_load_config()
	print("[Game] boot: config loaded, levels=", campaign_levels.size())
	_load_progress_state()
	_build_ui()
	_build_timers()
	var start_level_index = int(progression_state.get("current_level_index", 0))
	print("[Game] boot: starting level ", start_level_index)
	_start_level(start_level_index, true)
	set_process(true)
	call_deferred("_show_onboarding_if_needed")
	call_deferred("_start_bgm")

func _process(delta):
	_update_combo_progress()
	_update_time_warning_pulse(delta)


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

func _on_tile_pressed(button):
	return GAME_INPUT._on_tile_pressed(self, button)

func _on_memory_tile_pressed(point, r, c):
	return GAME_INPUT._on_memory_tile_pressed(self, point, r, c)

func _unhandled_input(event):
	return GAME_INPUT._unhandled_input(self, event)

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










func _progress_best_score():
	return PROGRESSION_SCRIPT.best_score(progression_state)

func _progress_best_combo():
	return PROGRESSION_SCRIPT.best_combo(progression_state)



func _default_campaign_levels():
	return CAMPAIGN_LEVELS_SCRIPT.default_campaign_levels()


func _build_ui():
	UI_HUD.build_main_ui(self)


func _build_onboarding_panel():
	UI_PANELS._onboarding_panel(self)

func _build_settings_panel():
	UI_PANELS._settings_panel(self)

func _load_config():
	return GAME_CONFIG._load_config(self)

func _load_progress_state():
	return PROGRESS_STORE._load_progress_state(self)

func _save_progress_state():
	return PROGRESS_STORE._save_progress_state(self)

func _patch_progress_state(patch):
	return PROGRESS_STORE._patch_progress_state(self, patch)

func _load_json_file(path: String):
	return GAME_CONFIG._load_json_file(self, path)

func _load_campaign_levels():
	return GAME_CONFIG._load_campaign_levels(self)

func _load_tuning():
	return GAME_CONFIG._load_tuning(self)

func _load_icon_sets():
	return GAME_CONFIG._load_icon_sets(self)

func _load_game_mode_configs():
	return GAME_CONFIG._load_game_mode_configs(self)

func _default_tuning():
	return GAME_CONFIG._default_tuning(self)

func _default_icon_sets():
	return GAME_CONFIG._default_icon_sets(self)

func _build_achievements_panel():
	UI_PANELS._achievements_panel(self)

func _build_pause_panel():
	UI_PANELS._pause_panel(self)

func _build_modes_panel():
	UI_PANELS._modes_panel(self)




func _add_stat_card(parent, title, key):
	STATS_HUD.add_card(self, parent, title, key)


func _populate_icon_set_options():
	icon_set_option.clear()
	for i in range(icon_sets.size()):
		var icon_set: Dictionary = icon_sets[i]
		icon_set_option.add_item(icon_set.get("name", "主题" + str(i + 1)))

	if icon_sets.size() > 0:
		icon_set_index = clamp(icon_set_index, 0, icon_sets.size() - 1)
		icon_set_option.select(icon_set_index)

func _create_power_up_label(power_up_id, icon, shortcut):
	return STATS_HUD._create_power_up_label(self, power_up_id, icon, shortcut)

func _create_chip_label():
	return STATS_HUD._create_chip_label(self)

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


func _on_level_select_changed(index):
	if not _is_level_unlocked(index):
		_sync_level_select_selection()
		_show_message("该关卡尚未解锁", 0.9)
		return
	_refresh_ui()


func _trigger_level_highlight():
	if level_select_option == null:
		return
	level_select_option.modulate = LEVEL_HIGHLIGHT_COLOR
	level_highlight_timer.stop()
	level_highlight_timer.wait_time = 0.4
	level_highlight_timer.start()


func _start_bgm():
	AudioManager.start_bgm()

func _stop_bgm():
	AudioManager.stop_bgm()


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









func _color_for(value):
	if icon_sets.empty():
		return Color("ffffff")

	var icon_set: Dictionary = icon_sets[icon_set_index]
	var colors: Array = icon_set.get("colors", [])
	var index = value - 1
	if index >= 0 and index < colors.size():
		return Color(str(colors[index]))
	return Color("ffffff")

func _apply_glass_style(panel, bg_color, alpha):
	return UI_PANELS._apply_glass_style(self, panel, bg_color, alpha)

func _apply_button_style(button, bg_color, border_color):
	return UI_PANELS._apply_button_style(self, button, bg_color, border_color)

func _style_dialog_buttons(node):
	return UI_PANELS._style_dialog_buttons(self, node)

func _refresh_board_visuals():
	return BOARD_VIEW._refresh_board_visuals(self)

func _render_board():
	return BOARD_VIEW._render_board(self)

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


func _memory_schedule_hide(coords, delay):
	memory_pending_hide = coords.duplicate()
	memory_lock = true
	memory_hide_timer.stop()
	memory_hide_timer.wait_time = max(0.2, delay)
	memory_hide_timer.start()








func _on_second_tick():
	return UI_HUD._on_second_tick(self)

func _on_race_tick():
	return UI_HUD._on_race_tick(self)

func _on_message_timeout():
	return UI_HUD._on_message_timeout(self)

func _on_error_timeout():
	return UI_HUD._on_error_timeout(self)

func _on_combo_reset_timeout():
	return UI_HUD._on_combo_reset_timeout(self)

func _on_level_highlight_timeout():
	return UI_HUD._on_level_highlight_timeout(self)

func _on_level_advance_timeout():
	return UI_HUD._on_level_advance_timeout(self)

func _on_time_freeze_timeout():
	return UI_HUD._on_time_freeze_timeout(self)

func _on_memory_preview_timeout():
	return UI_HUD._on_memory_preview_timeout(self)

func _on_memory_hide_timeout():
	return UI_HUD._on_memory_hide_timeout(self)



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

func _on_hint_pressed():
	return GAME_INPUT._on_hint_pressed(self)

func _on_auto_pressed():
	return GAME_INPUT._on_auto_pressed(self)







func _on_shuffle_pressed():
	return GAME_INPUT._on_shuffle_pressed(self)

func _on_reset_pressed():
	return GAME_INPUT._on_reset_pressed(self)

func _on_jump_level_pressed():
	return GAME_INPUT._on_jump_level_pressed(self)

func _on_pause_pressed():
	return GAME_INPUT._on_pause_pressed(self)

func _cycle_level_selection(step):
	return GAME_INPUT._cycle_level_selection(self, step)

func _toggle_fullscreen_mode():
	return GAME_INPUT._toggle_fullscreen_mode(self)

func _try_get_tile_button(coord):
	if coord.x < 0 or coord.x >= cell_buttons.size():
		return null
	var row_buttons: Array = cell_buttons[coord.x]
	if coord.y < 0 or coord.y >= row_buttons.size():
		return null
	return row_buttons[coord.y]



func _make_fx_tween(node_to_free = null):
	var tween = Tween.new()
	add_child(tween)
	if node_to_free != null:
		tween.connect("tween_all_completed", node_to_free, "queue_free")
	tween.connect("tween_all_completed", tween, "queue_free")
	return tween









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
	return BOARD_VIEW._animate_board_spawn(self)

func _animate_shuffle_wave():
	return BOARD_VIEW._animate_shuffle_wave(self)

func _build_timers():
	return UI_HUD._build_timers(self)

func _show_message(text, duration_sec = 1.0):
	return UI_HUD._show_message(self, text, duration_sec)

func _hide_message():
	return UI_HUD._hide_message(self)

func _show_stage_callout(text, color, font_size):
	return UI_HUD._show_stage_callout(self, text, color, font_size)

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





func _play_eliminate_effects(coords):
	return FX._play_eliminate_effects(self, coords)

func _tile_center_in_effect_layer(coord):
	return FX._tile_center_in_effect_layer(self, coord)


func _spawn_ring_effect(center, color, duration, base_size):
	return FX._spawn_ring_effect(self, center, color, duration, base_size)

func _spawn_particle_burst(center, color, particle_count, intensity):
	return FX._spawn_particle_burst(self, center, color, particle_count, intensity)

func _spawn_combo_particle_burst(center, color, particle_count, combo_level):
	return FX._spawn_combo_particle_burst(self, center, color, particle_count, combo_level)

func _spawn_board_particles(count, color, intensity):
	return FX._spawn_board_particles(self, count, color, intensity)

func _show_combo_burst(text):
	return FX._show_combo_burst(self, text)

















# One successful match hits both tiles. Frozen cells (armor 1) crack instead
# of clearing and need a second match; cracked tiles keep blocking paths.
# 步数挑战: every removed pair costs one move; running dry loses.
func _flash_error_tiles(coords):
	return FX._flash_error_tiles(self, coords)

func _animate_hint_tiles(coords):
	return FX._animate_hint_tiles(self, coords)

func _show_path(path, preview_type, duration_ms):
	return FX._show_path(self, path, preview_type, duration_ms)

func _path_to_overlay_points(path):
	return FX._path_to_overlay_points(self, path)

func _consume_move():
	if special_mode != "moves" or stage_status != STATUS_PLAYING:
		return
	moves_left = max(0, moves_left - 1)
	_refresh_ui()
	if moves_left <= 0 and _remaining_tiles_count() > 0:
		_fail_moves_exhausted()


# 竞速对战: the AI clears one pair per ai_interval seconds.

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


func _start_second_timer():
	second_timer.stop()
	second_timer.start()



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

func _on_time_up():
	return SESSION._on_time_up(self)

func _record_special_completion():
	return SESSION._record_special_completion(self)


func _start_special_mode(mode_id):
	return SESSION._start_special_mode(self, mode_id)

func _exit_special_mode():
	return SESSION._exit_special_mode(self)

func _apply_combo_gain(base_score):
	return SESSION._apply_combo_gain(self, base_score)

func _reset_level_session(level, reset_total = false):
	return SESSION._reset_level_session(self, level, reset_total)

func _fail_moves_exhausted():
	return SESSION._fail_moves_exhausted(self)

func _resolve_after_board_changed():
	return SESSION._resolve_after_board_changed(self)

func _resolve_special_clear():
	return SESSION._resolve_special_clear(self)


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

func _create_control_button(text):
	return UI_HUD._create_control_button(self, text)

func _populate_level_select_options():
	return UI_HUD._populate_level_select_options(self)

func _show_achievement_notification(achievement_name):
	return UI_HUD._show_achievement_notification(self, achievement_name)

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
