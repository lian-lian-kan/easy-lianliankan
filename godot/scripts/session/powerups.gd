extends Reference

# Power-up domain: loadout rules per level/mode, the arm/use/spend flow,
# and the click-targeted executions. Statics take the live game node.

const LOADOUT = preload("res://scripts/session/powerup_loadout.gd")

# Friendly fixed loadout for special sessions: base grants for everyone,
# per-mode extras, and per-mode overrides (hell strips back to basics).
# New modes need no code here — just a row in powerup_loadout.gd's
# SPECIAL_LOADOUT_EXTRA.
static func _init_power_ups(game, level):
	# Reset power-ups
	game.power_ups = LOADOUT.resolve(int(level.get("id", 1)), str(level.get("mode", "classic")), game._is_special_session(), game.special_mode)
	game.bomb_pending = false
	game.rainbow_pending = false
	game.frost_pending = false
	game.frost_uses = 0


# Re-press cancels an armed click-targeted power-up and refunds the
# charge: nothing is spent until the bomb/rainbow/patch actually lands.
const RECALL_MESSAGES = {"bomb": "已收回炸弹", "rainbow": "已收回彩虹", "warm_patch": "已收回暖宝宝"}
const ARMED_FLAG_BY_TYPE = {"bomb": "bomb_pending", "rainbow": "rainbow_pending", "warm_patch": "frost_pending"}

static func _use_power_up(game, power_up_type):
	if _recall_armed(game, power_up_type):
		return
	if game.power_ups.get(power_up_type, 0) <= 0:
		return
	if game.stage_status != game.STATUS_PLAYING:
		return
	if power_up_type == "time_sand" and game.special_mode == "endless":
		game._show_message("无尽模式没有时间限制", 1.0)
		return
	if power_up_type == "warm_patch" and not game._is_frost_mode():
		game._show_message("暖宝宝只有冰雪模式用得上", 1.0)
		return

	game.call("_activate_" + power_up_type)

	game.power_ups[power_up_type] -= 1
	game._refresh_ui()
	game.audio.play_button_click()

# Re-pressing an armed type disarms it; rainbow also drops the selection.
static func _recall_armed(game, power_up_type) -> bool:
	var armed_flag = ARMED_FLAG_BY_TYPE.get(power_up_type)
	if armed_flag == null or not game.get(armed_flag):
		return false
	game.set(armed_flag, false)
	if power_up_type == "rainbow":
		game.selected = Vector2(-1, -1)
	game.power_ups[power_up_type] += 1
	game._show_message(RECALL_MESSAGES[power_up_type], 0.8)
	game._refresh_ui()
	game._refresh_board_visuals()
	return true

static func _activate_time_freeze(game):
	game.time_frozen = true
	game._show_message("⏱️ 时间冻结！", 1.5)
	if game.time_freeze_timer:
		game.time_freeze_timer.stop()
		game.time_freeze_timer.wait_time = 5.0
		game.time_freeze_timer.start()

static func _activate_auto_match(game):
	if game._is_target_mode():
		game._show_message("✨ 指定连消没有自动消，看准金光！", 1.2)
		return
	var hint = game._find_any_hint(game.board)
	if hint.empty():
		game._show_message("没有可自动消除的对子", 1.0)
		return
	var a = hint["a"]
	var b = hint["b"]
	var button_a = game._try_get_tile_button(a)
	var button_b = game._try_get_tile_button(b)
	if button_a == null or button_b == null:
		return
	game.selected = a
	game._on_tile_pressed(button_a)
	yield(game.get_tree().create_timer(0.2), "timeout")
	game._on_tile_pressed(button_b)

static func _activate_reshuffle(game):
	game._reshuffle_board(game.board)
	game._show_message("🔄 棋盘已重排", 1.0)
	game._refresh_board_visuals()

static func _activate_magnifier(game):
	# Highlight up to 3 connectable pairs; in memory mode they also flip over.
	var working = []
	for row in game.board:
		working.append(row.duplicate())
	var coords = []
	for _i in range(3):
		var hint = game._find_any_hint(working)
		if hint.empty():
			break
		coords.append(hint["a"])
		coords.append(hint["b"])
		working[hint["a"].x][hint["a"].y] = 0
		working[hint["b"].x][hint["b"].y] = 0
	if coords.empty():
		game._show_message("没有可以高亮的对子", 1.0)
		return
	game.hint_tiles = coords
	for coord in coords:
		if game._is_memory_mode():
			game.memory_revealed[game._memory_key(coord)] = true
	game._animate_hint_tiles(coords)
	game._show_message("🔍 放大镜：高亮 %d 组可消对子" % int(coords.size() / 2.0), 1.4)
	game._refresh_board_visuals()

static func _activate_time_sand(game):
	game.time_left = min(999, game.time_left + 15)
	game._show_message("⏳ 时光沙漏：时间 +15 秒", 1.4)
	game._refresh_ui()

static func _activate_bomb(game):
	game.bomb_pending = true
	game.rainbow_pending = false
	game.frost_pending = false
	game.selected = Vector2(-1, -1)
	game._show_message("💥 炸弹已就绪：点击任意方块，与它的同伴一起消失", 2.6)
	game._refresh_board_visuals()

static func _activate_rainbow(game):
	game.rainbow_pending = true
	game.bomb_pending = false
	game.frost_pending = false
	game.selected = Vector2(-1, -1)
	game._show_message("🌈 彩虹已就绪：点击两枚方块，图案不同也能消除", 2.6)
	game._refresh_board_visuals()

static func _activate_warm_patch(game):
	game.frost_pending = true
	game.bomb_pending = false
	game.rainbow_pending = false
	game.selected = Vector2(-1, -1)
	game._show_message("🔥 暖宝宝已就绪：点一块结霜的方块解冻", 2.6)
	game._refresh_board_visuals()

static func _execute_warm_patch(game, point):
	# Not-ice target: stay armed so the charge isn't wasted on a misclick.
	if int(game.board_armor[point.x][point.y]) <= 0:
		game._show_message("这块没有结冰，选一块淡蓝色的冰", 1.3)
		return
	game.frost_pending = false
	game.frost_uses += 1
	game.board_armor[point.x][point.y] = 0
	game.audio.play_hint()
	game._play_eliminate_effects([point])
	game._show_message("🔥 冰融化了！", 1.1)
	game._refresh_ui()
	game._refresh_board_visuals()

# The bomb partner: first other tile carrying the same pattern value.
static func _find_kind_partner(game, point):
	var kind = int(game.board[point.x][point.y])
	for r in range(game.board.size()):
		for c in range(game.board[r].size()):
			if int(game.board[r][c]) == kind and not (r == point.x and c == point.y):
				return Vector2(r, c)
	return Vector2(-1, -1)

# 炸弹顺便炸开相邻的石头牌（障碍模式的核心开路手段）。
static func _shatter_rocks_around(game, cells):
	for cell in cells:
		for nr in range(max(0, cell.x - 1), min(game.board.size(), cell.x + 2)):
			for nc in range(max(0, cell.y - 1), min(game.board[0].size(), cell.y + 2)):
				if game.BOARD_ENGINE.is_rock_value(game.board[nr][nc]):
					game.board[nr][nc] = 0

# Shared pair destruction: clear selection, spend a move, path preview,
# effects, combo score, pierce ice in frost mode, pop stacks, break chains
# and resolve the board. Both click-targeted pair powers funnel here.
static func _destroy_pair(game, a, b, shatter_rocks = false):
	game.selected = Vector2(-1, -1)
	game.hint_tiles.clear()
	game.error_tiles.clear()
	game.moves += 1

	game._show_path(game._board_edge_path(a, b), "eliminate", int(game.tuning.get("path_preview_ms", 420)))
	game._play_eliminate_effects([a, b])
	game._apply_combo_gain(int(game.tuning.get("base_score", 10)))

	game.board[a.x][a.y] = 0
	game.board[b.x][b.y] = 0
	if game._is_frost_mode():
		# Explosions and rainbow light both shatter ice along with the tile.
		game.board_armor[a.x][a.y] = 0
		game.board_armor[b.x][b.y] = 0
	if shatter_rocks and game._is_rock_mode():
		_shatter_rocks_around(game, [a, b])
	game._pop_stack_at(a)
	game._pop_stack_at(b)
	game._break_chains_around([a, b])
	game._consume_move()

	game._refresh_ui()
	game._refresh_board_visuals()
	game._resolve_after_board_changed()

static func _execute_bomb(game, point):
	if not game._is_coord_playable(point):
		game._show_message("这块消不掉，先解锁/驱雾再炸", 1.2)
		return
	var partner = _find_kind_partner(game, point)
	game.bomb_pending = false
	if partner.x < 0:
		game.power_ups["bomb"] += 1
		game._show_message("没有可配对的方块，炸弹已退回", 1.2)
		return
	game.audio.play_shuffle()
	game._show_message("💥 轰！", 0.8)
	_destroy_pair(game, point, partner, true)

static func _execute_rainbow_click(game, point):
	if not game._is_coord_playable(point):
		game._show_message("这块消不掉，先解锁/驱雾再选", 1.2)
		return
	if game.selected.x < 0:
		game.selected = point
		game.hint_tiles.clear()
		game.audio.play_select()
		game._animate_select(point)
		game._refresh_board_visuals()
		return
	if game.selected == point:
		game.selected = Vector2(-1, -1)
		game._refresh_board_visuals()
		return
	var a = game.selected
	game.rainbow_pending = false
	game.audio.play_eliminate_combo(game.combo)
	game._show_message("🌈 彩虹消除 +✨", 0.9)
	_destroy_pair(game, a, point)

