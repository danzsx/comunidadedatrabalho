extends GutTest


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()
	TimeSystem.autosave_on_day_end = false
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)


func after_each() -> void:
	TimeSystem.autosave_on_day_end = true
	WorldState.reset_to_new_game()


func test_7_days_headless_simulation_routines_and_independent_event() -> void:
	# Day 1 Morning: Dona Rosa should be at BairroPraca and Bruno at CasaFamiliaC.
	assert_eq(str(WorldState.npc_states[&"npc_b_1"]["location_id"]), "loc_bairro_praca")
	assert_eq(str(WorldState.npc_states[&"npc_c_2"]["location_id"]), "loc_casa_fam_c")
	assert_false(WorldState.get_fact(&"fam_c_bruno_left_for_shift", false))

	# Advance to Night (period 2) of Day 1: Dona Rosa moves home to CasaFamiliaB.
	TimeSystem.advance_period(2)
	assert_eq(WorldState.day, 1)
	assert_eq(WorldState.period, 2)
	assert_eq(str(WorldState.npc_states[&"npc_b_1"]["location_id"]), "loc_casa_fam_b")

	# Advance remaining 26 periods to complete 7 full days (total 28 periods) with zero player intervention.
	TimeSystem.advance_period(26)
	assert_eq(WorldState.day, 8, "After 28 periods from Day 1 Morning, calendar should reach Day 8 Morning.")
	assert_eq(WorldState.week, 2)
	assert_eq(WorldState.period, 0)

	# Verify independent event fired on Day 4 without Alex visiting Family C.
	assert_true(&"evt_fam_c_independent_shift" in WorldState.completed_events)
	assert_eq(WorldState.get_fact(&"fam_c_bruno_left_for_shift"), true)

	# Verify Bruno's routine updated to away (empty location) and Family C logged history.
	assert_eq(str(WorldState.npc_states[&"npc_c_2"]["location_id"]), "")
	var fam_c_state: Dictionary = WorldState.family_states.get(&"fam_c", {}) as Dictionary
	var history: Array = fam_c_state.get("history", []) as Array
	assert_gt(history.size(), 0, "Family C should record Bruno's independent shift in history.")


func test_sleep_until_morning_advances_day_cleanly() -> void:
	WorldState.day = 1
	WorldState.period = 1
	TimeSystem.sleep_until_morning()
	assert_eq(WorldState.day, 2)
	assert_eq(WorldState.period, 0)
