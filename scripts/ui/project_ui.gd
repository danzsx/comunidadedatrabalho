class_name ProjectUI
extends CanvasLayer
## Contextual Projects & Backpack UI with clear have/need counters and stage completion.

@onready var projects_box: VBoxContainer = $Root/Panel/Margin/VBox/Split/ProjectsScroll/ProjectsBox
@onready var inventory_text: RichTextLabel = $Root/Panel/Margin/VBox/Split/InventoryBox/InventoryText

var _player: Node = null
var _dialogue_service: Node = null


func _ready() -> void:
	add_to_group(&"project_ui")
	visible = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"project_stage_changed", _on_project_changed):
		var err: Error = bus.connect(&"project_stage_changed", _on_project_changed)
		if err != OK:
			push_warning("ProjectUI failed to connect project_stage_changed.")


func bind_host(player: Node, dialogue_service: Node) -> void:
	_player = player
	_dialogue_service = dialogue_service


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_projects"):
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


func _on_project_changed(_project_id: StringName, _stage: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	if projects_box == null or inventory_text == null:
		return
	for child: Node in projects_box.get_children():
		child.queue_free()

	var any_unlocked: bool = false
	for proj_id: StringName in DataRegistry.get_all_project_ids():
		if not ProjectService.is_unlocked(WorldState, proj_id):
			continue
		any_unlocked = true
		var proj: ProjectData = DataRegistry.get_project(proj_id)
		if proj == null:
			continue
		_add_project_card(proj)

	if not any_unlocked:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum projeto desbloqueado ainda.\nConverse com os moradores e construa vinculos no bairro."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override(&"font_color", Color(0.28, 0.24, 0.2, 1.0))
		empty_lbl.add_theme_font_size_override(&"font_size", 9)
		projects_box.add_child(empty_lbl)

	inventory_text.text = _build_inventory_text()


func _add_project_card(proj: ProjectData) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override(&"separation", 3)

	var stage: int = ProjectService.get_stage(WorldState, proj.id)
	var completed: bool = ProjectService.is_completed(WorldState, proj.id)

	var title_lbl := Label.new()
	title_lbl.text = "%s (%d/%d)" % [proj.title, stage, proj.stages.size()]
	title_lbl.add_theme_color_override(&"font_color", Color(0.2, 0.14, 0.08, 1.0))
	title_lbl.add_theme_font_size_override(&"font_size", 10)
	card.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = proj.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override(&"font_color", Color(0.3, 0.25, 0.2, 1.0))
	desc_lbl.add_theme_font_size_override(&"font_size", 8)
	card.add_child(desc_lbl)

	if completed:
		var done_lbl := Label.new()
		done_lbl.text = "Concluido! O bairro ja reflete essa transformacao."
		done_lbl.add_theme_color_override(&"font_color", Color(0.16, 0.45, 0.2, 1.0))
		done_lbl.add_theme_font_size_override(&"font_size", 9)
		card.add_child(done_lbl)
	elif stage < proj.stages.size():
		var st_def: Dictionary = proj.stages[stage]
		var stage_lbl := Label.new()
		stage_lbl.text = "Proxima etapa: " + str(st_def.get("label", ""))
		stage_lbl.add_theme_color_override(&"font_color", Color(0.2, 0.16, 0.12, 1.0))
		stage_lbl.add_theme_font_size_override(&"font_size", 9)
		card.add_child(stage_lbl)

		var req_items: Dictionary = st_def.get("required_items", {}) as Dictionary
		var req_lines: PackedStringArray = []
		for key: Variant in req_items.keys():
			var item_id: StringName = StringName(str(key))
			var need: int = int(req_items[key])
			var have: int = InventorySystem.get_count(WorldState, item_id)
			var item_data: ItemData = DataRegistry.get_item(item_id)
			var item_name: String = item_data.display_name if item_data != null else String(item_id)
			req_lines.append("  • %s: %d/%d" % [item_name, have, need])

		var req_lbl := Label.new()
		req_lbl.text = "\n".join(req_lines)
		req_lbl.add_theme_color_override(&"font_color", Color(0.24, 0.2, 0.16, 1.0))
		req_lbl.add_theme_font_size_override(&"font_size", 8)
		card.add_child(req_lbl)

		var btn := Button.new()
		btn.text = "Concluir Etapa"
		btn.disabled = not ProjectService.can_advance_stage(WorldState, DataRegistry, proj.id)
		var pid: StringName = proj.id
		var err: Error = btn.pressed.connect(func() -> void: _on_advance_pressed(pid))
		if err != OK:
			push_warning("ProjectUI failed to connect advance button.")
		card.add_child(btn)

	projects_box.add_child(card)


func _on_advance_pressed(project_id: StringName) -> void:
	var ok: bool = ProjectService.advance_stage(WorldState, DataRegistry, EventBus, project_id)
	if ok:
		refresh()


func _build_inventory_text() -> String:
	if WorldState.inventory.is_empty():
		return "Mochila vazia."
	var lines: PackedStringArray = []
	for item_id_var: Variant in WorldState.inventory.keys():
		var item_id: StringName = StringName(str(item_id_var))
		var count: int = int(WorldState.inventory[item_id_var])
		var data: ItemData = DataRegistry.get_item(item_id)
		var label: String = data.display_name if data != null else String(item_id)
		lines.append("• %s x%d" % [label, count])
	return "\n".join(lines)
