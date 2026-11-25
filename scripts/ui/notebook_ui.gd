class_name NotebookUI
extends CanvasLayer
## Field Notebook UI displaying ACS demands, family clues/records, and 4D relationships.

@onready var activities_text: RichTextLabel = $Root/Panel/Margin/VBox/Tabs/Atividades/ActivitiesText
@onready var families_text: RichTextLabel = $Root/Panel/Margin/VBox/Tabs/Familias/FamiliesText
@onready var relations_text: RichTextLabel = $Root/Panel/Margin/VBox/Tabs/Relacoes/RelationsText

var _player: Node = null
var _dialogue_service: Node = null


func _ready() -> void:
	visible = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		if not bus.is_connected(&"household_record_updated", _on_data_changed):
			var err1: Error = bus.connect(&"household_record_updated", _on_data_changed)
			if err1 != OK:
				push_warning("NotebookUI failed to connect household_record_updated.")
		if not bus.is_connected(&"relationship_changed", _on_rel_changed):
			var err2: Error = bus.connect(&"relationship_changed", _on_rel_changed)
			if err2 != OK:
				push_warning("NotebookUI failed to connect relationship_changed.")


func bind_host(player: Node, dialogue_service: Node) -> void:
	_player = player
	_dialogue_service = dialogue_service


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_notebook"):
		if _dialogue_service != null and bool(_dialogue_service.get("is_active")):
			return
		for ui: Node in get_tree().get_nodes_in_group(&"environmental_inspection_ui"):
			if bool(ui.get("is_active")):
				return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	refresh()
	visible = true
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", true)


func close() -> void:
	visible = false
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", false)


func _on_data_changed(_family_id: StringName) -> void:
	if visible:
		refresh()


func _on_rel_changed(_npc_id: StringName, _axis: StringName, _new_value: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	if activities_text == null or families_text == null or relations_text == null:
		return
	activities_text.text = _build_activities_summary()
	families_text.text = _build_families_summary()
	relations_text.text = _build_relations_summary()


func _build_activities_summary() -> String:
	var sections: PackedStringArray = []
	var visits: Dictionary = WorldState.field_visits
	if visits.is_empty():
		sections.append("Visitas Domiciliares:\nNenhuma visita registrada ainda. Visite a UBS e converse com Hortencia.")
	else:
		var lines: PackedStringArray = ["Visitas Domiciliares:"]
		for fam_id_var: Variant in visits.keys():
			var v: Dictionary = visits[fam_id_var] as Dictionary
			var title: String = str(v.get("title", "Visita domiciliar"))
			var stage: String = str(v.get("stage", "assigned"))
			var stage_label: String = _stage_to_pt(stage)
			var clues: int = HouseholdRecordService.get_clue_count(WorldState, StringName(str(fam_id_var)))
			lines.append("• %s\n  Estado: %s | Pistas anotadas: %d" % [title, stage_label, clues])
		sections.append("\n".join(lines))

	var env_lines: PackedStringArray = ["Vigilância Ambiental (Focos de Mosquito):"]
	for zone_key: String in EnvironmentalInspectionService.get_zone_ids():
		var z_def: Dictionary = EnvironmentalInspectionService.get_zone_def(StringName(zone_key))
		var z_state: Dictionary = EnvironmentalInspectionService.get_zone_state(WorldState, StringName(zone_key))
		var status: String = str(z_state.get("status", "pending"))
		var status_pt: String = "Pendente de inspeção"
		if status == "clean":
			status_pt = "Limpo (focos eliminados)"
		elif status == "infested":
			status_pt = "INFESTADO — mosquitos ativos!"
		env_lines.append("• %s: %s" % [str(z_def.get("title", zone_key)), status_pt])

	var infected: Array[StringName] = EnvironmentalInspectionService.get_infected_npcs(WorldState)
	if not infected.is_empty():
		var names: PackedStringArray = []
		for npc_id: StringName in infected:
			var ch: CharacterData = DataRegistry.get_character(npc_id)
			names.append(ch.display_name if ch != null else String(npc_id))
		env_lines.append("ALERTA UBS — Moradores com dengue em atendimento: %s" % ", ".join(names))
	sections.append("\n".join(env_lines))

	var g: Dictionary = CommunityGardenService.get_summary_counts(WorldState)
	if bool(g.get("unlocked", false)):
		sections.append(
			"Horta Comunitária (Nível %d/3):\n• Plantados: %d | Prontos p/ colher: %d | Secos: %d\n• Colheitas: %d | Alimentos compartilhados: %d" % [
				int(g.get("level", 0)),
				int(g.get("planted", 0)),
				int(g.get("ready", 0)),
				int(g.get("dry", 0)),
				int(g.get("total_harvests", 0)),
				int(g.get("total_shares", 0)),
			]
		)
	else:
		sections.append("Horta Comunitária:\n• Ainda não iniciada — converse com Dona Rosa na praça para abrir os primeiros canteiros.")

	return "\n\n".join(sections)


func _build_families_summary() -> String:
	var lines: PackedStringArray = []
	for fam_id: StringName in DataRegistry.get_all_family_ids():
		var fam: FamilyData = DataRegistry.get_family(fam_id)
		if fam == null:
			continue
		var rec: Dictionary = HouseholdRecordService.get_record(WorldState, fam_id)
		var notes: Array = rec.get("observations", []) as Array
		var status: String = _referral_to_pt(str(rec.get("referral_status", "none")))
		var visit_count: int = int(rec.get("visit_count", 0))
		var block: String = "%s — %s\nVisitas registradas: %d | Encaminhamento: %s" % [
			fam.family_name,
			fam.summary,
			visit_count,
			status,
		]

		var followups: Array = rec.get("pending_followups", []) as Array
		if not followups.is_empty():
			block += "\n  Pendências e Retornos:"
			for f_var: Variant in followups:
				if f_var is Dictionary:
					var f_item: Dictionary = f_var as Dictionary
					var is_done: bool = str(f_item.get("status", "pending")) == "resolved"
					var mark: String = "[Concluída]" if is_done else "[Pendente · Dia %d]" % int(f_item.get("due_day", 1))
					block += "\n    %s %s" % [mark, str(f_item.get("description", ""))]

		var history: Array = rec.get("visit_history", []) as Array
		if not history.is_empty():
			block += "\n  Histórico de Visitas:"
			var start_idx: int = maxi(0, history.size() - 3)
			for i: int in range(start_idx, history.size()):
				if history[i] is Dictionary:
					var h: Dictionary = history[i] as Dictionary
					var p_name: String = TimeSystem.get_period_name(int(h.get("period", 0)))
					block += "\n    #%d (Dia %d · %s): %s" % [
						int(h.get("visit_number", i + 1)),
						int(h.get("day", 1)),
						p_name,
						str(h.get("summary", "")),
					]

		if notes.is_empty():
			block += "\n  (Sem observações de campo ainda)"
		else:
			block += "\n  Observações de Campo:"
			for n: Variant in notes:
				block += "\n    - %s" % str(n)
		lines.append(block)
	return "\n\n".join(lines)


func _build_relations_summary() -> String:
	var lines: PackedStringArray = []
	for char_id: StringName in DataRegistry.get_all_character_ids():
		var ch: CharacterData = DataRegistry.get_character(char_id)
		if ch == null:
			continue
		var axes: Dictionary = RelationshipService.get_all_axes(WorldState, char_id)
		var bond: String = RelationshipService.describe_bond(axes)
		lines.append(
			"%s (%s) — %s\n  Confianca: %d | Afinidade: %d | Familiaridade: %d | Cooperacao: %d" % [
				ch.display_name,
				ch.occupation,
				bond,
				int(axes[&"trust"]),
				int(axes[&"affinity"]),
				int(axes[&"familiarity"]),
				int(axes[&"cooperation"]),
			]
		)
	return "\n\n".join(lines)


func _stage_to_pt(stage: String) -> String:
	match stage:
		"assigned":
			return "Pendente — ir ate a residencia e observar o ambiente"
		"observing":
			return "Em andamento — observar detalhes e ouvir moradores"
		"ready_to_report":
			return "Pronta para articular na UBS com Hortencia"
		"reported_supportive":
			return "Articulada com abordagem acolhedora (acompanhar no Dia 5)"
		"reported_rushed":
			return "Registrada com pressa (acompanhar repercussao no Dia 5)"
		_:
			return stage


func _referral_to_pt(status: String) -> String:
	match status:
		"referred_support":
			return "Articulado com rede de apoio na UBS"
		"closed_strained":
			return "Registro burocratico (vinculo tenso)"
		"pending_ubs":
			return "Aguardando retorno na UBS"
		_:
			return "Sem encaminhamento"
