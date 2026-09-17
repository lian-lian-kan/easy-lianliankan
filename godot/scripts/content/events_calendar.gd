extends Reference

# 限时活动日历：周末双倍樱花 + 固定节日限定奖池。Pure date math — the events
# page (page_router) and the earn hooks (economy / special_session) consume
# these helpers; everything is deterministic from the calendar date.

const WEEKEND_MULT = 2.0

# Solar-date festivals: "month-day" -> limited chest. One claim per festival
# id per save (the limited pool; next year the id list is extended with the
# year prefix if the design ever needs per-year chests).
const FESTIVALS = {
	"1-1": {"id": "newyear", "name": "元旦", "emoji": "🎊", "chest": 30},
	"2-14": {"id": "valentine", "name": "情人节", "emoji": "💝", "chest": 30},
	"3-8": {"id": "goddess", "name": "女神节", "emoji": "🌷", "chest": 30},
	"5-1": {"id": "labour", "name": "劳动节", "emoji": "🛠️", "chest": 30},
	"6-1": {"id": "children", "name": "儿童节", "emoji": "🧸", "chest": 30},
	"9-10": {"id": "teacher", "name": "教师节", "emoji": "📚", "chest": 30},
	"10-1": {"id": "national", "name": "国庆节", "emoji": "🎉", "chest": 50},
	"12-24": {"id": "christmas_eve", "name": "平安夜", "emoji": "🎄", "chest": 30},
	"12-25": {"id": "christmas", "name": "圣诞节", "emoji": "🎄", "chest": 30},
	"12-31": {"id": "countdown", "name": "跨年夜", "emoji": "🎆", "chest": 50},
}

# Godot weekday: 0 = Sunday, 6 = Saturday.
static func is_weekend(date) -> bool:
	var weekday = int(date.weekday)
	return weekday == 0 or weekday == 6

# Central earn hook: every blossom income path funnels through this so the
# weekend doubles land exactly once, in one place.
static func apply_earn(date, amount: int) -> int:
	var reward = max(0, int(amount))
	if is_weekend(date):
		reward = int(round(float(reward) * WEEKEND_MULT))
	return reward

static func is_multiplied(date) -> bool:
	return is_weekend(date)

static func festival_for(date) -> Dictionary:
	var key = "%d-%d" % [int(date.month), int(date.day)]
	return FESTIVALS.get(key, {})

# Days until the next festival (0 = today); -1 keeps the "all passed this
# year" tail honest — callers then point at next year's New Year.
static func days_until_next_festival(date) -> int:
	var today_epoch = _epoch_of(date)
	for offset in range(0, 367):
		var probe = OS.get_datetime_from_unix_time(today_epoch + offset * 86400)
		if not festival_for(probe).empty():
			return offset
	return -1

static func _epoch_of(date) -> int:
	var stamp = {
		"year": int(date.year), "month": int(date.month), "day": int(date.day),
		"weekday": 0, "hour": 12, "minute": 0, "second": 0
	}
	return int(OS.get_unix_time_from_datetime(stamp))

# --- Limited chest claim state (per save) ---

static func chest_claimed(state, festival_id) -> bool:
	var chests = state.get("event_chests", {})
	return typeof(chests) == TYPE_DICTIONARY and chests.has(str(festival_id))

# Progress-patch fragment for claiming a festival chest; progression.gd's
# _apply_meta_economy folds it into the event_chests dict.
static func claim_patch(festival_id) -> Dictionary:
	return {"event_chest": str(festival_id)}
