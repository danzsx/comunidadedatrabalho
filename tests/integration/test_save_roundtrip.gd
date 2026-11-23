extends GutTest

const ROUNDTRIP_PATH: String = "user://saves/test_full_roundtrip_m6.json"


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()
	TimeSystem.autosave_on_day_end = false


func after_each() -> void:
	if FileAccess.file_exists(ROUNDTRIP_PATH):
		var _err: Error = DirAccess.remove_absolute(ROUNDTRIP_PATH)
	TimeSystem.autosave_on_day_end = true
	WorldState.reset_to_new_game()


func test_full_world_state_save_load_roundtrip() -> void:
	# Populate every single subsystem in WorldState as if mid-Vertical-Slice (Day 6 Night).
	WorldState.day = 6
	WorldState.week = 1
	WorldState.period = 2
	WorldState.current_location_id = &"loc_bairro_praca"
	WorldState.current_spawn_id = &"spawn_ubs"
	WorldState.player_position = Vector2(312.5, 194.25)
	WorldState.set_fact(&"met_hortencia", true)
	WorldState.set_fact(&"alex_study_sessions", 3)

	RelationshipService.adjust(WorldState, EventBus, &"npc_hortencia", &"trust", 4)
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_1", &"affinity", 3)
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_1", &"familiarity", 2)
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_1", &"cooperation", 2)

	FieldVisitService.assign_visit(WorldState, EventBus, &"fam_a", "Visita Familia Alencar")
	FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_receitas", "Receitas sem horario.")
	FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_umidade", "Umidade no corredor.")
	FieldVisitService.mark_resident_listened(WorldState, EventBus, &"fam_a", &"npc_a_2", true)
	FieldVisitService.submit_ubs_referral(WorldState, EventBus, &"fam_a", &"supportive")

	InventorySystem.add_item(WorldState, &"item_caderno_campo", 1)
	InventorySystem.add_item(WorldState, &"item_ferramentas_jardim", 1)
	InventorySystem.add_item(WorldState, &"item_composto_organico", 1)
	InventorySystem.add_item(WorldState, &"item_mudas_flores", 1)
	assert_true(ProjectService.unlock_project(WorldState, DataRegistry, EventBus, &"proj_jardim_praca"))
	assert_true(ProjectService.advance_stage(WorldState, DataRegistry, EventBus, &"proj_jardim_praca"))
	assert_true(ProjectService.advance_stage(WorldState, DataRegistry, EventBus, &"proj_jardim_praca"))

	# Trigger Day 6 Morning tick so Day 5+ morning consequence fires, then move to Night before saving.
	WorldState.period = 0
	WorldSimulationTick.process_tick(true, WorldState, DataRegistry, EventBus)
	WorldState.period = 2

	# Save to file and verify meta preview.
	assert_eq(SaveSystem.save_to_path(ROUNDTRIP_PATH), OK)
	var meta: Dictionary = SaveSystem.get_meta_from_path(ROUNDTRIP_PATH)
	assert_eq(int(meta.get("day", 0)), 6)
	assert_eq(int(meta.get("period", -1)), 2)
	assert_eq(str(meta.get("current_location_id", "")), "loc_bairro_praca")

	# Wipe WorldState completely, then reload.
	WorldState.reset_to_new_game()
	assert_eq(WorldState.day, 1)
	assert_false(ProjectService.is_completed(WorldState, &"proj_jardim_praca"))

	assert_eq(SaveSystem.load_from_path(ROUNDTRIP_PATH), OK)

	# Assert 100% fidelity across all subsystems.
	assert_eq(WorldState.day, 6)
	assert_eq(WorldState.period, 2)
	assert_eq(WorldState.current_location_id, &"loc_bairro_praca")
	assert_eq(WorldState.player_position, Vector2(312.5, 194.25))
	assert_eq(WorldState.get_fact(&"met_hortencia"), true)
	assert_eq(WorldState.get_fact(&"alex_study_sessions"), 3)
	assert_eq(RelationshipService.get_axis(WorldState, &"npc_hortencia", &"trust"), 6)
	assert_eq(FieldVisitService.get_visit_stage(WorldState, &"fam_a"), "reported_supportive")
	assert_eq(HouseholdRecordService.get_clue_count(WorldState, &"fam_a"), 2)
	assert_eq(InventorySystem.get_count(WorldState, &"item_caderno_campo"), 1)
	assert_true(ProjectService.is_completed(WorldState, &"proj_jardim_praca"))
	assert_eq(int(WorldState.world_patches.get(&"patch_praca_canteiro", 0)), 2)
	assert_true(&"evt_fam_a_consequence_supportive" in WorldState.completed_events)
	assert_gt(int(WorldState.career_trajectory.get(&"community_ties", 0)), 0)


func test_all_character_sprites_and_portraits_exist() -> void:
	assert_true(ResourceLoader.exists("res://assets/characters/sheets/alex_sheet.png"))
	assert_true(ResourceLoader.exists("res://assets/characters/portraits/alex.png"))
	for char_id: StringName in DataRegistry.get_all_character_ids():
		assert_true(ResourceLoader.exists("res://assets/characters/sheets/%s_sheet.png" % String(char_id)), "Missing anim sheet for " + String(char_id))
		assert_true(ResourceLoader.exists("res://assets/characters/portraits/%s.png" % String(char_id)), "Missing portrait for " + String(char_id))
