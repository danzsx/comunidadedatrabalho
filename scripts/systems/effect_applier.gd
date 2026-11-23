class_name EffectApplier
extends RefCounted
## Applies declarative effect dictionaries to WorldState and emits EventBus signals.


static func apply_all(effects: Array, world_state: Node, event_bus: Node = null) -> void:
	for entry: Variant in effects:
		if entry is Dictionary:
			apply_one(entry as Dictionary, world_state, event_bus)


static func apply_one(effect: Dictionary, world_state: Node, event_bus: Node = null) -> void:
	if world_state == null:
		return
	var eff_type: String = str(effect.get("type", ""))
	match eff_type:
		"set_fact":
			var fact_id: StringName = StringName(str(effect.get("fact_id", "")))
			world_state.call(&"set_fact", fact_id, effect.get("value", true))
		"inc_fact":
			var fact_id: StringName = StringName(str(effect.get("fact_id", "")))
			var current: int = int(world_state.call(&"get_fact", fact_id, 0))
			world_state.call(&"set_fact", fact_id, current + int(effect.get("amount", 1)))
		"add_relationship":
			var npc_id: StringName = StringName(str(effect.get("npc_id", "")))
			var axis: StringName = StringName(str(effect.get("axis", "trust")))
			var delta: int = int(effect.get("delta", 0))
			var rels: Dictionary = world_state.get("relationships") as Dictionary
			if not rels.has(npc_id):
				rels[npc_id] = {
					&"trust": 0,
					&"affinity": 0,
					&"familiarity": 0,
					&"cooperation": 0,
				}
			var npc_rel: Dictionary = rels[npc_id] as Dictionary
			var next_val: int = int(npc_rel.get(axis, 0)) + delta
			npc_rel[axis] = next_val
			if event_bus != null:
				event_bus.emit_signal(&"relationship_changed", npc_id, axis, next_val)
		"give_item":
			var item_id: StringName = StringName(str(effect.get("item_id", "")))
			var amount: int = maxi(1, int(effect.get("amount", 1)))
			var inv: Dictionary = world_state.get("inventory") as Dictionary
			inv[item_id] = int(inv.get(item_id, 0)) + amount
		"consume_item":
			var item_id: StringName = StringName(str(effect.get("item_id", "")))
			var amount: int = maxi(1, int(effect.get("amount", 1)))
			var inv: Dictionary = world_state.get("inventory") as Dictionary
			var next_count: int = maxi(0, int(inv.get(item_id, 0)) - amount)
			if next_count == 0:
				inv.erase(item_id)
			else:
				inv[item_id] = next_count
		"inc_career_axis":
			var axis: StringName = StringName(str(effect.get("axis", "")))
			var delta: int = int(effect.get("delta", 1))
			var traj: Dictionary = world_state.get("career_trajectory") as Dictionary
			traj[axis] = int(traj.get(axis, 0)) + delta
		"set_world_patch":
			var patch_id: StringName = StringName(str(effect.get("patch_id", "")))
			var stage: int = int(effect.get("stage", 0))
			var patches: Dictionary = world_state.get("world_patches") as Dictionary
			patches[patch_id] = stage
			if event_bus != null:
				event_bus.emit_signal(&"world_patch_applied", patch_id, stage)
		_:
			push_warning("EffectApplier: unknown effect type '%s'" % eff_type)
