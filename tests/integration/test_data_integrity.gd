extends GutTest

const EXPECTED_NPCS: Array[StringName] = [
	&"npc_hortencia",
	&"npc_a_1", &"npc_a_2", &"npc_a_3",
	&"npc_b_1", &"npc_b_2",
	&"npc_c_1", &"npc_c_2",
]

const EXPECTED_FAMILIES: Array[StringName] = [
	&"fam_a",
	&"fam_b",
	&"fam_c",
]


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()


func test_vertical_slice_cast_and_data_integrity() -> void:
	for npc_id: StringName in EXPECTED_NPCS:
		assert_true(DataRegistry.has_character(npc_id), "Missing character '%s'" % String(npc_id))
	for fam_id: StringName in EXPECTED_FAMILIES:
		assert_true(DataRegistry.has_family(fam_id), "Missing family '%s'" % String(fam_id))
	assert_true(DataRegistry.has_item(&"item_caderno_campo"), "Missing item_caderno_campo")

	var errors: Array[String] = DataRegistry.validate_integrity()
	assert_eq(errors.size(), 0, "DataRegistry integrity errors: %s" % str(errors))


func test_dialogue_service_executes_hortencia_branch_and_mutates_world_state() -> void:
	var service := DialogueService.new()
	add_child_autofree(service)

	var err: Error = await service.start_dialogue(&"hortencia", "start")
	assert_eq(err, OK)
	assert_true(service.is_active)
	assert_not_null(service.current_line)

	# Step through lines until the choice prompt appears.
	var guard: int = 0
	while service.is_active and service.current_line != null and service.current_line.responses.is_empty() and guard < 10:
		await service.advance()
		guard += 1

	assert_true(service.is_active, "Dialogue should reach choice prompt.")
	assert_gt(service.current_line.responses.size(), 0, "Hortencia should present choices.")

	# Pick first choice (patient approach).
	var first_response: DialogueResponse = service.current_line.responses[0] as DialogueResponse
	await service.advance(first_response.next_id)

	assert_eq(WorldState.get_fact(&"met_hortencia"), true)
	assert_eq(WorldState.get_fact(&"hortencia_briefing_patient"), true)
	assert_eq(WorldState.inventory.get(&"item_caderno_campo", 0), 1)
	assert_eq(service.get_rel("npc_hortencia", "trust"), 2)

	# Advance to close dialogue.
	await service.advance()
	assert_false(service.is_active)
