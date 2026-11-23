class_name ProjectService
extends RefCounted
## Manages relational unlocking, stage progression, and permanent world patches for projects.


static func get_project_state(world_state: Node, project_id: StringName) -> Dictionary:
	if world_state == null:
		return {}
	var projects: Dictionary = world_state.get("projects") as Dictionary
	return projects.get(project_id, {}) as Dictionary


static func is_unlocked(world_state: Node, project_id: StringName) -> bool:
	var st: Dictionary = get_project_state(world_state, project_id)
	return bool(st.get("unlocked", false))


static func is_completed(world_state: Node, project_id: StringName) -> bool:
	var st: Dictionary = get_project_state(world_state, project_id)
	return bool(st.get("completed", false))


static func get_stage(world_state: Node, project_id: StringName) -> int:
	var st: Dictionary = get_project_state(world_state, project_id)
	return int(st.get("stage", 0))


static func can_unlock(world_state: Node, registry: Node, project_id: StringName) -> bool:
	if world_state == null or registry == null:
		return false
	if is_unlocked(world_state, project_id):
		return false
	var data: ProjectData = registry.call(&"get_project", project_id) as ProjectData
	if data == null:
		return false
	return ConditionEvaluator.evaluate_all(data.unlock_conditions, world_state)


static func unlock_project(world_state: Node, registry: Node, event_bus: Node, project_id: StringName) -> bool:
	if not can_unlock(world_state, registry, project_id):
		return false
	var data: ProjectData = registry.call(&"get_project", project_id) as ProjectData
	var projects: Dictionary = world_state.get("projects") as Dictionary
	projects[project_id] = {
		"unlocked": true,
		"stage": 0,
		"completed": false,
	}
	if event_bus != null:
		event_bus.emit_signal(&"project_stage_changed", project_id, 0)
		event_bus.emit_signal(&"notification_requested", "Projeto desbloqueado: " + data.title, &"project")
	return true


static func can_advance_stage(world_state: Node, registry: Node, project_id: StringName) -> bool:
	if world_state == null or registry == null:
		return false
	if not is_unlocked(world_state, project_id) or is_completed(world_state, project_id):
		return false
	var data: ProjectData = registry.call(&"get_project", project_id) as ProjectData
	if data == null:
		return false
	var stage_idx: int = get_stage(world_state, project_id)
	if stage_idx < 0 or stage_idx >= data.stages.size():
		return false
	var stage_def: Dictionary = data.stages[stage_idx]
	var req_items: Dictionary = stage_def.get("required_items", {}) as Dictionary
	if not InventorySystem.has_items(world_state, req_items):
		return false
	var req_conds: Array = stage_def.get("required_conditions", []) as Array
	return ConditionEvaluator.evaluate_all(req_conds, world_state)


static func advance_stage(world_state: Node, registry: Node, event_bus: Node, project_id: StringName) -> bool:
	if not can_advance_stage(world_state, registry, project_id):
		return false
	var data: ProjectData = registry.call(&"get_project", project_id) as ProjectData
	var projects: Dictionary = world_state.get("projects") as Dictionary
	var st: Dictionary = projects[project_id] as Dictionary
	var stage_idx: int = int(st.get("stage", 0))
	var stage_def: Dictionary = data.stages[stage_idx]

	var req_items: Dictionary = stage_def.get("required_items", {}) as Dictionary
	for key: Variant in req_items.keys():
		InventorySystem.remove_item(world_state, StringName(str(key)), int(req_items[key]))

	var next_stage: int = stage_idx + 1
	st["stage"] = next_stage
	var finished: bool = next_stage >= data.stages.size()
	st["completed"] = finished

	var effects: Array = stage_def.get("completion_effects", []) as Array
	EffectApplier.apply_all(effects, world_state, event_bus)

	if data.world_patch_id != &"":
		EffectApplier.apply_one(
			{"type": "set_world_patch", "patch_id": String(data.world_patch_id), "stage": next_stage},
			world_state,
			event_bus
		)

	if event_bus != null:
		event_bus.emit_signal(&"project_stage_changed", project_id, next_stage)
		var msg: String = "Projeto concluido: " + data.title if finished else "Etapa concluida em: " + data.title
		event_bus.emit_signal(&"notification_requested", msg, &"project")
	return true
