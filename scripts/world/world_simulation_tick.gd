class_name WorldSimulationTick
extends RefCounted
## Deterministic tick pipeline executed strictly on period/day transitions (never per frame).


static func process_tick(is_day_end: bool, world_state: Node, registry: Node, event_bus: Node = null) -> Array[StringName]:
	FamilySimulation.ensure_initialized(world_state, registry)
	EnvironmentalInspectionService.ensure_initialized(world_state)
	CommunityGardenService.ensure_initialized(world_state)
	var triggered_events: Array[StringName] = EventRunner.evaluate_events(world_state, registry, event_bus)
	if is_day_end:
		FamilySimulation.process_day_tick(world_state, registry)
	var _infected: Array[StringName] = EnvironmentalInspectionService.process_tick(is_day_end, world_state, registry, event_bus)
	CommunityGardenService.process_tick(is_day_end, world_state, registry, event_bus)
	RoutineResolver.recompute_npc_locations(world_state, registry)
	return triggered_events
