class_name ProjectSite
extends Interactable
## Interactive world spot (e.g., degraded garden bed) opening ProjectUI for a project.

@export var project_id: StringName = &"proj_jardim_praca"


func _ready() -> void:
	prompt_text = "Inspecionar canteiro da praca"
	if not interacted.is_connected(_on_interacted):
		var err: Error = interacted.connect(_on_interacted)
		if err != OK:
			push_warning("ProjectSite failed to connect interacted.")


func _on_interacted(_actor: Node) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	if ws != null and not ProjectService.is_unlocked(ws, project_id):
		if bus != null:
			bus.emit_signal(&"notification_requested", "O canteiro esta abandonado. Talvez Dona Rosa saiba como recupera-lo.", &"project")
		return
	for node: Node in get_tree().get_nodes_in_group(&"project_ui"):
		if node.has_method(&"open"):
			node.call(&"open")
			return
