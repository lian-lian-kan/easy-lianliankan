extends Reference

# Weekly missions: a fixed pool of five meta-goals that reset on a rolling
# seven-day cycle. Progress is earned across every play mode; claiming pays
# blossoms. The rolling week logic lives here so progression.gd stays a pure
# store — it only persists the whole weekly_missions dictionary verbatim.

const SPECIAL_MODES_SCRIPT = preload("res://scripts/modes/special_modes.gd")

# use_max=true means progress keeps the highest value seen (combo peaks);
# otherwise amounts accumulate additively.
const MISSIONS = {
	"pairs_30": {"desc": "消除 30 对棋子", "target": 30, "reward": 15, "use_max": false},
	"levels_5": {"desc": "通过 5 关（任意玩法）", "target": 5, "reward": 20, "use_max": false},
	"coins_100": {"desc": "赚取 100 🌸", "target": 100, "reward": 30, "use_max": false},
	"combo_5": {"desc": "达成 5 连击", "target": 5, "reward": 15, "use_max": true},
	"specials_3": {"desc": "完成 3 场特殊玩法", "target": 3, "reward": 25, "use_max": false}
}

const WEEK_SECONDS = 7 * 86400


# Rolling seven-day bucket, aligned to Unix epoch weeks. No weekday alignment
# needed — the point is just "same bucket within the week, new bucket after".
static func week_key_for(unix_seconds: int) -> String:
	return "W%d" % int(int(unix_seconds) / WEEK_SECONDS)


static func current_week_key(game) -> String:
	return week_key_for(OS.get_unix_time())


static func _empty_week(week_key: String) -> Dictionary:
	return {"week_key": week_key, "progress": {}, "claimed": []}


# Read the active week, resetting the stored state when the bucket rolled.
static func active_state(game) -> Dictionary:
	var week = current_week_key(game)
	var state = game.progression_state.get("weekly_missions", {})
	if typeof(state) != TYPE_DICTIONARY or str(state.get("week_key", "")) != week:
		state = _empty_week(week)
		game._patch_progress_state({"weekly_missions": state})
	return state


static func progress_of(state, task_id: String) -> int:
	return int(state.get("progress", {}).get(task_id, 0))


static func is_claimed(state, task_id: String) -> bool:
	return state.get("claimed", []).has(task_id)


static func is_complete(state, task_id: String) -> bool:
	return progress_of(state, task_id) >= int(MISSIONS[task_id]["target"])


# Record progress for one mission hook. Reaching the target caps the counter;
# claiming afterwards pays the reward (claim is what fires coins_delta).
static func record(game, task_id: String, amount: int):
	if not MISSIONS.has(task_id):
		return
	var state = active_state(game)
	if is_claimed(state, task_id):
		return
	var current = progress_of(state, task_id)
	var target = int(MISSIONS[task_id]["target"])
	var updated
	if bool(MISSIONS[task_id]["use_max"]):
		updated = max(current, amount)
	else:
		updated = min(current + amount, target)
	if updated == current:
		return
	state["progress"][task_id] = updated
	game._patch_progress_state({"weekly_missions": state})
	# One-shot nudge at the moment the target is reached (later records cap
	# out at updated == current and never re-enter this branch).
	if updated >= target and not is_claimed(state, task_id):
		game._show_message("📋 周任务达成：%s" % str(MISSIONS[task_id]["desc"]), 1.8)


static func claim(game, task_id: String):
	if not MISSIONS.has(task_id):
		return
	var state = active_state(game)
	if is_claimed(state, task_id) or not is_complete(state, task_id):
		return
	var reward = int(MISSIONS[task_id]["reward"])
	state["claimed"].append(task_id)
	game._patch_progress_state({"weekly_missions": state, "coins_delta": reward})
	game._show_message("任务完成！🌸+%d" % reward, 1.4)
	# Member access, not preload: economy.gd already preloads this module.
	game.ECONOMY.refresh_economy_page(game)


# --- Sign-in page section -----------------------------------------------

static func build_section(game, box):
	var state = active_state(game)
	var title = Label.new()
	title.text = "📋 周任务"
	title.add_font_override("font", game._font_at_size(15))
	title.add_color_override("font_color", Color("a85878"))
	box.add_child(title)
	for task_id in MISSIONS:
		box.add_child(_mission_row(game, task_id, state))


static func _mission_row(game, task_id: String, state):
	var mission: Dictionary = MISSIONS[task_id]
	var progress = progress_of(state, task_id)
	var target = int(mission["target"])
	var claimed = is_claimed(state, task_id)
	var done = progress >= target
	var row = PanelContainer.new()
	game._apply_glass_style(row, Color("ffffff"), 0.88)
	row.rect_min_size = Vector2(0, 44)
	var row_box = HBoxContainer.new()
	row_box.add_constant_override("separation", 8)
	row.add_child(row_box)
	var desc = Label.new()
	desc.text = str(mission["desc"])
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_font_override("font", game._font_at_size(13))
	desc.add_color_override("font_color", Color("5c3a4d"))
	row_box.add_child(desc)
	var status_text = ("🌸%d" % int(mission["reward"])) + (" · 已领" if claimed else (" · %d/%d" % [progress, target]))
	var status = Label.new()
	status.text = status_text
	status.align = Label.ALIGN_RIGHT
	status.add_font_override("font", game._font_at_size(12))
	status.add_color_override("font_color", Color("d6336c") if done and not claimed else Color("a85878"))
	row_box.add_child(status)
	if done and not claimed:
		var claim_button = Button.new()
		claim_button.text = "领取"
		claim_button.rect_min_size = Vector2(56, 24)
		claim_button.add_font_override("font", game._font_at_size(12))
		game._apply_button_style(claim_button, Color("f06ba8"), Color("d6336c"))
		claim_button.add_color_override("font_color", Color("ffffff"))
		claim_button.connect("pressed", game, "_on_mission_claim_pressed", [task_id])
		row_box.add_child(claim_button)
	return row
