extends GutTest

const VISIT_SAVE_PATH: String = "user://saves/test_home_visit_mvp_roundtrip.json"


func before_each() -> void:
	WorldState.reset_to_new_game()
	DataRegistry.reload_all()
	TimeSystem.autosave_on_day_end = false
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)


func after_each() -> void:
	if FileAccess.file_exists(VISIT_SAVE_PATH):
		var _err: Error = DirAccess.remove_absolute(VISIT_SAVE_PATH)
	TimeSystem.autosave_on_day_end = true
	WorldState.reset_to_new_game()


func test_npc_availability_and_residence_door_states() -> void:
	# Morning (period 0): Dona Lucia is home and available.
	WorldState.period = 0
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)
	var avail_m: Dictionary = NPCAvailabilityService.get_availability(WorldState, DataRegistry, &"npc_a_2")
	assert_eq(str(avail_m.get("status", "")), "available")
	var door_m: Dictionary = NPCAvailabilityService.check_residence_entry(WorldState, DataRegistry, &"fam_a", &"npc_a_2")
	assert_true(bool(door_m.get("allowed", false)))

	# Afternoon (period 1): Dona Lucia is out on the plaza sidewalk.
	WorldState.period = 1
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)
	var avail_t: Dictionary = NPCAvailabilityService.get_availability(WorldState, DataRegistry, &"npc_a_2")
	assert_eq(str(avail_t.get("status", "")), "out_at_plaza")

	# Night (period 2): Dona Lucia is home but tired.
	WorldState.period = 2
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)
	var avail_n: Dictionary = NPCAvailabilityService.get_availability(WorldState, DataRegistry, &"npc_a_2")
	assert_eq(str(avail_n.get("status", "")), "busy_tired")

	# Late night / Madrugada (period 3): resting, door blocks intrusive entry.
	WorldState.period = 3
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)
	var avail_late: Dictionary = NPCAvailabilityService.get_availability(WorldState, DataRegistry, &"npc_a_2")
	assert_eq(str(avail_late.get("status", "")), "resting_night")
	var door_late: Dictionary = NPCAvailabilityService.check_residence_entry(WorldState, DataRegistry, &"fam_a", &"npc_a_2")
	assert_false(bool(door_late.get("allowed", true)), "Residence door must block entry during Madrugada.")

	# Verify BairroPraca has ResidenceDoorFamA and gated PortalFamA.
	var bairro_packed: PackedScene = load("res://scenes/maps/BairroPraca.tscn") as PackedScene
	var bairro: Node = bairro_packed.instantiate()
	add_child_autofree(bairro)
	assert_not_null(bairro.get_node_or_null("EntitiesYSort/ResidenceDoorFamA"))
	var portal: ScenePortal = bairro.get_node_or_null("Portals/PortalFamA") as ScenePortal
	assert_not_null(portal)
	assert_true(portal.require_door_interaction)


func test_dona_lucia_branching_first_visit_save_load_and_contextual_return() -> void:
	var ds: DialogueService = DialogueService.new()
	add_child_autofree(ds)

	# 1. Start first visit dialogue with Dona Lucia.
	var err: Error = await ds.start_dialogue(&"fam_a", "start", {"npc_id": &"npc_a_2"})
	assert_eq(err, OK)
	assert_true(ds.is_active)

	# Advance through opening lines until first branching posture choice appears.
	var safety: int = 0
	while ds.is_active and ds.current_line != null and ds.current_line.responses.is_empty() and safety < 10:
		await ds.advance()
		safety += 1
	assert_not_null(ds.current_line)
	assert_gte(ds.current_line.responses.size(), 3, "First visit should present 3 posture choices.")

	# Pick choice 0 (empathetic listening).
	var emp_resp: DialogueResponse = ds.current_line.responses[0] as DialogueResponse
	await ds.advance(emp_resp.next_id)
	assert_eq(str(HouseholdRecordService.get_memory(WorldState, &"fam_a", "first_impression", "")), "empathetic")
	assert_gt(RelationshipService.get_axis(WorldState, &"npc_a_2", &"trust"), 0)
	assert_gt(RelationshipService.get_axis(WorldState, &"npc_a_2", &"affinity"), 0)

	# Advance to topics menu.
	safety = 0
	while ds.is_active and ds.current_line != null and ds.current_line.responses.is_empty() and safety < 10:
		await ds.advance()
		safety += 1
	assert_not_null(ds.current_line)
	assert_gte(ds.current_line.responses.size(), 2, "Topics menu should present branching options.")

	# Pick topic 0 (Seu Antonio's prescriptions -> creates memory + pending follow-up).
	var meds_resp: DialogueResponse = ds.current_line.responses[0] as DialogueResponse
	await ds.advance(meds_resp.next_id)
	assert_true(HouseholdRecordService.has_memory(WorldState, &"fam_a", "discussed_meds"))
	assert_true(HouseholdRecordService.has_pending_followup(WorldState, &"fam_a", "followup_receitas"))

	# Advance back to topics menu and select the final choice to close the visit.
	safety = 0
	while ds.is_active and ds.current_line != null and ds.current_line.responses.is_empty() and safety < 10:
		await ds.advance()
		safety += 1
	assert_not_null(ds.current_line)
	var close_resp: DialogueResponse = ds.current_line.responses[ds.current_line.responses.size() - 1] as DialogueResponse
	await ds.advance(close_resp.next_id)

	# Finish remaining closing line.
	safety = 0
	while ds.is_active and safety < 10:
		await ds.advance()
		safety += 1
	assert_false(ds.is_active)

	assert_eq(HouseholdRecordService.get_visit_count(WorldState, &"fam_a"), 1)
	assert_eq(HouseholdRecordService.get_visit_history(WorldState, &"fam_a").size(), 1)

	# 2. Save & reload to verify full persistence of visit history, memories, follow-ups, and trust.
	var trust_after_v1: int = RelationshipService.get_axis(WorldState, &"npc_a_2", &"trust")
	assert_eq(SaveSystem.save_to_path(VISIT_SAVE_PATH), OK)
	WorldState.reset_to_new_game()
	assert_eq(HouseholdRecordService.get_visit_count(WorldState, &"fam_a"), 0)
	assert_eq(SaveSystem.load_from_path(VISIT_SAVE_PATH), OK)

	assert_eq(HouseholdRecordService.get_visit_count(WorldState, &"fam_a"), 1)
	assert_eq(RelationshipService.get_axis(WorldState, &"npc_a_2", &"trust"), trust_after_v1)
	assert_true(HouseholdRecordService.has_memory(WorldState, &"fam_a", "discussed_meds"))
	assert_true(HouseholdRecordService.has_pending_followup(WorldState, &"fam_a", "followup_receitas"))

	# 3. Return on next day: Dona Lucia remembers previous visit & offers to resolve pending follow-up.
	TimeSystem.sleep_until_morning()
	var err2: Error = await ds.start_dialogue(&"fam_a", "start", {"npc_id": &"npc_a_2"})
	assert_eq(err2, OK)

	var seen_memory_text: bool = false
	safety = 0
	while ds.is_active and ds.current_line != null and ds.current_line.responses.is_empty() and safety < 10:
		if ds.current_line.text.contains("receitas") or ds.current_line.text.contains("volta"):
			seen_memory_text = true
		await ds.advance()
		safety += 1
	assert_true(seen_memory_text, "Return visit greeting should reference the previous visit.")
	assert_not_null(ds.current_line)

	# First response should be resolving the pending meds follow-up.
	var resolve_resp: DialogueResponse = ds.current_line.responses[0] as DialogueResponse
	assert_string_contains(resolve_resp.text, "receitas")
	await ds.advance(resolve_resp.next_id)
	safety = 0
	while ds.is_active and safety < 10:
		await ds.advance()
		safety += 1

	assert_false(HouseholdRecordService.has_pending_followup(WorldState, &"fam_a", "followup_receitas"))
	assert_eq(HouseholdRecordService.get_visit_count(WorldState, &"fam_a"), 2)
	assert_eq(HouseholdRecordService.get_visit_history(WorldState, &"fam_a").size(), 2)
	assert_gt(RelationshipService.get_axis(WorldState, &"npc_a_2", &"trust"), trust_after_v1)

	# 4. Verify NotebookUI displays history & follow-ups.
	var nb_packed: PackedScene = load("res://scenes/ui/NotebookUI.tscn") as PackedScene
	var nb: NotebookUI = nb_packed.instantiate() as NotebookUI
	add_child_autofree(nb)
	nb.refresh()
	assert_string_contains(nb.families_text.text, "Visitas registradas: 2")
	assert_string_contains(nb.families_text.text, "[Concluída]")
	assert_string_contains(nb.families_text.text, "Histórico de Visitas:")


func test_dialogue_ui_reference_layout_portrait_and_heart_bond() -> void:
	var packed: PackedScene = load("res://scenes/ui/DialogueUI.tscn") as PackedScene
	assert_not_null(packed)
	var ui: DialogueUI = packed.instantiate() as DialogueUI
	add_child_autofree(ui)

	assert_not_null(ui.portrait_rect)
	assert_not_null(ui.heart_icon)
	assert_not_null(ui.choices_box)
	assert_true(ResourceLoader.exists("res://assets/characters/portraits/bust_npc_a_2.png"))
	assert_true(ResourceLoader.exists("res://assets/characters/portraits/bust_alex.png"))

	# Heart color changes cleanly between initial bond and warm partnership.
	ui.heart_icon.set_bond_from_axes({&"trust": 0, &"affinity": 0, &"familiarity": 0, &"cooperation": 0})
	var col_initial: Color = ui.heart_icon.heart_color
	ui.heart_icon.set_bond_from_axes({&"trust": 4, &"affinity": 3, &"familiarity": 2, &"cooperation": 2})
	var col_strong: Color = ui.heart_icon.heart_color
	assert_ne(col_initial, col_strong)
