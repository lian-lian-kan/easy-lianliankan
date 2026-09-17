extends SceneTree

# 限时活动日历：周末判定、统一收益翻倍、节日查找、限定奖池领取状态。

const EVENTS = preload("res://scripts/content/events_calendar.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _date(year: int, month: int, day: int, weekday: int) -> Dictionary:
	return {"year": year, "month": month, "day": day, "weekday": weekday, "hour": 12}

func _init() -> void:
	print("== events_calendar_test")

	# --- weekend detection (Godot weekday: 0 = Sunday, 6 = Saturday)
	check(EVENTS.is_weekend(_date(2026, 9, 19, 6)), "Saturday is a weekend day")
	check(EVENTS.is_weekend(_date(2026, 9, 20, 0)), "Sunday is a weekend day")
	check(not EVENTS.is_weekend(_date(2026, 9, 16, 3)), "Wednesday is not")
	check(not EVENTS.is_weekend(_date(2026, 9, 18, 5)), "Friday is not")

	# --- unified earn hook
	check(EVENTS.apply_earn(_date(2026, 9, 16, 3), 20) == 20, "weekday earn is flat")
	check(EVENTS.apply_earn(_date(2026, 9, 19, 6), 20) == 40, "weekend earn doubles")
	check(EVENTS.apply_earn(_date(2026, 9, 19, 6), 9) == 18, "odd amounts round after doubling")
	check(EVENTS.apply_earn(_date(2026, 9, 16, 3), -5) == 0, "negative earns clamp to zero")
	check(EVENTS.is_multiplied(_date(2026, 9, 20, 0)), "is_multiplied agrees with the earn hook")

	# --- festival lookup
	var national = EVENTS.festival_for(_date(2026, 10, 1, 4))
	check(not national.empty() and str(national["name"]) == "国庆节", "Oct 1 resolves to 国庆节")
	check(int(national["chest"]) == 50, "national day chest pays 50")
	check(EVENTS.festival_for(_date(2026, 10, 2, 5)).empty(), "Oct 2 has no festival")
	check(EVENTS.FESTIVALS.size() == 10, "calendar carries 10 festivals")

	# --- countdown
	check(EVENTS.days_until_next_festival(_date(2026, 10, 1, 4)) == 0, "festival day is 0 days away")
	var from_sep20 = EVENTS.days_until_next_festival(_date(2026, 9, 20, 0))
	check(from_sep20 == 11, "Sep 20 counts 11 days to 国庆")
	check(EVENTS.days_until_next_festival(_date(2026, 1, 2, 5)) > 0, "post-New-Year finds the next festival")

	# --- limited chest claim state
	var state = {"event_chests": {"national": true}}
	check(EVENTS.chest_claimed(state, "national"), "claimed chest is claimed")
	check(not EVENTS.chest_claimed(state, "valentine"), "other chests stay closed")
	check(not EVENTS.chest_claimed({}, "national"), "no dict means nothing claimed")
	var patch = EVENTS.claim_patch("national")
	check(str(patch["event_chest"]) == "national" and patch.size() == 1, "claim patch carries the festival id")

	if failures == 0:
		print("events_calendar_test: ALL PASSED")
		quit(0)
	else:
		print("events_calendar_test: %d FAILURES" % failures)
		quit(1)
