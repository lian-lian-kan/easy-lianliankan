extends Node

# Daily Reward Manager - Handles daily check-in rewards
# Godot 3.5 compatible

const SAVE_PATH = "user://daily_rewards_data.json"

const REWARDS = [
	{"day": 1, "type": "coin", "amount": 50, "icon": "🪙"},
	{"day": 2, "type": "coin", "amount": 100, "icon": "🪙"},
	{"day": 3, "type": "coin", "amount": 150, "icon": "🪙"},
	{"day": 4, "type": "coin", "amount": 200, "icon": "🪙"},
	{"day": 5, "type": "coin", "amount": 300, "icon": "🪙"},
	{"day": 6, "type": "coin", "amount": 400, "icon": "🪙"},
	{"day": 7, "type": "theme", "theme_id": "random_locked", "icon": "🎁", "name": "随机主题"}
]

var current_streak = 0
var last_checkin_date = ""
var can_checkin_today = false

func _ready():
	_load_data()
	_check_can_checkin()

func _load_data():
	var file = File.new()
	if file.file_exists(SAVE_PATH):
		var err = file.open(SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				current_streak = data.get("streak", 0)
				last_checkin_date = data.get("last_date", "")
			file.close()

func _save_data():
	var file = File.new()
	var err = file.open(SAVE_PATH, File.WRITE)
	if err == OK:
		var data = {
			"streak": current_streak,
			"last_date": last_checkin_date
		}
		file.store_string(to_json(data))
		file.close()

func _get_today_date():
	var datetime = OS.get_datetime()
	return str(datetime.year) + "-" + str(datetime.month) + "-" + str(datetime.day)

func _check_can_checkin():
	var today = _get_today_date()
	can_checkin_today = (last_checkin_date != today)

func can_checkin():
	_check_can_checkin()
	return can_checkin_today

func get_current_day():
	return (current_streak % 7) + 1

func get_reward_for_day(day):
	for reward in REWARDS:
		if reward.day == day:
			return reward
	return REWARDS[0]

func get_today_reward():
	var day = get_current_day()
	return get_reward_for_day(day)

func claim_reward(coins_manager, theme_manager):
	if not can_checkin():
		return false

	var reward = get_today_reward()
	var claimed = false

	if reward.type == "coin":
		coins_manager.add_coins(reward.amount)
		claimed = true
	elif reward.type == "theme":
		if theme_manager != null:
			claimed = theme_manager.unlock_random_theme()

	if claimed:
		current_streak += 1
		last_checkin_date = _get_today_date()
		_save_data()
		can_checkin_today = false
		return true

	return false

func get_all_rewards():
	return REWARDS

func get_streak():
	return current_streak

func get_time_until_next():
	if can_checkin():
		return "可领取"

	var now = OS.get_datetime()
	var tomorrow = now.duplicate()
	tomorrow.day += 1
	tomorrow.hour = 0
	tomorrow.minute = 0
	tomorrow.second = 0

	# Simple calculation
	var seconds_until_midnight = (24 - now.hour) * 3600 - now.minute * 60 - now.second
	var hours = seconds_until_midnight / 3600
	var minutes = (seconds_until_midnight % 3600) / 60

	if hours > 0:
		return str(hours) + "小时" + str(minutes) + "分"
	return str(minutes) + "分钟"

func reset_streak():
	# Check if streak should be reset (missed more than 1 day)
	if last_checkin_date == "" or last_checkin_date == _get_today_date():
		return

	# Parse last checkin date
	var parts = last_checkin_date.split("-")
	if parts.size() != 3:
		return

	var last_year = int(parts[0])
	var last_month = int(parts[1])
	var last_day = int(parts[2])

	var today = OS.get_datetime()

	# Simple check - if not consecutive day, reset streak
	var last_date_val = last_year * 10000 + last_month * 100 + last_day
	var today_val = today.year * 10000 + today.month * 100 + today.day

	if today_val - last_date_val > 1:
		current_streak = 0
		_save_data()
