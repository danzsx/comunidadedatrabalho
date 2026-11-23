class_name HomeActivityService
extends RefCounted
## Personal life activities in CasaAlex (studying for university, reflection).


static func perform_study_session(world_state: Node, time_system: Node, event_bus: Node) -> void:
	if world_state == null:
		return
	EffectApplier.apply_all([
		{"type": "inc_fact", "fact_id": "alex_study_sessions", "amount": 1},
		{"type": "inc_career_axis", "axis": "academic_focus", "delta": 1},
		{"type": "inc_career_axis", "axis": "self_reflection", "delta": 1},
	], world_state, event_bus)

	if time_system != null:
		time_system.call(&"advance_period", 1)
	if event_bus != null:
		var count: int = int(world_state.call(&"get_fact", &"alex_study_sessions", 1))
		event_bus.emit_signal(&"notification_requested", "Voce estudou para a faculdade (%d sessoes)." % count, &"personal")
