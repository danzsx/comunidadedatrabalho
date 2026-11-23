class_name FamilySimulation
extends RefCounted
## Maintains mutable household states and processes day-end family transitions.


static func ensure_initialized(world_state: Node, registry: Node) -> void:
	if world_state == null or registry == null:
		return
	var fam_states: Dictionary = world_state.get("family_states") as Dictionary
	var families: Dictionary = registry.get("families") as Dictionary

	for fam_id_var: Variant in families.keys():
		var fam_id: StringName = fam_id_var as StringName
		if fam_states.has(fam_id):
			continue
		var fam: FamilyData = families[fam_id] as FamilyData
		if fam == null:
			continue
		var members_copy: Array[String] = []
		for member: StringName in fam.initial_members:
			members_copy.append(String(member))
		var conds_copy: Array[String] = []
		for cond: StringName in fam.initial_conditions:
			conds_copy.append(String(cond))
		fam_states[fam_id] = {
			"members": members_copy,
			"residence_id": String(fam.residence_id),
			"active_situations": conds_copy,
			"resolved_situations": [],
			"history": [],
		}


static func process_day_tick(world_state: Node, registry: Node) -> void:
	ensure_initialized(world_state, registry)
	var fam_states: Dictionary = world_state.get("family_states") as Dictionary

	# Reflect independent shift event in Family C history once triggered.
	if bool(world_state.call(&"get_fact", &"fam_c_bruno_left_for_shift", false)):
		var fam_c: Dictionary = fam_states.get(&"fam_c", {}) as Dictionary
		if not fam_c.is_empty():
			var history: Array = fam_c.get("history", []) as Array
			var already_logged: bool = false
			for item: Variant in history:
				if item is Dictionary and str((item as Dictionary).get("code", "")) == "bruno_left_for_shift":
					already_logged = true
					break
			if not already_logged:
				history.append({
					"day": int(world_state.get("day")),
					"code": "bruno_left_for_shift",
					"summary": "Bruno assumiu turno temporario fora da cidade.",
				})
				fam_c["history"] = history
