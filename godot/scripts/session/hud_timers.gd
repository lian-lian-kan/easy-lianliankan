extends Reference

# Session heartbeat: timer factory and every callback the timers drive
# (clock ticks, message/error/combo/highlight timeouts, level advance,
# freeze thaw, memory preview/hide, race AI). Extracted from ui_hud.gd
# so the main-screen module stays build/refresh/layout only.

# Timer inventory: member name -> spec. Default wait 1.0 / auto-repeat
# unless overridden; order matches the original build order.
const TIMER_SPECS = {
	"second_timer": {"wait": 1.0, "repeats": true, "callback": "_on_second_tick"},
	"message_timer": {"callback": "_on_message_timeout"},
	"error_timer": {"callback": "_on_error_timeout"},
	"combo_reset_timer": {"callback": "_on_combo_reset_timeout"},
	"level_highlight_timer": {"callback": "_on_level_highlight_timeout"},
	"level_advance_timer": {"callback": "_on_level_advance_timeout"},
	"time_freeze_timer": {"callback": "_on_time_freeze_timeout"},
	"memory_preview_timer": {"callback": "_on_memory_preview_timeout"},
	"memory_hide_timer": {"callback": "_on_memory_hide_timeout"},
	"flip_back_timer": {"wait": 0.7, "callback": "_on_flip_back_timeout"},
	"race_timer": {"wait": 1.0, "repeats": true, "callback": "_on_race_tick"},
}

static func _build_timers(game):
	for timer_name in TIMER_SPECS:
		var spec = TIMER_SPECS[timer_name]
		var timer = Timer.new()
		timer.wait_time = float(spec.get("wait", 1.0))
		timer.one_shot = not bool(spec.get("repeats", false))
		timer.connect("timeout", game, spec["callback"])
		game.add_child(timer)
		game.set(timer_name, timer)

static func _on_second_tick(game):
	if game.stage_status != game.STATUS_PLAYING:
		return

	if game.time_frozen:
		return

	# Endless/zen/moves/race have no countdown clock at all.
	if game.special_mode == "endless" or int(game._current_level().get("time_limit", 90)) <= 0:
		return

	game.time_left = max(0, game.time_left - 1)
	game._refresh_ui()

	if game.time_left <= 0:
		game._on_time_up()

static func _on_race_tick(game):
	if game.special_mode != "race" or game.stage_status != game.STATUS_PLAYING:
		return
	var interval = max(1.0, float(game._current_level().get("ai_interval", 8.5)))
	game.race_elapsed += 1
	if game.race_elapsed < int(interval):
		return
	game.race_elapsed = 0
	game.race_ai_pairs = min(game.race_total_pairs, game.race_ai_pairs + 1)
	AudioManager.play_select()
	game._refresh_ui()
	if game.race_ai_pairs >= game.race_total_pairs:
		game._fail_race_lost()

static func _on_message_timeout(game):
	game.message_label.visible = false

static func _on_error_timeout(game):
	game.error_tiles.clear()
	game._refresh_board_visuals()

static func _on_combo_reset_timeout(game):
	game._reset_combo()
	game._refresh_ui()

static func _on_level_highlight_timeout(game):
	if game.level_select_option != null:
		game.level_select_option.modulate = game.LEVEL_NORMAL_COLOR

static func _on_level_advance_timeout(game):
	if game.stage_status != game.STATUS_CLEARED:
		return
	if game.special_mode == "endless":
		# Next endless round keeps the running total score.
		game._reset_level_session(game.special_level, false)
		game._show_message("第" + str(game.endless_round) + "轮开始", 1.2)
		return
	if game.pending_level_index < 0:
		return

	var next_index = game.pending_level_index
	game.pending_level_index = -1
	game._start_level(next_index, false)

static func _on_time_freeze_timeout(game):
	game.time_frozen = false
	game._show_message("时间恢复流逝", 1.0)

# Memory preview/hide timeouts live in session.gd with the memory session
# domain; hud_timers only owns the generic heartbeat callbacks.
