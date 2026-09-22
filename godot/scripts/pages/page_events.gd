extends Reference

# 活动页（page_router 的内容分册）：周末双倍樱花 / 节日限定奖池 / 节日
# 日历，数据全部来自 events_calendar.gd。页面路由与开关在 page_router.gd。

const PAGE_UI = preload("res://scripts/pages/page_ui.gd")
const EVENTS = preload("res://scripts/content/events_calendar.gd")

static func _build_events(game):
	var page_content = game.page_content
	PAGE_UI.page_frame(game, page_content, "🎉 活动", "限时活动与限定奖励")
	var box = PAGE_UI.scroll_area(game, page_content)
	var today = OS.get_date()
	_build_events_weekend(game, box, today)
	_build_events_festival(game, box, today)
	_build_events_calendar(game, box, today)

static func _build_events_weekend(game, box, today):
	var weekend_box = _event_card(game, "🌈 周末双倍樱花")
	var weekend_status = Label.new()
	if EVENTS.is_weekend(today):
		weekend_status.text = "进行中！今天所有樱花入账 x2（关卡/玩法/里程碑通用）"
		weekend_status.add_color_override("font_color", Color("2f9e44"))
	else:
		var days = (6 - int(today.weekday)) % 7
		weekend_status.text = "休息中 · %d 天后开启（周六、周日入账 x2）" % days
		weekend_status.add_color_override("font_color", Color("8f6b80"))
	weekend_status.autowrap = true
	weekend_status.add_font_override("font", game._font_at_size(13))
	weekend_box.add_child(weekend_status)
	box.add_child(weekend_box.get_parent())

static func _build_events_festival(game, box, today):
	var festival = EVENTS.festival_for(today)
	if festival.empty():
		box.add_child(_quiet_day_card(game, today))
		return
	box.add_child(_festival_card(game, festival))

# 没有节日的普通日子：一张「今日限定」空卡，带下一个活动的倒计时。
static func _quiet_day_card(game, today):
	var next_days = EVENTS.days_until_next_festival(today)
	var quiet_box = _event_card(game, "🎈 今日限定")
	var quiet_label = Label.new()
	quiet_label.text = "今天没有节日活动" + ("，下一个活动在 %d 天后" % next_days if next_days >= 0 else "")
	quiet_label.autowrap = true
	quiet_label.add_font_override("font", game._font_at_size(13))
	quiet_label.add_color_override("font_color", Color("8f6b80"))
	quiet_box.add_child(quiet_label)
	return quiet_box.get_parent()

# 节日奖池卡：礼盒数值 + 已领打勾或领取主按钮（每存档限领一次）。
static func _festival_card(game, festival):
	var fest_box = _event_card(game, "%s %s · 限定奖池" % [str(festival["emoji"]), str(festival["name"])])
	var fest_label = Label.new()
	fest_label.text = "今日限定礼盒 🌸x%d，每个存档限领一次" % int(festival["chest"])
	fest_label.autowrap = true
	fest_label.add_font_override("font", game._font_at_size(13))
	fest_label.add_color_override("font_color", Color("8f6b80"))
	fest_box.add_child(fest_label)
	if EVENTS.chest_claimed(game.progression_state, festival["id"]):
		var claimed = Label.new()
		claimed.text = "✓ 已领取，明年节日再见"
		claimed.add_font_override("font", game._font_at_size(13))
		claimed.add_color_override("font_color", Color("0ca678"))
		fest_box.add_child(claimed)
	else:
		fest_box.add_child(_claim_button(game, festival))
	return fest_box.get_parent()

static func _claim_button(game, festival):
	var claim = Button.new()
	claim.text = "🎁 领取限定礼盒"
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim.rect_min_size = Vector2(0, 40)
	claim.add_font_override("font", game.game_font)
	claim.connect("pressed", game, "_on_event_chest_claimed", [str(festival["id"]), int(festival["chest"])])
	game._style_dialog_buttons(claim)
	return claim

static func _build_events_calendar(game, box, today):
	var upcoming_box = _event_card(game, "📅 节日日历")
	for entry in _upcoming_festivals(today, 3):
		var row = Label.new()
		row.text = "%s %s · %d月%d日（%s）" % [str(entry["emoji"]), str(entry["name"]), int(entry["month"]), int(entry["day"]), entry["when"]]
		row.add_font_override("font", game._font_at_size(13))
		row.add_color_override("font_color", Color("5c3a4d"))
		upcoming_box.add_child(row)
	box.add_child(upcoming_box.get_parent())

static func _event_card(game, title_text):
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("ffffff")
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color("f09ebb")
	card.add_stylebox_override("panel", style)
	var card_box = VBoxContainer.new()
	card_box.add_constant_override("separation", 8)
	card.add_child(card_box)
	var title = Label.new()
	title.text = title_text
	title.add_font_override("font", game._font_at_size(15))
	title.add_color_override("font_color", Color("a85878"))
	card_box.add_child(title)
	return card_box

# Next `count` festivals from today (today inclusive, marked 今日).
static func _upcoming_festivals(today, count):
	var found = []
	var epoch_today = EVENTS._epoch_of(today)
	for offset in range(0, 367):
		var probe = OS.get_datetime_from_unix_time(epoch_today + offset * 86400)
		var festival = EVENTS.festival_for(probe)
		if festival.empty():
			continue
		var entry = festival.duplicate()
		entry["month"] = int(probe.month)
		entry["day"] = int(probe.day)
		entry["when"] = "今天" if offset == 0 else ("%d 天后" % offset)
		found.append(entry)
		if found.size() >= int(count):
			break
	return found
