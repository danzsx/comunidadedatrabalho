class_name RelationshipService
extends RefCounted
## Manages the 4 independent relationship axes: trust, affinity, familiarity, cooperation.

const AXES: Array[StringName] = [&"trust", &"affinity", &"familiarity", &"cooperation"]
const MIN_VALUE: int = -10
const MAX_VALUE: int = 10


static func ensure_entry(world_state: Node, npc_id: StringName) -> Dictionary:
	var rels: Dictionary = world_state.get("relationships") as Dictionary
	if not rels.has(npc_id):
		rels[npc_id] = {
			&"trust": 0,
			&"affinity": 0,
			&"familiarity": 0,
			&"cooperation": 0,
		}
	return rels[npc_id] as Dictionary


static func get_axis(world_state: Node, npc_id: StringName, axis: StringName) -> int:
	if world_state == null:
		return 0
	var rels: Dictionary = world_state.get("relationships") as Dictionary
	if not rels.has(npc_id):
		return 0
	var entry: Dictionary = rels[npc_id] as Dictionary
	return int(entry.get(axis, entry.get(String(axis), 0)))


static func get_all_axes(world_state: Node, npc_id: StringName) -> Dictionary:
	return {
		&"trust": get_axis(world_state, npc_id, &"trust"),
		&"affinity": get_axis(world_state, npc_id, &"affinity"),
		&"familiarity": get_axis(world_state, npc_id, &"familiarity"),
		&"cooperation": get_axis(world_state, npc_id, &"cooperation"),
	}


static func adjust(world_state: Node, event_bus: Node, npc_id: StringName, axis: StringName, delta: int) -> int:
	if world_state == null or not (axis in AXES):
		return 0
	var entry: Dictionary = ensure_entry(world_state, npc_id)
	var current: int = int(entry.get(axis, entry.get(String(axis), 0)))
	var next_val: int = clampi(current + delta, MIN_VALUE, MAX_VALUE)
	entry[axis] = next_val
	if event_bus != null:
		event_bus.emit_signal(&"relationship_changed", npc_id, axis, next_val)
	return next_val


static func describe_bond(axes: Dictionary) -> String:
	var trust: int = int(axes.get(&"trust", 0))
	var affinity: int = int(axes.get(&"affinity", 0))
	var familiarity: int = int(axes.get(&"familiarity", 0))
	var cooperation: int = int(axes.get(&"cooperation", 0))

	if trust <= -2:
		return "Relação fragilizada"
	if trust >= 3 and cooperation >= 2:
		return "Parceria comunitária sólida"
	if trust >= 2 or affinity >= 2:
		return "Vínculo acolhedor em crescimento"
	if familiarity >= 1:
		return "Conhecido do bairro"
	return "Primeiro contato pendente"
