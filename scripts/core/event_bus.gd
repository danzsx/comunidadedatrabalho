extends Node
## Global typed signal bus for decoupled cross-system communication.

signal period_changed(new_day: int, new_period: int)
signal day_ended(ended_day: int)
signal world_fact_changed(fact_id: StringName, new_value: Variant)
signal relationship_changed(npc_id: StringName, axis: StringName, new_value: int)
signal household_record_updated(family_id: StringName)
signal project_stage_changed(project_id: StringName, new_stage: int)
signal world_patch_applied(patch_id: StringName, active_stage: int)
signal dialogue_requested(dialogue_id: StringName, start_node: String, context: Dictionary)
signal dialogue_finished(dialogue_id: StringName)
signal scene_change_requested(location_id: StringName, spawn_id: StringName)
signal notification_requested(text: String, category: StringName)
