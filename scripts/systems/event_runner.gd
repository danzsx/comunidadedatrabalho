class_name EventRunner
extends RefCounted
## Evaluates WorldEventData rules on period/day ticks and applies their effects.


static func evaluate_events(world_state: Node, registry: Node, event_bus: Node = null) -> Array[StringName]:
	var triggered: Array[StringName] = []
	if world_state == null or registry == null:
		return triggered

	var events_dict: Dictionary = registry.get("events") as Dictionary
	var completed: Array = world_state.get("completed_events") as Array
	var current_day: int = int(world_state.get("day"))
	var current_period: int = int(world_state.get("period"))

	for evt_id: Variant in events_dict.keys():
		var evt: WorldEventData = events_dict[evt_id] as WorldEventData
		if evt == null:
			continue
		if evt.once and (evt.id in completed):
			continue
		if current_day < evt.min_day:
			continue
		if evt.target_period != -1 and current_period != evt.target_period:
			continue
		if not ConditionEvaluator.evaluate_all(evt.conditions, world_state):
			continue

		EffectApplier.apply_all(evt.effects, world_state, event_bus)
		if not (evt.id in completed):
			completed.append(evt.id)
		triggered.append(evt.id)

		if event_bus != null and not evt.notification_hint.is_empty():
			event_bus.emit_signal(&"notification_requested", evt.notification_hint, &"world_event")

	return triggered
