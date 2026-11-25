class_name PauseSaveUI
extends CanvasLayer
## Pause and Save/Load menu (Esc) supporting Slot 1, Slot 2, and Autosave.

@onready var status_label: Label = $Root/Panel/Margin/VBox/StatusLabel
@onready var slot1_info: Label = $Root/Panel/Margin/VBox/Slot1Row/Slot1Info
@onready var slot2_info: Label = $Root/Panel/Margin/VBox/Slot2Row/Slot2Info
@onready var autosave_info: Label = $Root/Panel/Margin/VBox/AutosaveRow/AutosaveInfo

var _player: Node = null
var _dialogue_service: Node = null
var _notebook_ui: Node = null
var _project_ui: Node = null
var _audio_feedback: Node = null
var _inspection_ui: Node = null
var _garden_board_ui: Node = null


func _ready() -> void:
	visible = false


func bind_host(
	player: Node,
	dialogue_service: Node,
	notebook_ui: Node,
	project_ui: Node,
	audio_feedback: Node,
	inspection_ui: Node = null,
	garden_board_ui: Node = null
) -> void:
	_player = player
	_dialogue_service = dialogue_service
	_notebook_ui = notebook_ui
	_project_ui = project_ui
	_audio_feedback = audio_feedback
	_inspection_ui = inspection_ui
	_garden_board_ui = garden_board_ui


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _dialogue_service != null and bool(_dialogue_service.get("is_active")):
		return
	if _inspection_ui != null and bool(_inspection_ui.get("is_active")):
		return
	if _garden_board_ui != null and bool(_garden_board_ui.get("visible")):
		return
	if _notebook_ui != null and bool(_notebook_ui.get("visible")):
		return
	if _project_ui != null and bool(_project_ui.get("visible")):
		return
	toggle()
	get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	refresh_slots()
	status_label.text = ""
	visible = true
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", true)


func close() -> void:
	visible = false
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", false)


func refresh_slots() -> void:
	if slot1_info == null:
		return
	slot1_info.text = _format_meta("Slot 1", SaveSystem.get_slot_meta(1))
	slot2_info.text = _format_meta("Slot 2", SaveSystem.get_slot_meta(2))
	autosave_info.text = _format_meta("Autosave", SaveSystem.get_autosave_meta())


func _format_meta(prefix: String, meta: Dictionary) -> String:
	if meta.is_empty():
		return "%s: (vazio)" % prefix
	var d: int = int(meta.get("day", 1))
	var p: String = TimeSystem.get_period_name(int(meta.get("period", 0)))
	return "%s: Dia %d · %s" % [prefix, d, p]


func _on_continue_pressed() -> void:
	close()


func _on_save_slot_1_pressed() -> void:
	_do_save(1)


func _on_load_slot_1_pressed() -> void:
	_do_load(1)


func _on_save_slot_2_pressed() -> void:
	_do_save(2)


func _on_load_slot_2_pressed() -> void:
	_do_load(2)


func _on_load_autosave_pressed() -> void:
	var err: Error = SaveSystem.load_autosave()
	if err == OK:
		var _apply_err: Error = SaveSystem.apply_loaded_state_to_world()
		status_label.text = "Autosave carregado!"
		close()
	else:
		status_label.text = "Nenhum autosave disponivel ainda."


func _on_quit_pressed() -> void:
	get_tree().quit()


func _do_save(slot: int) -> void:
	var err: Error = SaveSystem.save_slot(slot)
	if err == OK:
		if _audio_feedback != null and _audio_feedback.has_method(&"play_save_chime"):
			_audio_feedback.call(&"play_save_chime")
		status_label.text = "Salvo no Slot %d!" % slot
		refresh_slots()
	else:
		status_label.text = "Erro ao salvar (cod %d)." % err


func _do_load(slot: int) -> void:
	var err: Error = SaveSystem.load_slot(slot)
	if err == OK:
		var _apply_err: Error = SaveSystem.apply_loaded_state_to_world()
		status_label.text = "Slot %d carregado!" % slot
		close()
	else:
		status_label.text = "Slot %d esta vazio." % slot
