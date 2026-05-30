extends Node

# Coins Manager - Handles player currency
# Godot 3.5 compatible

const SAVE_PATH = "user://coins_data.json"

var coins = 0
var coin_multiplier = 1.0
var multiplier_end_time = 0

func _ready():
	_load_coins_data()

func _load_coins_data():
	var file = File.new()
	if file.file_exists(SAVE_PATH):
		var err = file.open(SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				coins = data.get("coins", 0)
				coin_multiplier = data.get("multiplier", 1.0)
				multiplier_end_time = data.get("multiplier_end", 0)
			file.close()
	_check_multiplier_status()

func _save_coins_data():
	var file = File.new()
	var err = file.open(SAVE_PATH, File.WRITE)
	if err == OK:
		var data = {
			"coins": coins,
			"multiplier": coin_multiplier,
			"multiplier_end": multiplier_end_time
		}
		file.store_string(to_json(data))
		file.close()

func _check_multiplier_status():
	if coin_multiplier > 1.0:
		var now = OS.get_unix_time()
		if now > multiplier_end_time:
			coin_multiplier = 1.0
			_save_coins_data()

# Public API

func get_coins():
	_check_multiplier_status()
	return coins

func can_spend(amount):
	return coins >= amount

func spend_coins(amount):
	if coins >= amount:
		coins -= amount
		_save_coins_data()
		return true
	return false

func earn_coins(amount, apply_multiplier = true):
	_check_multiplier_status()
	var final_amount = amount
	if apply_multiplier:
		final_amount = int(amount * coin_multiplier)
	coins += final_amount
	_save_coins_data()
	return final_amount

func add_coins(amount):
	coins += amount
	_save_coins_data()

func set_multiplier(multiplier, duration_minutes):
	coin_multiplier = multiplier
	multiplier_end_time = OS.get_unix_time() + (duration_minutes * 60)
	_save_coins_data()

func get_multiplier():
	_check_multiplier_status()
	return coin_multiplier

func get_multiplier_time_remaining():
	if coin_multiplier <= 1.0:
		return 0
	var now = OS.get_unix_time()
	if now >= multiplier_end_time:
		return 0
	return multiplier_end_time - now

func get_multiplier_time_string():
	var seconds = get_multiplier_time_remaining()
	if seconds <= 0:
		return ""
	var minutes = seconds / 60
	var hours = minutes / 60
	if hours > 0:
		return str(hours) + "小时" + str(minutes % 60) + "分"
	return str(minutes) + "分钟"

# Reward calculation

func calculate_level_reward(score, level_config, time_remaining, time_limit):
	# Base reward
	var base_reward = int(score / 100)

	# Difficulty multiplier based on level
	var difficulty = level_config.get("kinds", 6)
	var difficulty_mult = 1.0 + (difficulty - 6) * 0.1

	# Time bonus
	var time_percent = float(time_remaining) / float(time_limit)
	var time_mult = 1.0
	if time_percent > 0.5:
		time_mult = 1.5
	elif time_percent > 0.25:
		time_mult = 1.2
	elif time_percent <= 0:
		time_mult = 0.5

	var final_reward = int(base_reward * difficulty_mult * time_mult)
	return final_reward

func add_first_clear_bonus():
	return earn_coins(50, false)

func add_perfect_clear_bonus():
	return earn_coins(100, false)
