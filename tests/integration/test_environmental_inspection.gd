extends GutTest

const ENV_SAVE_PATH: String = "user://saves/test_env_inspection_roundtrip.json"


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()
	TimeSystem.autosave_on_day_end = false
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)


func after_each() -> void:
	if FileAccess.file_exists(ENV_SAVE_PATH):
		var _err: Error = DirAccess.remove_absolute(ENV_SAVE_PATH)
	TimeSystem.autosave_on_day_end = true
	WorldState.reset_to_new_game()


func test_successful_inspection_cleans_zone_and_prevents_dengue() -> void:
	var res: Dictionary = EnvironmentalInspectionService.record_inspection_result(
		WorldState,
		EventBus,
		&"zone_quintal_fam_a",
		true,
		4,
		4,
		0
	)
	assert_true(bool(res.get("ok", false)))
	assert_eq(str(res.get("status", "")), "clean")
	assert_eq(EnvironmentalInspectionService.get_total_mosquito_level(WorldState), 0)
	assert_false(bool(WorldState.get_fact(&"env_mosquitoes_active", false)))

	TimeSystem.advance_period(4)
	assert_eq(EnvironmentalInspectionService.get_infected_npcs(WorldState).size(), 0)


func test_failed_inspection_spawns_mosquitoes_infects_npc_routes_to_ubs_and_recovers() -> void:
	# 1. Fail inspection at Quintal da Familia Alencar.
	var fail_res: Dictionary = EnvironmentalInspectionService.record_inspection_result(
		WorldState,
		EventBus,
		&"zone_quintal_fam_a",
		false,
		1,
		4,
		3
	)
	assert_true(bool(fail_res.get("ok", false)))
	assert_eq(str(fail_res.get("status", "")), "infested")
	assert_gt(EnvironmentalInspectionService.get_total_mosquito_level(WorldState), 0)
	assert_true(bool(WorldState.get_fact(&"env_mosquitoes_active", false)))

	# 2. Advance one period: a vulnerable resident gets dengue and goes to the UBS.
	TimeSystem.advance_period(1)
	var infected: Array[StringName] = EnvironmentalInspectionService.get_infected_npcs(WorldState)
	assert_eq(infected.size(), 1, "An infested zone should cause a resident to contract dengue.")
	var sick_npc: StringName = infected[0]
	assert_eq(
		str(WorldState.npc_states[sick_npc]["location_id"]),
		"loc_ubs",
		"Infected NPC must route directly to the UBS."
	)
	assert_true(
		str(WorldState.npc_states[sick_npc]["marker_name"]).begins_with("spot_dengue_"),
		"Infected NPC should use a UBS dengue waiting spot."
	)

	# 3. Verify save/load roundtrip preserves infestation and dengue state.
	assert_eq(SaveSystem.save_to_path(ENV_SAVE_PATH), OK)
	WorldState.reset_to_new_game()
	assert_eq(EnvironmentalInspectionService.get_infected_npcs(WorldState).size(), 0)
	assert_eq(SaveSystem.load_from_path(ENV_SAVE_PATH), OK)
	assert_true(EnvironmentalInspectionService.is_npc_infected(WorldState, sick_npc))
	assert_gt(EnvironmentalInspectionService.get_total_mosquito_level(WorldState), 0)

	# 4. Alex re-inspects and succeeds: mosquitoes clear, and on next day the NPC recovers.
	var clean_res: Dictionary = EnvironmentalInspectionService.record_inspection_result(
		WorldState,
		EventBus,
		&"zone_quintal_fam_a",
		true,
		4,
		4,
		0
	)
	assert_eq(str(clean_res.get("status", "")), "clean")
	assert_eq(EnvironmentalInspectionService.get_total_mosquito_level(WorldState), 0)

	TimeSystem.sleep_until_morning()
	assert_false(
		EnvironmentalInspectionService.is_npc_infected(WorldState, sick_npc),
		"Once the infested zone is cleaned, the resident should recover on the next day."
	)


func test_world_scenes_contain_inspection_sites_mosquito_swarm_and_ubs_dengue_spots() -> void:
	var bairro_packed: PackedScene = load("res://scenes/maps/BairroPraca.tscn") as PackedScene
	assert_not_null(bairro_packed)
	var bairro: Node = bairro_packed.instantiate()
	add_child_autofree(bairro)
	assert_not_null(bairro.get_node_or_null("EntitiesYSort/InspectionQuintalFamA"))
	assert_not_null(bairro.get_node_or_null("EntitiesYSort/InspectionTerrenoLeste"))
	assert_not_null(bairro.get_node_or_null("EntitiesYSort/InspectionQuintalFamC"))
	assert_not_null(bairro.get_node_or_null("MosquitoSwarm"))

	var ubs_packed: PackedScene = load("res://scenes/interiors/UBS.tscn") as PackedScene
	assert_not_null(ubs_packed)
	var ubs: Node = ubs_packed.instantiate()
	add_child_autofree(ubs)
	assert_not_null(ubs.get_node_or_null("NPCSpots/spot_dengue_1"))
	assert_not_null(ubs.get_node_or_null("NPCSpots/spot_dengue_2"))
	assert_not_null(ubs.get_node_or_null("NPCSpots/spot_dengue_3"))
