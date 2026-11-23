class_name RoutineResolver
extends RefCounted
## Resolves each NPC's active location and spot marker from RoutineEntry resources.


static func recompute_npc_locations(world_state: Node, registry: Node) -> void:
	if world_state == null or registry == null:
		return
	var characters: Dictionary = registry.get("characters") as Dictionary
	var routines: Dictionary = registry.get("routines") as Dictionary
	var npc_states: Dictionary = world_state.get("npc_states") as Dictionary
	var current_day: int = int(world_state.get("day"))
	var current_period: int = int(world_state.get("period"))

	for char_id_var: Variant in characters.keys():
		var npc_id: StringName = char_id_var as StringName
		var ch: CharacterData = characters[npc_id] as CharacterData
		var best: RoutineEntry = null

		for r_id: Variant in routines.keys():
			var entry: RoutineEntry = routines[r_id] as RoutineEntry
			if entry == null or entry.npc_id != npc_id:
				continue
			if not entry.day_filter.is_empty() and not (current_day in entry.day_filter):
				continue
			if entry.period != -1 and entry.period != current_period:
				continue
			if not ConditionEvaluator.evaluate_all(entry.conditions, world_state):
				continue
			if best == null or entry.priority > best.priority:
				best = entry

		var resolved_loc: String = String(ch.residence_id) if ch != null else ""
		var resolved_marker: String = "spot_default"
		var resolved_line: String = ""
		if best != null:
			resolved_loc = String(best.location_id)
			resolved_marker = String(best.marker_name)
			resolved_line = best.ambient_line

		var existing: Dictionary = npc_states.get(npc_id, {}) as Dictionary
		existing["location_id"] = resolved_loc
		existing["marker_name"] = resolved_marker
		existing["ambient_line"] = resolved_line
		if not existing.has("alive"):
			existing["alive"] = true
		npc_states[npc_id] = existing


static func get_npcs_for_location(location_id: StringName, world_state: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world_state == null or location_id == &"":
		return result
	var target: String = String(location_id)
	var npc_states: Dictionary = world_state.get("npc_states") as Dictionary
	for npc_id_var: Variant in npc_states.keys():
		var state: Dictionary = npc_states[npc_id_var] as Dictionary
		if not bool(state.get("alive", true)):
			continue
		if str(state.get("location_id", "")) == target:
			result.append({
				"npc_id": npc_id_var as StringName,
				"marker_name": StringName(str(state.get("marker_name", "spot_default"))),
				"ambient_line": str(state.get("ambient_line", "")),
			})
	return result
