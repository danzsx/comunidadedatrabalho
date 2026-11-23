class_name WorldPatcher
extends Node2D
## Switches persistent map state layers (Stage0, Stage1, Stage2...) based on WorldState.world_patches.

@export var patch_id: StringName = &""


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"world_patch_applied", _on_world_patch_applied):
		var err: Error = bus.connect(&"world_patch_applied", _on_world_patch_applied)
		if err != OK:
			push_warning("WorldPatcher failed to connect world_patch_applied.")
	refresh_from_world_state()


func _on_world_patch_applied(applied_patch_id: StringName, active_stage: int) -> void:
	if applied_patch_id == patch_id:
		apply_stage(active_stage)


func refresh_from_world_state() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var stage: int = 0
	if ws != null and patch_id != &"":
		var patches: Dictionary = ws.get("world_patches") as Dictionary
		stage = int(patches.get(patch_id, 0))
	apply_stage(stage)


func apply_stage(active_stage: int) -> void:
	var target_name: String = "Stage%d" % active_stage
	var matched: bool = false
	for child: Node in get_children():
		if child is CanvasItem:
			var is_match: bool = child.name == target_name
			(child as CanvasItem).visible = is_match
			if is_match:
				matched = true
	# Fallback to highest stage <= active_stage if exact stage node doesn't exist.
	if not matched and get_child_count() > 0:
		var fallback: CanvasItem = get_child(0) as CanvasItem
		if fallback != null:
			fallback.visible = true
