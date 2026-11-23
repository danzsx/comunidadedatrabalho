class_name HouseholdRecordService
extends RefCounted
## Manages Alex's Field Notebook records per family (clues, notes, referral status).


static func ensure_record(world_state: Node, family_id: StringName) -> Dictionary:
	var records: Dictionary = world_state.get("household_records") as Dictionary
	if not records.has(family_id):
		records[family_id] = {
			"family_id": String(family_id),
			"last_visit_day": 0,
			"discovered_clues": [],
			"observations": [],
			"referral_status": "none",
			"follow_up_day": 0,
		}
	return records[family_id] as Dictionary


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
