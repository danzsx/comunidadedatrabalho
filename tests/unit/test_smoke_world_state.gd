extends GutTest

const TEST_SAVE_PATH: String = "user://saves/test_smoke_m0.json"


func after_each() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		var err: Error = DirAccess.remove_absolute(TEST_SAVE_PATH)
		assert_eq(err, OK, "Temporary test save file should be removed cleanly.")
	WorldState.reset_to_new_game()


func test_world_state_defaults() -> void:
	WorldState.reset_to_new_game()
	assert_eq(WorldState.schema_version, 1)
	assert_eq(WorldState.day, 1)
	assert_eq(WorldState.period, 0)
	assert_eq(WorldState.current_location_id, &"loc_casa_alex")


func test_set_fact_emits_event_bus_signal() -> void:
	watch_signals(EventBus)
	WorldState.set_fact(&"ubs_briefed_day1", true)
	assert_eq(WorldState.get_fact(&"ubs_briefed_day1"), true)
	assert_signal_emitted_with_parameters(EventBus, "world_fact_changed", [&"ubs_briefed_day1", true])


func test_save_and_load_roundtrip_preserves_state() -> void:
	WorldState.reset_to_new_game()
	WorldState.day = 3
	WorldState.period = 2
	WorldState.current_location_id = &"loc_bairro_praca"
	WorldState.player_position = Vector2(128.0, 96.0)
	WorldState.set_fact(&"met_hortencia", true)
	WorldState.set_fact(&"notes_count", 4)
	WorldState.career_trajectory[&"acs_engagement"] = 5

	var save_err: Error = SaveSystem.save_to_path(TEST_SAVE_PATH)
	assert_eq(save_err, OK, "SaveSystem should write JSON save file cleanly.")

	WorldState.reset_to_new_game()
	assert_eq(WorldState.day, 1)
	assert_null(WorldState.get_fact(&"met_hortencia"))

	var load_err: Error = SaveSystem.load_from_path(TEST_SAVE_PATH)
	assert_eq(load_err, OK, "SaveSystem should load JSON save file cleanly.")

	assert_eq(WorldState.day, 3)
	assert_eq(WorldState.period, 2)
	assert_eq(WorldState.current_location_id, &"loc_bairro_praca")
	assert_eq(WorldState.player_position, Vector2(128.0, 96.0))
	assert_eq(WorldState.get_fact(&"met_hortencia"), true)
	assert_eq(WorldState.get_fact(&"notes_count"), 4)
	assert_eq(WorldState.career_trajectory[&"acs_engagement"], 5)
