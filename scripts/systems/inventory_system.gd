class_name InventorySystem
extends RefCounted
## Lightweight narrative-purpose inventory operations backed by WorldState.inventory.


static func get_count(world_state: Node, item_id: StringName) -> int:
	if world_state == null or item_id == &"":
		return 0
	var inv: Dictionary = world_state.get("inventory") as Dictionary
	return int(inv.get(item_id, 0))


static func add_item(world_state: Node, item_id: StringName, amount: int = 1) -> int:
	if world_state == null or item_id == &"" or amount <= 0:
		return 0
	var inv: Dictionary = world_state.get("inventory") as Dictionary
	var next_val: int = int(inv.get(item_id, 0)) + amount
	inv[item_id] = next_val
	return next_val


static func remove_item(world_state: Node, item_id: StringName, amount: int = 1) -> bool:
	if get_count(world_state, item_id) < amount:
		return false
	var inv: Dictionary = world_state.get("inventory") as Dictionary
	var next_val: int = int(inv.get(item_id, 0)) - amount
	if next_val <= 0:
		inv.erase(item_id)
	else:
		inv[item_id] = next_val
	return true


static func has_items(world_state: Node, required_items: Dictionary) -> bool:
	for key: Variant in required_items.keys():
		var item_id: StringName = StringName(str(key))
		var needed: int = int(required_items[key])
		if get_count(world_state, item_id) < needed:
			return false
	return true
