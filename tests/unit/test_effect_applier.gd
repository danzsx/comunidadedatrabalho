extends GutTest


func before_each() -> void:
	WorldState.reset_to_new_game()


func test_effects_mutate_world_state_and_emit_signals() -> void:
	watch_signals(EventBus)
	EffectApplier.apply_all([
		{"type": "set_fact", "fact_id": "visited_ubs", "value": true},
		{"type": "inc_fact", "fact_id": "visit_steps", "amount": 2},
		{"type": "add_relationship", "npc_id": "npc_hortencia", "axis": "trust", "delta": 2},
		{"type": "give_item", "item_id": "item_caderno_campo", "amount": 1},
		{"type": "inc_career_axis", "axis": "acs_engagement", "delta": 3},
		{"type": "set_world_patch", "patch_id": "patch_praca_canteiro", "stage": 1},
	], WorldState, EventBus)

	assert_eq(WorldState.get_fact(&"visited_ubs"), true)
	assert_eq(WorldState.get_fact(&"visit_steps"), 2)
	assert_eq(WorldState.relationships[&"npc_hortencia"][&"trust"], 2)
	assert_eq(WorldState.relationships[&"npc_hortencia"][&"affinity"], 0)
	assert_eq(WorldState.inventory[&"item_caderno_campo"], 1)
	assert_eq(WorldState.career_trajectory[&"acs_engagement"], 3)
	assert_eq(WorldState.world_patches[&"patch_praca_canteiro"], 1)
	assert_signal_emitted_with_parameters(EventBus, "relationship_changed", [&"npc_hortencia", &"trust", 2])
	assert_signal_emitted_with_parameters(EventBus, "world_patch_applied", [&"patch_praca_canteiro", 1])

	EffectApplier.apply_one({"type": "consume_item", "item_id": "item_caderno_campo", "amount": 1}, WorldState, EventBus)
	assert_false(WorldState.inventory.has(&"item_caderno_campo"))
