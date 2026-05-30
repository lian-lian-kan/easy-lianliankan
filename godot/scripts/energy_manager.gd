extends Node

# Energy Manager - Handles player energy system
# Godot 3.5 compatible

const MAX_ENERGY = 5
const RECOVERY_TIME_MINUTES = 20
const COST_PER_GAME = 1
const SAVE_PATH = "user://energy_data.json"

var current_energy = 5
var last_update_time = 0
var max_overflow = 10

func _ready():
	_load_energy_data()
	_calculate_recovery()

func _load_energy_data():
	var file = File.new()
	if file.file_exists(SAVE_PATH):
		var err = file.open(SAVE_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				current_energy = data.get("energy", MAX_ENERGY)
				last_update_time = data.get("last_update", OS.get_unix_time())
			file.close()
	else:
		current_energy = MAX_ENERGY
		last_update_time = OS.get_unix_time()
		_save_energy_data()

func _save_energy_data():
	var file = File.new()
	var err = file.open(SAVE_PATH, File.WRITE)
	if err == OK:
		var data = {
			"energy": current_energy,
			"last_update": OS.get_unix_time()
		}
		file.store_string(to_json(data))
		file.close()

func _calculate_recovery():
	var now = OS.get_unix_time()
	var elapsed_minutes = (now - last_update_time) / 60.0
	var recovered = int(elapsed_minutes / RECOVERY_TIME_MINUTES)

	if recovered > 0:
		current_energy = min(current_energy + recovered, MAX_ENERGY)
		last_update_time = now
		_save_energy_data()

# Public API

func get_energy():
	_calculate_recovery()
	return current_energy

func get_max_energy():
	return MAX_ENERGY

func get_recovery_time_remaining():
	if current_energy >= MAX_ENERGY:
		return 0

	var now = OS.get_unix_time()
	var elapsed_minutes = (now - last_update_time) / 60.0
	var minutes_into_cycle = int(elapsed_minutes) % RECOVERY_TIME_MINUTES
	return (RECOVERY_TIME_MINUTES - minutes_into_cycle) * 60  # Return seconds

func can_start_game():
	return current_energy >= COST_PER_GAME

func consume_energy_for_game():
	if current_energy >= COST_PER_GAME:
		current_energy -= COST_PER_GAME
		_save_energy_data()
		return true
	return false

func add_energy(amount):
	current_energy = min(current_energy + amount, max_overflow)
	_save_energy_data()

func refill_energy():
	current_energy = MAX_ENERGY
	_save_energy_data()

func get_time_until_next_energy():
	if current_energy >= MAX_ENERGY:
		return "已满"

	var seconds = get_recovery_time_remaining()
	var minutes = seconds / 60
	if minutes < 1:
		return "<1分钟"
	return str(minutes) + "分钟"

# Purchase methods

func buy_energy_with_coins(coins_manager):
	if coins_manager.can_spend(100):
		if coins_manager.spend_coins(100):
			add_energy(1)
			return true
	return false

func buy_energy_with_gems(gems_manager):
	if gems_manager.can_spend(10):
		if gems_manager.spend_gems(10):
			add_energy(5)
			return true
	return false

func watch_ad_for_energy():
	# Ad reward - should be called after ad is watched
	add_energy(1)
	return true
