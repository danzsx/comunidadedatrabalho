class_name HouseholdRecordService
extends RefCounted
## Manages Alex's Field Notebook records per family: clues, visit history, memories, follow-ups, and referral status.


static func ensure_record(world_state: Node, family_id: StringName) -> Dictionary:
	var records: Dictionary = world_state.get("household_records") as Dictionary
	if not records.has(family_id):
		records[family_id] = {
			"family_id": String(family_id),
			"last_visit_day": 0,
			"visit_count": 0,
			"discovered_clues": [],
			"observations": [],
			"visit_history": [],
			"memories": {},
			"pending_followups": [],
			"referral_status": "none",
			"follow_up_day": 0,
		}
	var rec: Dictionary = records[family_id] as Dictionary
	if not rec.has("visit_count"):
		rec["visit_count"] = 0
	if not rec.has("visit_history"):
		rec["visit_history"] = []
	if not rec.has("memories"):
		rec["memories"] = {}
	if not rec.has("pending_followups"):
		rec["pending_followups"] = []
	return rec


static func get_record(world_state: Node, family_id: StringName) -> Dictionary:
	if world_state == null:
		return {}
	var records: Dictionary = world_state.get("household_records") as Dictionary
	return records.get(family_id, {}) as Dictionary


static func record_clue(world_state: Node, event_bus: Node, family_id: StringName, clue_id: StringName, note_text: String) -> bool:
	if world_state == null or family_id == &"" or clue_id == &"":
		return false
	var rec: Dictionary = ensure_record(world_state, family_id)
	var clues: Array = rec.get("discovered_clues", []) as Array
	var clue_str: String = String(clue_id)
	if clue_str in clues:
		return false

	clues.append(clue_str)
	rec["discovered_clues"] = clues
	var notes: Array = rec.get("observations", []) as Array
	notes.append(note_text)
	rec["observations"] = notes
	rec["last_visit_day"] = int(world_state.get("day"))

	if event_bus != null:
		event_bus.emit_signal(&"household_record_updated", family_id)
		event_bus.emit_signal(&"notification_requested", "Anotado no Caderno: " + note_text.left(52), &"notebook")
	return true


static func set_referral_status(world_state: Node, event_bus: Node, family_id: StringName, status: StringName, follow_up_day: int = 0) -> void:
	if world_state == null or family_id == &"":
		return
	var rec: Dictionary = ensure_record(world_state, family_id)
	rec["referral_status"] = String(status)
	rec["follow_up_day"] = follow_up_day
	rec["last_visit_day"] = int(world_state.get("day"))
	if event_bus != null:
		event_bus.emit_signal(&"household_record_updated", family_id)


static func get_clue_count(world_state: Node, family_id: StringName) -> int:
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return 0
	var clues: Array = rec.get("discovered_clues", []) as Array
	return clues.size()


static func set_memory(world_state: Node, event_bus: Node, family_id: StringName, key: String, value: Variant) -> void:
	if world_state == null or family_id == &"" or key.is_empty():
		return
	var rec: Dictionary = ensure_record(world_state, family_id)
	var memories: Dictionary = rec.get("memories", {}) as Dictionary
	memories[key] = value
	rec["memories"] = memories
	if event_bus != null:
		event_bus.emit_signal(&"household_record_updated", family_id)


static func get_memory(world_state: Node, family_id: StringName, key: String, default_value: Variant = null) -> Variant:
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return default_value
	var memories: Dictionary = rec.get("memories", {}) as Dictionary
	return memories.get(key, default_value)


static func has_memory(world_state: Node, family_id: StringName, key: String) -> bool:
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return false
	var memories: Dictionary = rec.get("memories", {}) as Dictionary
	if not memories.has(key):
		return false
	var val: Variant = memories[key]
	if val is bool:
		return bool(val)
	if val is String:
		return not (val as String).is_empty()
	return val != null


static func add_followup(
	world_state: Node,
	event_bus: Node,
	family_id: StringName,
	followup_id: String,
	description: String,
	due_day: int = 0
) -> bool:
	if world_state == null or family_id == &"" or followup_id.is_empty():
		return false
	var rec: Dictionary = ensure_record(world_state, family_id)
	var list: Array = rec.get("pending_followups", []) as Array
	for item_var: Variant in list:
		if item_var is Dictionary:
			var item: Dictionary = item_var as Dictionary
			if str(item.get("id", "")) == followup_id:
				if str(item.get("status", "pending")) == "pending":
					return false
				# Re-open if previously resolved and explicitly re-added
				item["status"] = "pending"
				item["description"] = description
				item["due_day"] = due_day
				rec["pending_followups"] = list
				if event_bus != null:
					event_bus.emit_signal(&"household_record_updated", family_id)
				return true

	var current_day: int = int(world_state.get("day"))
	var target_day: int = due_day if due_day > 0 else current_day + 1
	list.append({
		"id": followup_id,
		"description": description,
		"created_day": current_day,
		"due_day": target_day,
		"status": "pending",
		"resolved_day": 0,
	})
	rec["pending_followups"] = list
	if event_bus != null:
		event_bus.emit_signal(&"household_record_updated", family_id)
		event_bus.emit_signal(&"notification_requested", "Pendência registrada: " + description.left(48), &"notebook")
	return true


static func resolve_followup(world_state: Node, event_bus: Node, family_id: StringName, followup_id: String) -> bool:
	if world_state == null or family_id == &"" or followup_id.is_empty():
		return false
	var rec: Dictionary = ensure_record(world_state, family_id)
	var list: Array = rec.get("pending_followups", []) as Array
	for item_var: Variant in list:
		if item_var is Dictionary:
			var item: Dictionary = item_var as Dictionary
			if str(item.get("id", "")) == followup_id and str(item.get("status", "pending")) == "pending":
				item["status"] = "resolved"
				item["resolved_day"] = int(world_state.get("day"))
				rec["pending_followups"] = list
				if event_bus != null:
					event_bus.emit_signal(&"household_record_updated", family_id)
					event_bus.emit_signal(&"notification_requested", "Pendência resolvida: " + str(item.get("description", "")).left(48), &"work")
				return true
	return false


static func has_pending_followup(world_state: Node, family_id: StringName, followup_id: String) -> bool:
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return false
	var list: Array = rec.get("pending_followups", []) as Array
	for item_var: Variant in list:
		if item_var is Dictionary:
			var item: Dictionary = item_var as Dictionary
			if str(item.get("id", "")) == followup_id and str(item.get("status", "pending")) == "pending":
				return true
	return false


static func get_pending_followups(world_state: Node, family_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return result
	var list: Array = rec.get("pending_followups", []) as Array
	for item_var: Variant in list:
		if item_var is Dictionary:
			var item: Dictionary = item_var as Dictionary
			if str(item.get("status", "pending")) == "pending":
				result.append(item)
	return result


static func record_completed_visit(
	world_state: Node,
	event_bus: Node,
	family_id: StringName,
	npc_id: StringName,
	approach: String,
	summary: String,
	highlights: Array[String] = []
) -> Dictionary:
	if world_state == null or family_id == &"":
		return {}
	var rec: Dictionary = ensure_record(world_state, family_id)
	var next_num: int = int(rec.get("visit_count", 0)) + 1
	var current_day: int = int(world_state.get("day"))
	var current_period: int = int(world_state.get("period"))

	var entry: Dictionary = {
		"visit_number": next_num,
		"day": current_day,
		"period": current_period,
		"npc_id": String(npc_id),
		"approach": approach,
		"summary": summary,
		"highlights": highlights.duplicate(),
	}
	var history: Array = rec.get("visit_history", []) as Array
	history.append(entry)
	rec["visit_history"] = history
	rec["visit_count"] = next_num
	rec["last_visit_day"] = current_day

	var memories: Dictionary = rec.get("memories", {}) as Dictionary
	memories["last_approach"] = approach
	if not memories.has("first_impression"):
		memories["first_impression"] = approach
	rec["memories"] = memories

	if event_bus != null:
		event_bus.emit_signal(&"household_record_updated", family_id)
		event_bus.emit_signal(
			&"notification_requested",
			"Visita #%d registrada no Caderno de Campo." % next_num,
			&"work"
		)
	return entry


static func get_visit_count(world_state: Node, family_id: StringName) -> int:
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return 0
	return int(rec.get("visit_count", 0))


static func get_visit_history(world_state: Node, family_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rec: Dictionary = get_record(world_state, family_id)
	if rec.is_empty():
		return result
	var raw: Array = rec.get("visit_history", []) as Array
	for item_var: Variant in raw:
		if item_var is Dictionary:
			result.append(item_var as Dictionary)
	return result
