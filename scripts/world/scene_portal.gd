class_name ScenePortal
extends Area2D
## Triggers a location transition when the player enters the portal area.

@export var target_location_id: StringName = &""
@export var target_spawn_id: StringName = &"spawn_default"


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		var err: Error = body_entered.connect(_on_body_entered)
		if err != OK:
			push_warning("ScenePortal failed to connect body_entered.")


func _on_body_entered(body: Node2D) -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null and bool(router.get("is_transitioning")):
		return
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and body != null and body.is_in_group(&"player") and target_location_id != &"":
		bus.emit_signal(&"scene_change_requested", target_location_id, target_spawn_id)
