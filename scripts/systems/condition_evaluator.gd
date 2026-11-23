class_name ConditionEvaluator
extends RefCounted
## Evaluates declarative condition dictionaries against WorldState.


static func evaluate_all(conditions: Array, world_state: Node) -> bool:
	for entry: Variant in conditions:
		if entry is Dictionary:
			if not evaluate_one(entry as Dictionary, world_state):
				return false
	return true


static func evaluate_one(cond: Dictionary, world_state: Node) -> bool:
	if world_state == null:
		return false
	var cond_type: String = str(cond.get("type", ""))
	match cond_type:
		"fact_equals":
			var fact_id: StringName = StringName(str(cond.get("fact_id", "")))
			var expected: Variant = cond.get("value", null)
			return world_state.call(&"get_fact", fact_id) == expected
		"fact_exists":
			var fact_id: StringName = StringName(str(cond.get("fact_id", "")))
			var facts: Dictionary = world_state.get("facts") as Dictionary
			return facts.has(fact_id)
		"fact_gte":
			var fact_id: StringName = StringName(str(cond.get("fact_id", "")))
			var current: float = float(world_state.call(&"get_fact", fact_id, 0))
			return current >= float(cond.get("value", 0))
		"rel_gte":
			var npc_id: StringName = StringName(str(cond.get("npc_id", "")))
			var axis: String = str(cond.get("axis", "trust"))
			var rels: Dictionary = world_state.get("relationships") as Dictionary
			var npc_rel: Dictionary = rels.get(npc_id, {}) as Dictionary
			var val: int = int(npc_rel.get(axis, npc_rel.get(StringName(axis), 0)))
			return val >= int(cond.get("value", 0))
		"day_gte":
			return int(world_state.get("day")) >= int(cond.get("value", 1))
		"period_in":
			var allowed: Variant = cond.get("values", [])
			if allowed is Array:
				var current_period: int = int(world_state.get("period"))
				return current_period in (allowed as Array)
			return false
		"event_completed":
			var event_id: StringName = StringName(str(cond.get("event_id", "")))
			var completed: Array = world_state.get("completed_events") as Array
			return event_id in completed
		"project_stage_gte":
			var project_id: StringName = StringName(str(cond.get("project_id", "")))
			var projects: Dictionary = world_state.get("projects") as Dictionary
			var proj_state: Dictionary = projects.get(project_id, {}) as Dictionary
			return int(proj_state.get("stage", 0)) >= int(cond.get("value", 0))
		"item_count_gte":
			var item_id: StringName = StringName(str(cond.get("item_id", "")))
			var inv: Dictionary = world_state.get("inventory") as Dictionary
			return int(inv.get(item_id, 0)) >= int(cond.get("value", 1))
		_:
			push_warning("ConditionEvaluator: unknown condition type '%s'" % cond_type)
			return false
