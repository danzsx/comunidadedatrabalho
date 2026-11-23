extends GutTest


func before_each() -> void:
	WorldState.reset_to_new_game()


func test_fact_conditions() -> void:
	assert_false(ConditionEvaluator.evaluate_one({"type": "fact_exists", "fact_id": "met_hortencia"}, WorldState))
	WorldState.set_fact(&"met_hortencia", true)
	WorldState.set_fact(&"clues_found", 3)

	assert_true(ConditionEvaluator.evaluate_one({"type": "fact_exists", "fact_id": "met_hortencia"}, WorldState))
	assert_true(ConditionEvaluator.evaluate_one({"type": "fact_equals", "fact_id": "met_hortencia", "value": true}, WorldState))
	assert_true(ConditionEvaluator.evaluate_one({"type": "fact_gte", "fact_id": "clues_found", "value": 2}, WorldState))
	assert_false(ConditionEvaluator.evaluate_one({"type": "fact_gte", "fact_id": "clues_found", "value": 5}, WorldState))


func test_relationship_day_period_and_item_conditions() -> void:
	WorldState.day = 4
	WorldState.period = 2
	EffectApplier.apply_one({"type": "add_relationship", "npc_id": "npc_b_1", "axis": "affinity", "delta": 3}, WorldState, EventBus)
	EffectApplier.apply_one({"type": "give_item", "item_id": "item_caderno_campo", "amount": 1}, WorldState, EventBus)

	var all_pass: bool = ConditionEvaluator.evaluate_all([
		{"type": "day_gte", "value": 4},
		{"type": "period_in", "values": [1, 2]},
		{"type": "rel_gte", "npc_id": "npc_b_1", "axis": "affinity", "value": 3},
		{"type": "item_count_gte", "item_id": "item_caderno_campo", "value": 1},
	], WorldState)
	assert_true(all_pass)
	assert_false(ConditionEvaluator.evaluate_one({"type": "rel_gte", "npc_id": "npc_b_1", "axis": "trust", "value": 1}, WorldState))
