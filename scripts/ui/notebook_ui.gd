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
	var visits: Dictionary = WorldState.field_visits
	if visits.is_empty():
		return "Nenhuma atividade registrada ainda.\n\nVisite a UBS e converse com Hortencia para iniciar seu primeiro acompanhamento no bairro."

	var lines: PackedStringArray = []
	for fam_id_var: Variant in visits.keys():
		var v: Dictionary = visits[fam_id_var] as Dictionary
		var title: String = str(v.get("title", "Visita domiciliar"))
		var stage: String = str(v.get("stage", "assigned"))
		var stage_label: String = _stage_to_pt(stage)
		var clues: int = HouseholdRecordService.get_clue_count(WorldState, StringName(str(fam_id_var)))
		lines.append("• %s\n  Estado: %s | Pistas anotadas: %d" % [title, stage_label, clues])
	return "\n\n".join(lines)


func _build_families_summary() -> String:
	var lines: PackedStringArray = []
	for fam_id: StringName in DataRegistry.get_all_family_ids():
		var fam: FamilyData = DataRegistry.get_family(fam_id)
		if fam == null:
			continue
		var rec: Dictionary = HouseholdRecordService.get_record(WorldState, fam_id)
		var notes: Array = rec.get("observations", []) as Array
		var status: String = _referral_to_pt(str(rec.get("referral_status", "none")))
		var block: String = "%s — %s\nEncaminhamento: %s" % [fam.family_name, fam.summary, status]
		if notes.is_empty():
			block += "\n  (Sem observacoes de campo ainda)"
		else:
			for n: Variant in notes:
				block += "\n  - %s" % str(n)
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
