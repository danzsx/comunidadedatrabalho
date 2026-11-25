class_name ResidenceDoor
extends Interactable
## Interactive front door for a neighborhood residence: knocks, checks resident availability, and enters.

@export var family_id: StringName = &"fam_a"
@export var primary_npc_id: StringName = &"npc_a_2"
@export var residence_label: String = "Casa da Família Alencar"
@export var portal_path: NodePath = NodePath("")
@export var target_location_id: StringName = &"loc_casa_fam_a"
@export var target_spawn_id: StringName = &"spawn_door"


func _ready() -> void:
	interaction_priority = 5
	if not interacted.is_connected(_on_interacted):
		var err1: Error = interacted.connect(_on_interacted)
		if err1 != OK:
			push_warning("ResidenceDoor failed to connect interacted.")
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"period_changed", _on_period_changed):
		var err2: Error = bus.connect(&"period_changed", _on_period_changed)
		if err2 != OK:
			push_warning("ResidenceDoor failed to connect period_changed.")
	refresh_prompt()


func _on_period_changed(_day: int, _period: int) -> void:
	refresh_prompt()


func refresh_prompt() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var reg: Node = get_node_or_null("/root/DataRegistry")
	if ws != null and int(ws.get("period")) == 3:
		prompt_text = "Bater à porta — %s (Madrugada)" % residence_label
		return
	var avail: Dictionary = NPCAvailabilityService.get_availability(ws, reg, primary_npc_id)
	var status: String = str(avail.get("status", "available"))
	if status == "out_at_plaza":
		prompt_text = "Entrar — %s (Dona Lúcia na praça)" % residence_label
	elif status == "at_ubs_dengue":
		prompt_text = "Entrar — %s (Dona Lúcia na UBS)" % residence_label
	else:
		prompt_text = "Bater à porta — %s" % residence_label


func _on_interacted(_actor: Node) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var reg: Node = get_node_or_null("/root/DataRegistry")
	var bus: Node = get_node_or_null("/root/EventBus")

	var check: Dictionary = NPCAvailabilityService.check_residence_entry(ws, reg, family_id, primary_npc_id)
	var allowed: bool = bool(check.get("allowed", true))
	var msg: String = str(check.get("message", ""))

	if bus != null and not msg.is_empty():
		bus.emit_signal(&"notification_requested", msg, &"visit" if allowed else &"info")

	if not allowed:
		return

	if not portal_path.is_empty():
		var portal: Node = get_node_or_null(portal_path)
		if portal != null and portal.has_method(&"activate_portal"):
			portal.call(&"activate_portal")
			return

	if bus != null and target_location_id != &"":
		bus.emit_signal(&"scene_change_requested", target_location_id, target_spawn_id)
