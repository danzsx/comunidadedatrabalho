class_name InteractionSystem
extends Area2D
## Detects the best nearby Interactable in front of Alex and triggers it on input.

@export var reach_distance: float = 12.0

var _candidates: Array[Interactable] = []
var _current_target: Interactable = null

@onready var _prompt_label: Label = get_node_or_null("PromptLabel") as Label


func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		var err1: Error = area_entered.connect(_on_area_entered)
		if err1 != OK:
			push_warning("InteractionSystem failed to connect area_entered.")
	if not area_exited.is_connected(_on_area_exited):
		var err2: Error = area_exited.connect(_on_area_exited)
		if err2 != OK:
			push_warning("InteractionSystem failed to connect area_exited.")
	if _prompt_label != null:
		_prompt_label.visible = false


func _physics_process(_delta: float) -> void:
	var owner_player: Node = get_parent()
	if owner_player != null and owner_player.has_method(&"get_facing"):
		var facing: Vector2 = owner_player.call(&"get_facing") as Vector2
		position = facing.normalized() * reach_distance + Vector2(0.0, -4.0)
	_refresh_target()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact"):
		return
	var owner_player: Node = get_parent()
	if owner_player != null and owner_player.has_method(&"is_movement_locked"):
		if bool(owner_player.call(&"is_movement_locked")):
			return
	if _current_target != null and is_instance_valid(_current_target):
		_current_target.trigger(owner_player)
		get_viewport().set_input_as_handled()


func get_current_target() -> Interactable:
	return _current_target


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and not (area in _candidates):
		_candidates.append(area as Interactable)


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_candidates.erase(area as Interactable)


func _refresh_target() -> void:
	var best: Interactable = null
	var best_score: float = -INF
	var valid_candidates: Array[Interactable] = []

	for item: Interactable in _candidates:
		if not is_instance_valid(item):
			continue
		valid_candidates.append(item)
		if not item.enabled:
			continue
		var dist: float = global_position.distance_to(item.global_position)
		var score: float = float(item.interaction_priority) * 1000.0 - dist
		if score > best_score:
			best_score = score
			best = item

	_candidates = valid_candidates
	_current_target = best

	if _prompt_label != null:
		var owner_player: Node = get_parent()
		var locked: bool = owner_player != null and owner_player.has_method(&"is_movement_locked") and bool(owner_player.call(&"is_movement_locked"))
		if _current_target != null and not locked:
			_prompt_label.text = "[E] %s" % _current_target.prompt_text
			_prompt_label.visible = true
			_prompt_label.global_position = _current_target.global_position + Vector2(-36.0, -34.0)
		else:
			_prompt_label.visible = false
