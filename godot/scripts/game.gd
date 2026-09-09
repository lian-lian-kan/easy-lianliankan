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
const BOARD_MECHANICS = preload("res://scripts/board_mechanics.gd")

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
const UI_FONTS = preload("res://scripts/ui_fonts.gd")
const HUD_TIMERS = preload("res://scripts/hud_timers.gd")
const HUD_LAYOUT = preload("res://scripts/hud_layout.gd")
const PAGE_ROUTER = preload("res://scripts/page_router.gd")
const TILE_MATCH = preload("res://scripts/tile_match.gd")
const MEMORY_FLIP = preload("res://scripts/memory_flip.gd")
const ECONOMY = preload("res://scripts/economy.gd")
const SPECIAL_SESSION = preload("res://scripts/special_session.gd")

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

var revive_button  # 樱花币复活按钮（失败结算浮层）
var revive_cost = 30

var flip_state = {}  # 翻翻乐：暗牌状态（memory_flip.gd 管理）
var flip_layer  # 翻翻乐渲染层
var flip_back_timer  # 翻错盖回延时器
var collect_targets = {}  # 收集挑战：目标图案 -> 需要对数
var collect_progress = {}  # 收集挑战：已完成对数
var collect_row  # 目标进度行
var collect_labels = []  # 每个目标的进度 Label

var tray_state = {}  # 叠叠消：牌堆/槽位状态（tile_match.gd 管理）
var tray_layer  # 叠叠消渲染层（挂在棋盘区内）

var pages_root  # 多页面容器（旅程/图鉴/有礼/小铺）
var page_content
var nav_bar
var nav_buttons = {}
var coin_label
var current_page = ""

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



	# Panels are mounted inside full-rect CenterContainer holders (see
	# _mount_modal_panel), so dynamic content never knocks them off-center.

# A CenterContainer holder keeps dialogs centered whatever their content
# size does; mouse_filter IGNORE lets board clicks pass through when the
# dialog is hidden.

func _update_modal_panel_sizes(viewport_size, is_portrait):
	return UI_PANELS._update_modal_panel_sizes(self, viewport_size, is_portrait)

func _viewport_flags(viewport_size):
	return HUD_LAYOUT._viewport_flags(self, viewport_size)

func _update_layout_for_screen_size():
	HUD_LAYOUT.update_layout(self)


func _mount_modal_panel(panel):
	return UI_PANELS._mount_modal_panel(self, panel)

var _font_cache = {}

func _font_at_size(px):
	return UI_FONTS.font_at_size(self, px)

func _on_tile_pressed(button):
	return GAME_INPUT._on_tile_pressed(self, button)

func _on_memory_tile_pressed(point, r, c):
	return GAME_INPUT._on_memory_tile_pressed(self, point, r, c)

func _unhandled_input(event):
	return GAME_INPUT._unhandled_input(self, event)

func _init_font():
	UI_FONTS.init_theme(self)










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



func _create_power_up_label(power_up_id, icon, shortcut):
	return STATS_HUD._create_power_up_label(self, power_up_id, icon, shortcut)

func _create_chip_label():
	return STATS_HUD._create_chip_label(self)


func _populate_icon_set_options():
	return UI_PANELS._populate_icon_set_options(self)

func _on_icon_set_selected(index):
	return UI_PANELS._on_icon_set_selected(self, index)

func _is_level_unlocked(level_idx):
	return PROGRESSION_SCRIPT.is_level_unlocked(progression_state, level_idx, campaign_levels.size())

func _selected_level_option_index():
	return UI_HUD._selected_level_option_index(self)

func _sync_level_select_selection():
	return UI_HUD._sync_level_select_selection(self)

func _level_label_by_index(level_idx):
	return UI_HUD._level_label_by_index(self, level_idx)


func _on_level_select_changed(index):
	return UI_HUD._on_level_select_changed(self, index)


func _trigger_level_highlight():
	return UI_HUD._trigger_level_highlight(self)


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






func _current_level():
	if special_mode != "":
		return special_level
	return campaign_levels[level_index]

func _create_playable_board(level):
	return BOARD_ENGINE.create_playable_board(level, self, "_is_coord_playable")

func _create_board(rows, cols, kinds):
	return BOARD_ENGINE.create_board(rows, cols, kinds)

func _start_level(next_index, reset_total = false):
	return SESSION._start_level(self, next_index, reset_total)

func _shuffle_array(arr):
	BOARD_ENGINE.shuffle_array(arr)









func _color_for(value):
	return BOARD_VIEW.color_for(self, value)

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
	return BOARD_MECHANICS.cell_ring(self, r, c)

func _is_fogged(coord):
	return BOARD_MECHANICS.is_fogged(self, coord)

# 迷雾/锁链 make a tile unselectable; clicks, hints and auto tools skip it.
func _is_coord_playable(coord):
	return BOARD_MECHANICS.is_coord_playable(self, coord)

func _build_frost_armor(new_board, level):
	return BOARD_ENGINE.build_frost_armor_grid(new_board, float(level.get("frost_ratio", 0.0)))




func _memory_key(coord):
	return SPECIAL_SESSION._memory_key(self, coord)









func _memory_schedule_hide(coords, delay):
	return SPECIAL_SESSION._memory_schedule_hide(self, coords, delay)

func _start_memory_preview():
	return SPECIAL_SESSION._start_memory_preview(self)

func _on_second_tick():
	return HUD_TIMERS._on_second_tick(self)

func _on_race_tick():
	return HUD_TIMERS._on_race_tick(self)

func _on_message_timeout():
	return HUD_TIMERS._on_message_timeout(self)

func _on_error_timeout():
	return HUD_TIMERS._on_error_timeout(self)

func _on_combo_reset_timeout():
	return HUD_TIMERS._on_combo_reset_timeout(self)

func _on_level_highlight_timeout():
	return HUD_TIMERS._on_level_highlight_timeout(self)

func _on_level_advance_timeout():
	return HUD_TIMERS._on_level_advance_timeout(self)

func _on_time_freeze_timeout():
	return HUD_TIMERS._on_time_freeze_timeout(self)





func _on_memory_hide_timeout():
	return SPECIAL_SESSION._on_memory_hide_timeout(self)

func _on_memory_preview_timeout():
	return SPECIAL_SESSION._on_memory_preview_timeout(self)



func _pause_stage():
	return SESSION._pause_stage(self)

func _on_hint_pressed():
	return GAME_INPUT._on_hint_pressed(self)

func _on_auto_pressed():
	return GAME_INPUT._on_auto_pressed(self)







func _resume_stage():
	return SESSION._resume_stage(self)

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
	return BOARD_VIEW.tile_button_at(self, coord)



func _make_fx_tween(node_to_free = null):
	return FX.make_tween(self, node_to_free)









func _play_level_intro_animation(level):
	var callout = SPECIAL_MODES_SCRIPT.stage_callout(special_mode, level, level_index, endless_round)
	_show_stage_callout(callout[0], callout[1], 19)
	_animate_board_spawn()


func _animate_board_spawn():
	return BOARD_VIEW._animate_board_spawn(self)

func _animate_shuffle_wave():
	return BOARD_VIEW._animate_shuffle_wave(self)

func _build_timers():
	return HUD_TIMERS._build_timers(self)

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
	return FX.stage_clear_celebration(self, is_final_clear)





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



# 竞速对战: the AI clears one pair per ai_interval seconds.


# 叠层: lift a share of tiles onto a visible cover with a buried twin.
func _consume_move():
	return SESSION._consume_move(self)

func _build_stack_layers(ratio):
	return BOARD_MECHANICS.build_stack_layers(self, ratio)

# 锁链: chain a share of tiles; adjacent clears break the chains.
func _build_chain_locks(ratio):
	return BOARD_MECHANICS.build_chain_locks(self, ratio)

func _chains_remaining():
	return BOARD_ENGINE.count_chains(board_chain)

func _dissolve_all_chains():
	return BOARD_MECHANICS.dissolve_all_chains(self)

func _fail_race_lost():
	return SPECIAL_SESSION._fail_race_lost(self)

func _break_chains_around(coords):
	return BOARD_MECHANICS.break_chains_around(self, coords)

# 重力: columns compact downward after clears.
func _apply_gravity():
	return BOARD_MECHANICS.apply_gravity(self)

func _update_fog():
	return BOARD_MECHANICS.update_fog(self)

func _pop_stack_at(coord):
	return BOARD_MECHANICS.pop_stack_at(self, coord)

# One successful match hits both tiles. Frozen cells (armor 1) crack instead
# of clearing and need a second match; cracked tiles keep blocking paths.
func _apply_match_damage(a, b):
	return BOARD_MECHANICS.apply_match_damage(self, a, b)

func _damage_tile(coord, cracked, removed = null):
	return BOARD_MECHANICS.damage_tile(self, coord, cracked, removed)



func _board_edge_path(a, b):
	return BOARD_ENGINE.edge_path(a, b)

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
	return UI_HUD.start_second_timer(self)






func _reset_combo():
	return UI_HUD._reset_combo(self)

func _update_combo_progress():
	return UI_HUD._update_combo_progress(self)




func _consume_time_cost(seconds):
	return SESSION._consume_time_cost(self, seconds)


func _on_time_up():
	return SESSION._on_time_up(self)

func _record_special_completion():
	return SPECIAL_SESSION._record_special_completion(self)


func _start_special_mode(mode_id):
	return SPECIAL_SESSION._start_special_mode(self, mode_id)

func _unlock_achievements(ids):
	return SESSION._unlock_achievements(self, ids)

func _exit_special_mode():
	return SPECIAL_SESSION._exit_special_mode(self)

func _apply_combo_gain(base_score):
	return SESSION._apply_combo_gain(self, base_score)

func _reset_level_session(level, reset_total = false):
	return SESSION._reset_level_session(self, level, reset_total)

func _fail_moves_exhausted():
	return SESSION._fail_moves_exhausted(self)

func _resolve_after_board_changed():
	return SESSION._resolve_after_board_changed(self)

func _resolve_special_clear():
	return SPECIAL_SESSION._resolve_special_clear(self)


func _remaining_tiles_count():
	return BOARD_ENGINE.count_tiles(board)

func _refresh_ui():
	UI_HUD.refresh_ui(self)


func _update_power_ups_display():
	return STATS_HUD.refresh_power_ups(self)

func _set_stat_text(key, value):
	STATS_HUD.set_text(self, key, value)

func _is_time_danger():
	return STATS_HUD.is_time_danger(self)

func _update_time_warning_pulse(_delta):
	STATS_HUD.pulse(self, _is_time_danger(), _delta)

func _set_time_card_state(is_danger):
	STATS_HUD.set_card_state(self, is_danger)

func _mode_label(mode):
	return SPECIAL_MODES_SCRIPT.mode_label(mode)


func _format_time(seconds):
	return BOARD_ENGINE.format_time(seconds)

func _format_time_seconds(time_seconds):
	return BOARD_ENGINE.format_time_seconds(time_seconds)

# Achievement system



func _status_label(status):
	return UI_HUD._status_label(self, status)

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

func _check_achievements_on_clear():
	return SESSION._check_achievements_on_clear(self)

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

# --- UI 面板回调与状态方法（Round D 从 ui_panels.gd 迁回；Round AL 生命周期收敛到 ui_panels）---
func _show_onboarding_if_needed():
	if progression_state.get(ONBOARDING_SEEN_KEY, false):
		return
	UI_PANELS.open_modal(self, onboarding_panel)

func _on_onboarding_dismissed():
	print("[Game] onboarding dismissed")
	UI_PANELS.close_modal(self, onboarding_panel)
	_patch_progress_state({ONBOARDING_SEEN_KEY: true})

func _on_settings_pressed():
	UI_PANELS.open_modal(self, settings_panel)

func _on_settings_close():
	UI_PANELS.close_modal(self, settings_panel)

func _on_master_volume_changed(value):
	AudioManager.set_master_volume(value)


func _on_music_toggled(enabled):
	AudioManager.set_music_enabled(enabled)

func _on_effects_toggled(enabled):
	return UI_PANELS._on_effects_toggled(self, enabled)

func _on_mute_toggled(muted):
	AudioManager.set_muted(muted)

func _on_achievements_pressed():
	UI_PANELS.reopen_achievements(self)
	UI_PANELS.open_modal(self, achievements_panel)

func _on_achievements_close():
	UI_PANELS.close_modal(self, achievements_panel)

func _refresh_modes_panel():
	UI_PANELS.refresh_modes_rows(self)

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
	UI_PANELS.refresh_pause_panel(self)

func _hide_pause_panel():
	UI_PANELS.hide_pause_panel(self)

func _on_restart_current_level():
	return UI_PANELS.restart_current_level(self)

func _on_back_to_first_level():
	return UI_PANELS.back_to_first_level(self)

# --- 多页面导航（page_router 的薄壳）---
func _on_nav_pressed(page_id):
	return PAGE_ROUTER.show_page(self, page_id)

func _on_nav_home_pressed():
	return PAGE_ROUTER.close_page(self)

func _on_map_level_pressed(level_index):
	PAGE_ROUTER.close_page(self)
	_start_level(level_index, true)
	_show_message("进入第%d关" % (level_index + 1), 1.0)

func _on_map_locked_pressed():
	_sync_level_select_selection()
	_show_message("该关卡尚未解锁", 0.9)

func _on_signin_claim_pressed(today, yesterday):
	ECONOMY.claim_signin(self, today, yesterday)

func _on_shop_use_pressed(set_index):
	ECONOMY.use_icon_set(self, set_index)

func _on_shop_buy_pressed(set_index):
	ECONOMY.buy_icon_set(self, set_index)

# --- 叠叠消（tile_match 的薄壳）---
func _on_tray_tile_pressed(tile_index):
	var result = TILE_MATCH.pick(tray_state, tile_index)
	if result == "match":
		_play_eliminate_effects([Vector2(2, 2)])
	if result == "cleared":
		_resolve_tray_clear()
	elif result == "lost":
		_fail_tray_full()
	TILE_MATCH.build_view(self)

func _on_tray_undo_pressed():
	TILE_MATCH.undo(tray_state)
	TILE_MATCH.build_view(self)

func _on_tray_shuffle_pressed():
	TILE_MATCH.shuffle(tray_state)
	TILE_MATCH.build_view(self)

func _resolve_tray_clear():
	return SPECIAL_SESSION._resolve_tray_clear(self)

func _fail_tray_full():
	return SPECIAL_SESSION._fail_tray_full(self)

func _on_revive_pressed():
	return SESSION._revive(self)

# --- 收集挑战 / 翻翻乐（薄壳）---
func _on_collect_pair_progress(patterns):
	return ECONOMY.collect_pair(self, patterns)

func _on_flip_card_pressed(card_index):
	var result = MEMORY_FLIP.flip(self, card_index)
	if result == "match":
		_play_eliminate_effects([Vector2(2, 2)])
	elif result == "miss":
		if flip_back_timer:
			flip_back_timer.start()
	if result == "cleared":
		_resolve_flip_clear()
		return
	MEMORY_FLIP.build_view(self)

func _on_flip_back_timeout():
	return MEMORY_FLIP.unflip_misses(self)

func _resolve_flip_clear():
	return SPECIAL_SPECIAL_SESSION._resolve_flip_clear(self)

func _resolve_collect_clear():
	return SPECIAL_SESSION._resolve_collect_clear(self)
