extends GutTest

const GARDEN_SAVE_PATH: String = "user://saves/test_community_garden_roundtrip.json"


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()
	TimeSystem.autosave_on_day_end = false
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)


func after_each() -> void:
	if FileAccess.file_exists(GARDEN_SAVE_PATH):
		var _err: Error = DirAccess.remove_absolute(GARDEN_SAVE_PATH)
	TimeSystem.autosave_on_day_end = true
	WorldState.reset_to_new_game()


func test_full_crop_lifecycle_regrow_fertilizer_and_mild_neglect() -> void:
	# 1. Unlock garden -> starter seeds granted, 4 plots overgrown, 12 locked.
	assert_true(CommunityGardenService.unlock_garden(WorldState, EventBus))
	assert_true(CommunityGardenService.is_unlocked(WorldState))
	assert_eq(InventorySystem.get_count(WorldState, &"item_semente_cheiro_verde"), 2)
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_0")["state"]), "overgrown")
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_4")["state"]), "locked")

	# 2. Prepare, fertilize, plant & water Cheiro-Verde (regrows) and Alface (annual).
	assert_true(bool(CommunityGardenService.prepare_plot(WorldState, EventBus, &"plot_0")["ok"]))
	assert_true(bool(CommunityGardenService.prepare_plot(WorldState, EventBus, &"plot_1")["ok"]))
	assert_true(bool(CommunityGardenService.prepare_plot(WorldState, EventBus, &"plot_2")["ok"]))

	InventorySystem.add_item(WorldState, &"item_composto_organico", 1)
	assert_true(bool(CommunityGardenService.fertilize_plot(WorldState, EventBus, &"plot_0")["ok"]))
	assert_eq(InventorySystem.get_count(WorldState, &"item_composto_organico"), 0)

	assert_true(bool(CommunityGardenService.plant_seed(WorldState, DataRegistry, EventBus, &"plot_0", &"crop_cheiro_verde")["ok"]))
	assert_true(bool(CommunityGardenService.plant_seed(WorldState, DataRegistry, EventBus, &"plot_1", &"crop_alface")["ok"]))
	assert_true(bool(CommunityGardenService.plant_seed(WorldState, DataRegistry, EventBus, &"plot_2", &"crop_cenoura")["ok"]))

	assert_true(bool(CommunityGardenService.water_plot(WorldState, EventBus, &"plot_0")["ok"]))
	assert_true(bool(CommunityGardenService.water_plot(WorldState, EventBus, &"plot_1")["ok"]))
	# Leave plot_2 (cenoura) dry to test mild neglect (never dies!).

	# Advance 2 periods -> fertilized Cheiro-Verde (growth_target=3, +2 per tick) reaches harvestable!
	TimeSystem.advance_period(2)
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_0")["state"]), "harvestable")

	# Harvest Cheiro-Verde -> base_yield(2) + fertilizer bonus(1) = 3, and regrows to stage 1!
	var h0: Dictionary = CommunityGardenService.harvest_plot(WorldState, DataRegistry, EventBus, &"plot_0")
	assert_true(bool(h0["ok"]))
	assert_eq(int(h0["amount"]), 3)
	assert_eq(InventorySystem.get_count(WorldState, &"item_colheita_cheiro_verde"), 3)
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_0")["state"]), "planted")
	assert_eq(int(CommunityGardenService.get_plot_state(WorldState, &"plot_0")["stage"]), 1)

	# Keep watering Alface until harvestable, then verify annual resets to tilled.
	var _r: int = CommunityGardenService.refill_watering_can(WorldState, EventBus)
	for _step: int in range(6):
		var st1: String = str(CommunityGardenService.get_plot_state(WorldState, &"plot_1")["state"])
		if st1 == "harvestable":
			break
		var _w: Dictionary = CommunityGardenService.water_plot(WorldState, EventBus, &"plot_1")
		TimeSystem.advance_period(1)
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_1")["state"]), "harvestable")
	var h1: Dictionary = CommunityGardenService.harvest_plot(WorldState, DataRegistry, EventBus, &"plot_1")
	assert_true(bool(h1["ok"]))
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_1")["state"]), "tilled")

	# Verify dry plot_2 never died and resumes growth after watering.
	TimeSystem.sleep_until_morning()
	var p2: Dictionary = CommunityGardenService.get_plot_state(WorldState, &"plot_2")
	assert_eq(str(p2["state"]), "planted", "Neglected dry plant must pause growth, never die.")
	assert_gt(int(p2["dry_ticks"]), 0)
	var _w2: Dictionary = CommunityGardenService.water_plot(WorldState, EventBus, &"plot_2")
	assert_eq(int(CommunityGardenService.get_plot_state(WorldState, &"plot_2")["dry_ticks"]), 0)


func test_spontaneous_npc_help_respects_dengue_status() -> void:
	var _u: bool = CommunityGardenService.unlock_garden(WorldState, EventBus)
	var _p: Dictionary = CommunityGardenService.prepare_plot(WorldState, EventBus, &"plot_0")
	var _s: Dictionary = CommunityGardenService.plant_seed(WorldState, DataRegistry, EventBus, &"plot_0", &"crop_cenoura")
	# Build Dona Rosa affinity so she helps spontaneously.
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_1", &"affinity", 3)

	TimeSystem.sleep_until_morning()
	var p0: Dictionary = CommunityGardenService.get_plot_state(WorldState, &"plot_0")
	assert_eq(str(p0["watered_by_npc"]), "npc_b_1", "Healthy Dona Rosa should water dry plot spontaneously.")
	assert_eq(int(p0["moisture"]), 2)

	# Now infect Dona Rosa with dengue and verify she does NOT help while sick at UBS.
	var env_state: Dictionary = WorldState.get("environmental_state") as Dictionary
	var cases: Dictionary = env_state.get(&"dengue_cases", {}) as Dictionary
	cases["npc_b_1"] = {"infected_day": WorldState.day, "zone_id": "zone_terreno_leste", "recovery_days_left": 2}
	env_state[&"dengue_cases"] = cases
	WorldState.set("environmental_state", env_state)

	var _p1: Dictionary = CommunityGardenService.prepare_plot(WorldState, EventBus, &"plot_1")
	var _s1: Dictionary = CommunityGardenService.plant_seed(WorldState, DataRegistry, EventBus, &"plot_1", &"crop_cenoura")
	TimeSystem.sleep_until_morning()
	var p1: Dictionary = CommunityGardenService.get_plot_state(WorldState, &"plot_1")
	assert_ne(str(p1["watered_by_npc"]), "npc_b_1", "Infected Dona Rosa at UBS must not water plots.")


func test_sharing_upgrades_compost_and_save_roundtrip() -> void:
	var _u: bool = CommunityGardenService.unlock_garden(WorldState, EventBus)
	InventorySystem.add_item(WorldState, &"item_colheita_couve", 2)
	InventorySystem.add_item(WorldState, &"item_colheita_alface", 2)
	InventorySystem.add_item(WorldState, &"item_colheita_cenoura", 2)

	# Share favorite Couve with Dona Lucia -> bonus affinity + trust, daily cap enforced.
	var s1: Dictionary = CommunityGardenService.share_produce_with_npc(WorldState, DataRegistry, EventBus, &"npc_a_2", &"item_colheita_couve")
	assert_true(bool(s1["ok"]))
	assert_true(bool(s1["is_favorite"]))
	assert_false(CommunityGardenService.can_share_today(WorldState, &"npc_a_2"))
	assert_gt(RelationshipService.get_axis(WorldState, &"npc_a_2", &"affinity"), 0)

	# Share with Camila and Tiago -> total_shares = 3, Tiago familiarity >= 2 -> Upgrade 1 unlocked!
	var _s2: Dictionary = CommunityGardenService.share_produce_with_npc(WorldState, DataRegistry, EventBus, &"npc_c_1", &"item_colheita_alface")
	var _s3: Dictionary = CommunityGardenService.share_produce_with_npc(WorldState, DataRegistry, EventBus, &"npc_b_2", &"item_colheita_cenoura")
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_2", &"familiarity", 1)
	assert_true(CommunityGardenService.try_upgrade_garden(WorldState, EventBus))
	assert_eq(CommunityGardenService.get_level(WorldState), 1)
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_4")["state"]), "overgrown")

	# Upgrade 2 -> watering can 12x + compost generation after 2 days.
	var gs: Dictionary = WorldState.get("garden_state") as Dictionary
	gs[&"total_harvests"] = 6
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_1", &"cooperation", 2)
	assert_true(CommunityGardenService.try_upgrade_garden(WorldState, EventBus))
	assert_eq(CommunityGardenService.get_level(WorldState), 2)
	assert_eq(int((WorldState.get("garden_state") as Dictionary)[&"watering_can_max"]), 12)

	TimeSystem.sleep_until_morning()
	TimeSystem.sleep_until_morning()
	assert_gt(int(CommunityGardenService.get_summary_counts(WorldState)["compost_available"]), 0)
	assert_gt(CommunityGardenService.collect_compost(WorldState, EventBus), 0)

	# Full Save/Load roundtrip.
	assert_eq(SaveSystem.save_to_path(GARDEN_SAVE_PATH), OK)
	WorldState.reset_to_new_game()
	assert_false(CommunityGardenService.is_unlocked(WorldState))
	assert_eq(SaveSystem.load_from_path(GARDEN_SAVE_PATH), OK)
	assert_true(CommunityGardenService.is_unlocked(WorldState))
	assert_eq(CommunityGardenService.get_level(WorldState), 2)
	assert_eq(str(CommunityGardenService.get_plot_state(WorldState, &"plot_8")["state"]), "overgrown")


func test_horta_scene_and_ui_integrity() -> void:
	var errors: Array[String] = DataRegistry.validate_integrity()
	assert_eq(errors.size(), 0, "DataRegistry errors: %s" % str(errors))
	assert_true(DataRegistry.has_location(&"loc_horta_comunitaria"))
	assert_eq(DataRegistry.get_all_crop_ids().size(), 6)

	var horta_packed: PackedScene = load("res://scenes/maps/HortaComunitaria.tscn") as PackedScene
	assert_not_null(horta_packed)
	var horta: Node = horta_packed.instantiate()
	add_child_autofree(horta)
	assert_not_null(horta.get_node_or_null("EntitiesYSort/Plot0"))
	assert_not_null(horta.get_node_or_null("EntitiesYSort/Plot15"))
	assert_not_null(horta.get_node_or_null("EntitiesYSort/WaterSource"))
	assert_not_null(horta.get_node_or_null("EntitiesYSort/CompostBox"))
	assert_not_null(horta.get_node_or_null("EntitiesYSort/GardenBoard"))
	assert_not_null(horta.get_node_or_null("Portals/PortalBairro"))

	var hotbar_packed: PackedScene = load("res://scenes/ui/GardenHotbarUI.tscn") as PackedScene
	var hotbar: GardenHotbarUI = hotbar_packed.instantiate() as GardenHotbarUI
	add_child_autofree(hotbar)
	hotbar.select_tool(2)
	assert_eq(hotbar.get_selected_tool(), 2)
