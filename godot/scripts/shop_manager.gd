extends Node

# Shop Manager - Handles in-game purchases
# Godot 3.5 compatible

const SHOP_DATA_PATH = "res://data/shop.json"

var shop_items = []

func _ready():
	_load_shop_data()

func _load_shop_data():
	var file = File.new()
	if file.file_exists(SHOP_DATA_PATH):
		var err = file.open(SHOP_DATA_PATH, File.READ)
		if err == OK:
			var content = file.get_as_text()
			var data = parse_json(content)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				shop_items = data.get("items", [])
			file.close()

# Public API

func get_all_items():
	return shop_items

func get_items_by_type(item_type):
	var filtered = []
	for item in shop_items:
		if item.get("type", "") == item_type:
			filtered.append(item)
	return filtered

func get_item_by_id(item_id):
	for item in shop_items:
		if item.get("id", "") == item_id:
			return item
	return null

func can_afford(item_id, coins_manager, gems_manager = null):
	var item = get_item_by_id(item_id)
	if item == null:
		return false

	var price = item.get("price", {})
	var currency = price.get("currency", "coin")
	var amount = price.get("amount", 0)

	if currency == "coin":
		return coins_manager.can_spend(amount)
	elif currency == "gem" and gems_manager != null:
		return gems_manager.can_spend(amount)

	return false

func purchase_item(item_id, coins_manager, gems_manager = null, theme_manager = null):
	var item = get_item_by_id(item_id)
	if item == null:
		return {"success": false, "message": "商品不存在"}

	var price = item.get("price", {})
	var currency = price.get("currency", "coin")
	var amount = price.get("amount", 0)
	var item_type = item.get("type", "")

	# Check affordability
	if currency == "coin":
		if not coins_manager.can_spend(amount):
			return {"success": false, "message": "金币不足"}
	elif currency == "gem":
		if gems_manager == null or not gems_manager.can_spend(amount):
			return {"success": false, "message": "钻石不足"}

	# Process purchase based on item type
	var success = false
	var message = ""

	match item_type:
		"theme_bundle":
			if theme_manager != null:
				var contents = item.get("contents", [])
				var unlocked = 0
				for theme_id in contents:
					if theme_manager.unlock_theme(theme_id):
						unlocked += 1
				if unlocked > 0:
					success = true
					message = "解锁了 " + str(unlocked) + " 个主题"
				else:
					return {"success": false, "message": "这些主题已拥有"}

		"power_up_bundle":
			# Power-ups would be added to player's inventory
			# For now, just return success
			success = true
			message = "购买成功"

		"energy":
			var energy_amount = item.get("amount", 1)
			EnergyManager.add_energy(energy_amount)
			success = true
			message = "获得 " + str(energy_amount) + " 点体力"

		"booster":
			var duration = item.get("duration_minutes", 60)
			var effect = item.get("effect", "")
			if effect == "coin_x2":
				coins_manager.set_multiplier(2.0, duration)
				success = true
				message = "双倍金币效果已激活"

	# Deduct currency
	if success:
		if currency == "coin":
			coins_manager.spend_coins(amount)
		elif currency == "gem" and gems_manager != null:
			gems_manager.spend_gems(amount)

	return {"success": success, "message": message}

func get_price_string(item):
	var price = item.get("price", {})
	var currency = price.get("currency", "coin")
	var amount = price.get("amount", 0)

	var currency_symbol = "🪙" if currency == "coin" else "💎"
	return currency_symbol + " " + str(amount)
