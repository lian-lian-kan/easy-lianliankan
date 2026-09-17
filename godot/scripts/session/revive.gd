extends Reference

# Campaign fail/revive flow: the husband rescue gimmick, clock/move drain
# guards, and the paid revival that restores the stage. Extracted from
# session.gd; every function takes the live game node and routes sound and
# input through it.

# Husband rescue: the product gimmick. When time runs short the floating
# button appears; calling the husband once per round grants +15 seconds and
# a free pair hint (without charging the hint counter), wrapped in a
# doting one-liner.
static func call_husband(game):
	if game.husband_called or game.stage_status != game.STATUS_PLAYING:
		return
	game.husband_called = true
	game.time_left = min(999, game.time_left + 15)
	game.audio.play_hint()
	var hint = game._find_any_hint(game.board)
	if hint.empty():
		game._reshuffle_board(game.board)
		hint = game._find_any_hint(game.board)
	game.GAME_INPUT.reveal_hint_pair(game, hint)
	game._show_message(game.CHEERS.husband_line(game) + " · ⏰+15 秒", 2.2)


static func _consume_time_cost(game, seconds):
	# Clockless modes (endless/zen/moves/race) carry time_limit 0, so there is
	# nothing to drain; guard against a divide of the clock into negatives.
	if int(game._current_level().get("time_limit", 90)) <= 0:
		return
	# 攀登树工具清风：本层提示/自动/洗牌不耗时。
	if game._is_tree_mode() and game.TREE_BUFFS.tools_free(game.get("tree_buffs")):
		return
	if seconds <= 0 or game.stage_status != game.STATUS_PLAYING:
		return

	game.time_left = max(0, game.time_left - seconds)
	game._refresh_ui()
	if game.time_left == 0:
		game._on_time_up()


static func _consume_move(game):
	if game.special_mode != "moves" or game.stage_status != game.STATUS_PLAYING:
		return
	game.moves_left = max(0, game.moves_left - 1)
	game._refresh_ui()
	if game.moves_left <= 0 and game._remaining_tiles_count() > 0:
		game._fail_moves_exhausted()


static func _offer_revive(game, cost):
	# Blossom revival keeps the board as-is: only the resources return.
	game.revive_cost = cost
	if game.revive_button:
		game.revive_button.visible = coins_can_afford(game, cost)

static func coins_can_afford(game, cost):
	return int(game.progression_state.get("coins", 0)) >= cost

static func _revive(game):
	var cost = int(game.revive_cost)
	if game.stage_status != game.STATUS_FAILED or not coins_can_afford(game, cost):
		if game.revive_button:
			game.revive_button.visible = false
		return
	game._patch_progress_state({"coins_delta": -cost})
	if game.time_left <= 0:
		game.time_left = int(max(30.0, float(game._current_level().get("time_limit", 60)) * 0.25))
	if game.moves_left > 0 or game._current_level().has("move_budget"):
		game.moves_left = max(game.moves_left, 5)
	game.stage_status = game.STATUS_PLAYING
	if game.revive_button:
		game.revive_button.visible = false
	game.stage_panel_label.visible = false
	game._start_second_timer()
	game._show_message("复活成功！继续加油", 1.4)
	game._refresh_ui()
	game._refresh_board_visuals()

