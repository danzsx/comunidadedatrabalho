class_name FieldVisitService
extends RefCounted
## Orchestrates non-medicalized ACS home visits: briefing -> observation -> listening -> notebook -> UBS referral.

const MIN_CLUES_FOR_REPORT: int = 2


static func assign_visit(world_state: Node, event_bus: Node, family_id: StringName, title: String) -> void:
	if world_state == null or family_id == &"":
		return
	var visits: Dictionary = world_state.get("field_visits") as Dictionary
	if visits.has(family_id):
		return
	visits[family_id] = {
		"family_id": String(family_id),
		"title": title,
		"stage": "assigned",
		"listened": false,
		"respectful": false,
		"assigned_day": int(world_state.get("day")),
	}
	HouseholdRecordService.ensure_record(world_state, family_id)
	if event_bus != null:
		event_bus.emit_signal(&"household_record_updated", family_id)
		event_bus.emit_signal(&"notification_requested", "Nova atividade no Caderno: " + title, &"work")


static func get_visit_stage(world_state: Node, family_id: StringName) -> String:
	if world_state == null:
		return "not_assigned"
	var visits: Dictionary = world_state.get("field_visits") as Dictionary
	if not visits.has(family_id):
		return "not_assigned"
	var visit: Dictionary = visits[family_id] as Dictionary
	return str(visit.get("stage", "assigned"))


static func register_observation(world_state: Node, event_bus: Node, family_id: StringName, clue_id: StringName, note_text: String) -> bool:
	var added: bool = HouseholdRecordService.record_clue(world_state, event_bus, family_id, clue_id, note_text)
	if not added:
		return false
	var visits: Dictionary = world_state.get("field_visits") as Dictionary
	if visits.has(family_id):
		var visit: Dictionary = visits[family_id] as Dictionary
		if str(visit.get("stage", "")) == "assigned":
			visit["stage"] = "observing"
		_check_ready_to_report(world_state, event_bus, family_id)
	return true


static func mark_resident_listened(world_state: Node, event_bus: Node, family_id: StringName, npc_id: StringName, respectful: bool) -> void:
	if world_state == null:
		return
	var visits: Dictionary = world_state.get("field_visits") as Dictionary
	if not visits.has(family_id):
		assign_visit(world_state, event_bus, family_id, "Visita domiciliar")
	var visit: Dictionary = visits[family_id] as Dictionary
	visit["listened"] = true
	visit["respectful"] = respectful
	if str(visit.get("stage", "")) == "assigned":
		visit["stage"] = "observing"

	RelationshipService.adjust(world_state, event_bus, npc_id, &"familiarity", 1)
	if respectful:
		RelationshipService.adjust(world_state, event_bus, npc_id, &"trust", 2)
	else:
		RelationshipService.adjust(world_state, event_bus, npc_id, &"trust", -1)

	_check_ready_to_report(world_state, event_bus, family_id)


static func submit_ubs_referral(world_state: Node, event_bus: Node, family_id: StringName, approach: StringName) -> void:
	if world_state == null or family_id == &"":
		return
	var visits: Dictionary = world_state.get("field_visits") as Dictionary
	if not visits.has(family_id):
		return
	var visit: Dictionary = visits[family_id] as Dictionary
	var follow_up: int = maxi(5, int(world_state.get("day")) + 2)

	if approach == &"supportive":
		visit["stage"] = "reported_supportive"
		HouseholdRecordService.set_referral_status(world_state, event_bus, family_id, &"referred_support", follow_up)
		world_state.call(&"set_fact", StringName(String(family_id) + "_outcome_supportive"), true)
		RelationshipService.adjust(world_state, event_bus, &"npc_hortencia", &"trust", 2)
		RelationshipService.adjust(world_state, event_bus, &"npc_hortencia", &"cooperation", 1)
		EffectApplier.apply_one({"type": "inc_career_axis", "axis": "acs_engagement", "delta": 2}, world_state, event_bus)
	else:
		visit["stage"] = "reported_rushed"
		HouseholdRecordService.set_referral_status(world_state, event_bus, family_id, &"closed_strained", follow_up)
		world_state.call(&"set_fact", StringName(String(family_id) + "_outcome_rushed"), true)
		RelationshipService.adjust(world_state, event_bus, &"npc_hortencia", &"trust", -1)
		EffectApplier.apply_one({"type": "inc_career_axis", "axis": "academic_focus", "delta": 1}, world_state, event_bus)


static func _check_ready_to_report(world_state: Node, event_bus: Node, family_id: StringName) -> void:
	var visits: Dictionary = world_state.get("field_visits") as Dictionary
	var visit: Dictionary = visits.get(family_id, {}) as Dictionary
	if visit.is_empty():
		return
	var stage: String = str(visit.get("stage", ""))
	if stage in ["reported_supportive", "reported_rushed", "ready_to_report"]:
		return
	var clue_count: int = HouseholdRecordService.get_clue_count(world_state, family_id)
	if clue_count >= MIN_CLUES_FOR_REPORT and bool(visit.get("listened", false)):
		visit["stage"] = "ready_to_report"
		if event_bus != null:
			event_bus.emit_signal(&"household_record_updated", family_id)
			event_bus.emit_signal(&"notification_requested", "Visita registrada! Volte a UBS para articular com Hortencia.", &"work")
