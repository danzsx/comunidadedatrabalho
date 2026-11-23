extends GutTest


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()
	TimeSystem.autosave_on_day_end = false


func after_each() -> void:
	TimeSystem.autosave_on_day_end = true
	WorldState.reset_to_new_game()


func test_relationship_4d_axes_are_strictly_independent() -> void:
	watch_signals(EventBus)
	RelationshipService.adjust(WorldState, EventBus, &"npc_b_1", &"familiarity", 3)

	assert_eq(RelationshipService.get_axis(WorldState, &"npc_b_1", &"familiarity"), 3)
	assert_eq(RelationshipService.get_axis(WorldState, &"npc_b_1", &"trust"), 0)
	assert_eq(RelationshipService.get_axis(WorldState, &"npc_b_1", &"affinity"), 0)
	assert_eq(RelationshipService.get_axis(WorldState, &"npc_b_1", &"cooperation"), 0)
	assert_signal_emitted_with_parameters(EventBus, "relationship_changed", [&"npc_b_1", &"familiarity", 3])


func test_field_visit_supportive_branch_and_day5_consequence() -> void:
	FieldVisitService.assign_visit(WorldState, EventBus, &"fam_a", "Visita Familia Alencar")
	assert_eq(FieldVisitService.get_visit_stage(WorldState, &"fam_a"), "assigned")

	var added1: bool = FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_receitas", "Receitas sem horario.")
	var dup1: bool = FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_receitas", "Receitas sem horario.")
	assert_true(added1)
	assert_false(dup1, "Duplicate clue should not be recorded twice.")
	assert_eq(FieldVisitService.get_visit_stage(WorldState, &"fam_a"), "observing")

	var added2: bool = FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_umidade", "Umidade no corredor.")
	assert_true(added2)
	FieldVisitService.mark_resident_listened(WorldState, EventBus, &"fam_a", &"npc_a_2", true)
	assert_eq(FieldVisitService.get_visit_stage(WorldState, &"fam_a"), "ready_to_report")

	FieldVisitService.submit_ubs_referral(WorldState, EventBus, &"fam_a", &"supportive")
	assert_eq(FieldVisitService.get_visit_stage(WorldState, &"fam_a"), "reported_supportive")
	assert_eq(WorldState.get_fact(&"fam_a_outcome_supportive"), true)

	# Advance to Day 5 Morning -> supportive consequence event must trigger.
	WorldState.day = 5
	WorldState.period = 0
	var triggered: Array[StringName] = WorldSimulationTick.process_tick(true, WorldState, DataRegistry, EventBus)
	assert_true(&"evt_fam_a_consequence_supportive" in triggered)
	assert_eq(WorldState.get_fact(&"fam_a_consequence_supportive"), true)
	assert_gt(RelationshipService.get_axis(WorldState, &"npc_a_2", &"cooperation"), 0)


func test_field_visit_rushed_branch_and_day5_consequence() -> void:
	FieldVisitService.assign_visit(WorldState, EventBus, &"fam_a", "Visita Familia Alencar")
	FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_receitas", "Receitas.")
	FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_costura", "Costura.")
	FieldVisitService.mark_resident_listened(WorldState, EventBus, &"fam_a", &"npc_a_2", false)
	FieldVisitService.submit_ubs_referral(WorldState, EventBus, &"fam_a", &"rushed")

	assert_eq(FieldVisitService.get_visit_stage(WorldState, &"fam_a"), "reported_rushed")
	WorldState.day = 5
	WorldState.period = 0
	var triggered: Array[StringName] = WorldSimulationTick.process_tick(true, WorldState, DataRegistry, EventBus)
	assert_true(&"evt_fam_a_consequence_rushed" in triggered)
	assert_eq(WorldState.get_fact(&"fam_a_consequence_rushed"), true)
	assert_lt(RelationshipService.get_axis(WorldState, &"npc_a_2", &"trust"), 0)


func test_notebook_ui_renders_records_cleanly() -> void:
	FieldVisitService.assign_visit(WorldState, EventBus, &"fam_a", "Visita Familia Alencar")
	FieldVisitService.register_observation(WorldState, EventBus, &"fam_a", &"clue_fam_a_receitas", "Receitas na mesa.")

	var packed: PackedScene = load("res://scenes/ui/NotebookUI.tscn") as PackedScene
	var ui: NotebookUI = packed.instantiate() as NotebookUI
	add_child_autofree(ui)
	ui.refresh()
	assert_string_contains(ui.activities_text.text, "Visita Familia Alencar")
	assert_string_contains(ui.families_text.text, "Receitas na mesa.")
	assert_string_contains(ui.relations_text.text, "Hortencia")
