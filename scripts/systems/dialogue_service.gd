class_name DialogueService
extends Node
## Facade over Dialogue Manager v3 connecting .dialogue files safely to WorldState.

signal line_changed(line: DialogueLine)
signal dialogue_closed(dialogue_id: StringName)

const _DM_SCRIPT: Script = preload("res://addons/dialogue_manager/dialogue_manager.gd")

var is_active: bool = false
var current_dialogue_id: StringName = &""
var current_line: DialogueLine = null

var _dm: Node = null
var _current_resource: DialogueResource = null
var _player: Node = null
var _dialogue_ui: Node = null


func _ready() -> void:
	_dm = _DM_SCRIPT.new()
	_dm.name = "DialogueManagerRuntime"
	add_child(_dm)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"dialogue_requested", _on_dialogue_requested):
		var err: Error = bus.connect(&"dialogue_requested", _on_dialogue_requested)
		if err != OK:
			push_warning("DialogueService failed to connect dialogue_requested.")


func bind_host(player: Node, dialogue_ui: Node) -> void:
	_player = player
	_dialogue_ui = dialogue_ui
	if _dialogue_ui != null and _dialogue_ui.has_signal(&"advance_requested"):
		if not _dialogue_ui.is_connected(&"advance_requested", _on_ui_advance_requested):
			var err: Error = _dialogue_ui.connect(&"advance_requested", _on_ui_advance_requested)
			if err != OK:
				push_warning("DialogueService failed to connect DialogueUI advance_requested.")


func _on_dialogue_requested(dialogue_id: StringName, start_node: String, _context: Dictionary) -> void:
	await start_dialogue(dialogue_id, start_node)


func _on_ui_advance_requested(next_id: String) -> void:
	await advance(next_id)


func start_dialogue(dialogue_id: StringName, start_node: String = "start") -> Error:
	if is_active:
		return ERR_BUSY
	var registry: Node = get_node_or_null("/root/DataRegistry")
	if registry == null:
		return ERR_UNCONFIGURED
	var path: String = str(registry.call(&"get_dialogue_path", dialogue_id))
	if path.is_empty():
		return ERR_FILE_NOT_FOUND

	var res: DialogueResource = load(path) as DialogueResource
	if res == null:
		return ERR_CANT_OPEN

	_current_resource = res
	current_dialogue_id = dialogue_id
	is_active = true

	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", true)

	await _step_to(start_node)
	return OK


func advance(next_id: String = "") -> void:
	if not is_active or _current_resource == null:
		return
	var target_id: String = next_id
	if target_id.is_empty() and current_line != null:
		target_id = current_line.next_id
	await _step_to(target_id)


func _step_to(line_key: String) -> void:
	if _dm == null or _current_resource == null:
		_close_dialogue()
		return
	var line: DialogueLine = await _dm.call(&"get_next_dialogue_line", _current_resource, line_key, [self]) as DialogueLine
	if line == null:
		_close_dialogue()
		return

	current_line = line
	line_changed.emit(line)
	if _dialogue_ui != null and _dialogue_ui.has_method(&"show_line"):
		_dialogue_ui.call(&"show_line", line)


func _close_dialogue() -> void:
	var finished_id: StringName = current_dialogue_id
	is_active = false
	current_dialogue_id = &""
	current_line = null
	_current_resource = null

	if _dialogue_ui != null and _dialogue_ui.has_method(&"hide_dialogue"):
		_dialogue_ui.call(&"hide_dialogue")
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", false)

	dialogue_closed.emit(finished_id)
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(&"dialogue_finished", finished_id)


# --- Safe API exposed to .dialogue scripts via extra_game_states ---

func has_fact(fact_id: String) -> bool:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return false
	return bool(ws.call(&"get_fact", StringName(fact_id), false))


func get_fact(fact_id: String, default_value: Variant = null) -> Variant:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return default_value
	return ws.call(&"get_fact", StringName(fact_id), default_value)


func set_fact(fact_id: String, value: Variant = true) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		EffectApplier.apply_one({"type": "set_fact", "fact_id": fact_id, "value": value}, ws, get_node_or_null("/root/EventBus"))


func inc_fact(fact_id: String, amount: int = 1) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		EffectApplier.apply_one({"type": "inc_fact", "fact_id": fact_id, "amount": amount}, ws, get_node_or_null("/root/EventBus"))


func get_rel(npc_id: String, axis: String) -> int:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return 0
	var rels: Dictionary = ws.get("relationships") as Dictionary
	var npc_rel: Dictionary = rels.get(StringName(npc_id), {}) as Dictionary
	return int(npc_rel.get(StringName(axis), npc_rel.get(axis, 0)))


func add_rel(npc_id: String, axis: String, delta: int) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		EffectApplier.apply_one(
			{"type": "add_relationship", "npc_id": npc_id, "axis": axis, "delta": delta},
			ws,
			get_node_or_null("/root/EventBus")
		)


func give_item(item_id: String, amount: int = 1) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		EffectApplier.apply_one({"type": "give_item", "item_id": item_id, "amount": amount}, ws, get_node_or_null("/root/EventBus"))


func has_item(item_id: String, min_count: int = 1) -> bool:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return false
	return ConditionEvaluator.evaluate_one({"type": "item_count_gte", "item_id": item_id, "value": min_count}, ws)


func inc_career(axis: String, delta: int = 1) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		EffectApplier.apply_one({"type": "inc_career_axis", "axis": axis, "delta": delta}, ws, get_node_or_null("/root/EventBus"))


func assign_visit(family_id: String, title: String) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		FieldVisitService.assign_visit(ws, get_node_or_null("/root/EventBus"), StringName(family_id), title)


func get_visit_stage(family_id: String) -> String:
	var ws: Node = get_node_or_null("/root/WorldState")
	return FieldVisitService.get_visit_stage(ws, StringName(family_id))


func get_clue_count(family_id: String) -> int:
	var ws: Node = get_node_or_null("/root/WorldState")
	return HouseholdRecordService.get_clue_count(ws, StringName(family_id))


func mark_listened(family_id: String, npc_id: String, respectful: bool) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		FieldVisitService.mark_resident_listened(ws, get_node_or_null("/root/EventBus"), StringName(family_id), StringName(npc_id), respectful)


func submit_referral(family_id: String, approach: String) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		FieldVisitService.submit_ubs_referral(ws, get_node_or_null("/root/EventBus"), StringName(family_id), StringName(approach))
