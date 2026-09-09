extends Reference

const PAGE_ROUTER = preload("res://scripts/page_router.gd")
const HOME_SCREEN = preload("res://scripts/home_screen.gd")
const ECONOMY = preload("res://scripts/economy.gd")

# Main screen construction, extracted from gd so the 300+ line HUD/board
# layout lives beside the dialog factories in ui_panels.gd. Every call takes
# the live game node and assigns straight onto its members.

static func build_main_ui(game):
	return HOME_SCREEN.build_main_ui(game)



static func refresh_ui(game):
	ECONOMY.update_coin_label(game)
	var level = game._current_level()
	var level_id = int(level.get("id", game.level_index + 1))
	var level_name = str(level.get("name", "关卡"))
	var mode = str(level.get("mode", "classic"))
	var description = str(level.get("description", ""))
	var unlocked_level_count = int(game.progression_state.get("highest_unlocked_level_index", 0)) + 1

	game.title_label.text = "Sophia的连连看"
	if game.special_mode == "daily":
		var daily = game.progression_state.get("daily_challenge", {})
		var now_date = OS.get_date()
		var done_today = str(daily.get("last_date", "")) == game.SPECIAL_MODES_SCRIPT.date_string(now_date)
		game.subtitle_label.text = "每日挑战 · %d月%d日 · 连胜%d · 最佳%d · %s" % [
			int(now_date.month), int(now_date.day),
			int(daily.get("streak", 0)), int(daily.get("best_score", 0)),
			"今日已完成" if done_today else "今日未完成"
		]
	elif game.special_mode == "endless":
		var endless_best = game.progression_state.get("endless_best", {})
		game.subtitle_label.text = "无尽模式 · 第%d轮 · 最佳第%d轮 · 最高%d分" % [
			game.endless_round, int(endless_best.get("round", 0)), int(endless_best.get("score", 0))
		]
	elif game.special_mode == "time_attack":
		game.subtitle_label.text = "限时挑战 · 最佳%d分" % int(game.progression_state.get("time_attack_best_score", 0))
	elif game.special_mode == "memory":
		game.subtitle_label.text = "盲盒模式 · 最佳%d分" % int(game.progression_state.get("memory_best_score", 0))
	elif game.special_mode == "frost":
		game.subtitle_label.text = "冰雪挑战 · 最佳%d分" % int(game.progression_state.get("frost_best_score", 0))
	elif game.special_mode == "zen":
		game.subtitle_label.text = "休闲模式 · 最佳%d分" % int(game.progression_state.get("zen_best_score", 0))
	elif game.special_mode == "hell":
		game.subtitle_label.text = "地狱模式 · 最佳%d分" % int(game.progression_state.get("hell_best_score", 0))
	elif game.special_mode == "moves":
		game.subtitle_label.text = "步数挑战 · 最佳%d分 · 剩余%d步" % [int(game.progression_state.get("moves_best_score", 0)), game.moves_left]
	elif game.special_mode == "race":
		game.subtitle_label.text = "竞速对战 · 最佳%d分" % int(game.progression_state.get("race_best_score", 0))
	elif game.special_mode == "stack":
		game.subtitle_label.text = "叠层模式 · 最佳%d分" % int(game.progression_state.get("stack_best_score", 0))
	elif game.special_mode == "gravity":
		game.subtitle_label.text = "重力模式 · 最佳%d分" % int(game.progression_state.get("gravity_best_score", 0))
	elif game.special_mode == "fog":
		game.subtitle_label.text = "迷雾模式 · 最佳%d分" % int(game.progression_state.get("fog_best_score", 0))
	elif game.special_mode == "chain":
		game.subtitle_label.text = "锁链模式 · 最佳%d分" % int(game.progression_state.get("chain_best_score", 0))
	else:
		game.subtitle_label.text = "第" + str(level_id) + "/" + str(game.campaign_levels.size()) + "关 · " + level_name + " · 已解锁" + str(unlocked_level_count) + "/" + str(game.campaign_levels.size())
	game.desc_label.text = description

	game.status_chip_label.text = game._status_label(game.stage_status)
	# Update status chip style based on status
	var status_style = StyleBoxFlat.new()
	status_style.set_corner_radius_all(16)
	if game.stage_status == game.STATUS_PLAYING:
		game.status_chip_label.add_color_override("font_color", Color("0ca678"))
		status_style.bg_color = Color("e6fcf5")
	elif game.stage_status == game.STATUS_PAUSED:
		game.status_chip_label.add_color_override("font_color", Color("e67700"))
		status_style.bg_color = Color("fff3bf")
	elif game.stage_status == game.STATUS_CLEARED:
		game.status_chip_label.add_color_override("font_color", Color("e64980"))
		status_style.bg_color = Color("ffe3ef")
	elif game.stage_status == game.STATUS_FAILED:
		game.status_chip_label.add_color_override("font_color", Color("f06565"))
		status_style.bg_color = Color("ffe3e3")
	else:
		game.status_chip_label.add_color_override("font_color", Color("0ca678"))
		status_style.bg_color = Color("e6fcf5")
	game.status_chip_label.add_stylebox_override("normal", status_style)

	game.mode_chip_label.text = "模式：" + game._mode_label(mode)
	game.kinds_chip_label.text = "图案种类：" + str(level.get("kinds", 0))

	game.level_progress_bar.value = (float(game.level_index + 1) / float(max(1, game.campaign_levels.size()))) * 100.0
	if game.special_mode != "":
		game.level_progress_bar.value = 100.0

	game._set_stat_text("total_score", str(game.total_score))
	game._set_stat_text("level_score", str(game.level_score))
	game._set_stat_text("moves", str(game.moves))
	game._set_stat_text("remaining", str(game._remaining_tiles_count() / 2))
	game._set_stat_text("time_left", "∞" if int(game._current_level().get("time_limit", 90)) <= 0 else game._format_time(game.time_left))
	game._set_stat_text("combo", "x" + str(max(game.combo, 1)))
	game._set_stat_text("best_total_score", str(game._progress_best_score()))
	game._set_stat_text("best_combo", "x" + str(game._progress_best_combo()))

	# 对手 card only shows during the AI race.
	if game.stat_values.has("race"):
		game.stat_values["race"]["card"].visible = game.special_mode == "race"
		game._set_stat_text("race", "%d/%d" % [game.race_ai_pairs, game.race_total_pairs])

	game._update_fog()
	game._set_time_card_state(game._is_time_danger())

	var input_enabled = game.stage_status == game.STATUS_PLAYING
	game.hint_button.disabled = not input_enabled
	game.auto_button.disabled = not input_enabled
	game.shuffle_button.disabled = not input_enabled
	if game.level_select_option:
		game.level_select_option.disabled = game.campaign_levels.size() <= 1
	var selected_level_index = game._selected_level_option_index()
	var can_jump = selected_level_index != game.level_index and game._is_level_unlocked(selected_level_index)
	if game.jump_level_button:
		game.jump_level_button.disabled = not can_jump
	if game.clear_progress_button:
		game.clear_progress_button.disabled = false
	var pause_enabled = game.stage_status == game.STATUS_PLAYING or game.stage_status == game.STATUS_PAUSED
	game.pause_button.disabled = not pause_enabled
	game.pause_button.text = "继续" if game.stage_status == game.STATUS_PAUSED else "暂停"

	if game.stage_status == game.STATUS_COMPLETED:
		game.reset_button.text = "再来一轮"
	else:
		game.reset_button.text = "重开"

	# Update power-ups display
	game._update_power_ups_display()

# --- Timers and message/banner helpers (migrated from game.gd) ---

static func _show_message(game, text, duration_sec = 1.0):
	game.message_label.text = text
	game.message_label.visible = true
	game.message_timer.stop()
	game.message_timer.wait_time = max(0.1, duration_sec)
	game.message_timer.start()

static func _hide_message(game):
	game.message_label.visible = false
	game.message_timer.stop()

static func _show_stage_callout(game, text, color, font_size):
	var label = Label.new()
	label.text = text
	label.add_font_override("font", game._font_at_size(font_size))
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
	game.add_child(label)

	var tween = game._make_fx_tween(label)
	tween.interpolate_property(label, "margin_top", 150.0, 116.0, 0.35, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(label, "modulate:a", 0.0, 0.95, 0.2, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(label, "modulate:a", 0.95, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.1)
	tween.start()


# --- Control factories and notifications (migrated from game.gd) ---

static func _create_control_button(game, text):
	var button = Button.new()
	button.add_font_override("font", game.game_font)
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

static func _populate_level_select_options(game):
	if game.level_select_option == null:
		return

	game.level_select_option.clear()
	var best_times = game.progression_state.get("level_best_times", {})
	for i in range(game.campaign_levels.size()):
		var level: Dictionary = game.campaign_levels[i]
		var level_id = int(level.get("id", i + 1))
		var level_name = str(level.get("name", "关卡"))
		var unlocked = game._is_level_unlocked(i)
		var label = "第" + str(level_id) + "关 · " + level_name
		# Add best time if available
		if best_times.has(str(i)):
			var best_time = float(best_times[str(i)])
			label += " ⏱️" + game._format_time_seconds(best_time)
		if not unlocked:
			label += "（未解锁）"
		game.level_select_option.add_item(label)
		game.level_select_option.set_item_disabled(i, not unlocked)

	game.level_select_option.disabled = game.campaign_levels.size() <= 1
	game._sync_level_select_selection()

static func _show_achievement_notification(game, achievement_name):
	# Create floating achievement notification
	var notification = PanelContainer.new()
	notification.set_anchors_and_margins_preset(Control.PRESET_CENTER_TOP)
	notification.margin_top = 60
	game._apply_glass_style(notification, Color("fff3bf"), 0.95)
	game.add_child(notification)

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
	label.add_font_override("font", game.game_font)
	margin.add_child(label)

	# Auto-dismiss after animation
	var dismiss_timer = Timer.new()
	dismiss_timer.one_shot = true
	dismiss_timer.wait_time = 2.5
	dismiss_timer.connect("timeout", game, "_on_achievement_dismiss", [notification])
	game.add_child(dismiss_timer)
	dismiss_timer.start()


static func _status_label(game, status):
	match status:
		game.STATUS_PLAYING:
			return "进行中"
		game.STATUS_PAUSED:
			return "已暂停"
		game.STATUS_CLEARED:
			return "过关中"
		game.STATUS_FAILED:
			return "失败"
		game.STATUS_COMPLETED:
			return "全通关"
		_:
			return "未知"


# --- Level select state glue (migrated from game.gd) ---

static func _selected_level_option_index(game):
	if game.level_select_option == null or game.level_select_option.get_item_count() == 0:
		return game.level_index
	var selected_idx = int(game.level_select_option.get_selected_id())
	if selected_idx < 0:
		selected_idx = game.level_index
	return clamp(selected_idx, 0, game.campaign_levels.size() - 1)


static func _sync_level_select_selection(game):
	if game.level_select_option == null or game.level_select_option.get_item_count() == 0:
		return
	game.level_select_option.select(game.level_index)


static func _level_label_by_index(game, level_idx):
	var clamped = clamp(level_idx, 0, game.campaign_levels.size() - 1)
	var level: Dictionary = game.campaign_levels[clamped]
	return "第" + str(int(level.get("id", clamped + 1))) + "关 · " + str(level.get("name", "关卡"))


static func _on_level_select_changed(game, index):
	if not game._is_level_unlocked(index):
		game._sync_level_select_selection()
		game._show_message("该关卡尚未解锁", 0.9)
		return
	game._refresh_ui()


static func _trigger_level_highlight(game):
	if game.level_select_option == null:
		return
	game.level_select_option.modulate = game.LEVEL_HIGHLIGHT_COLOR
	game.level_highlight_timer.stop()
	game.level_highlight_timer.wait_time = 0.4
	game.level_highlight_timer.start()


# --- Combo progress bar state (migrated from game.gd) ---

static func _reset_combo(game):
	game.combo = 0
	game.combo_expires_ms = 0
	game.combo_progress_bar.value = 0
	game.combo_reset_timer.stop()


static func _update_combo_progress(game):
	if game.stage_status != game.STATUS_PLAYING or game.combo <= 0:
		game.combo_progress_bar.value = 0
		return

	var remain = max(0, game.combo_expires_ms - OS.get_ticks_msec())
	var window_ms = max(1, int(game.tuning.get("combo_window_ms", 2600)))
	var progress = (float(remain) / float(window_ms)) * 100.0
	game.combo_progress_bar.value = progress



static func start_second_timer(game):
	game.second_timer.stop()
	game.second_timer.start()
