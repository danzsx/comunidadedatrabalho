extends Node
## Root host scene initializing SceneRouter, DialogueService, and booting into the active location.

@onready var scene_container: Node = $SceneContainer
@onready var alex: PlayerController = $Alex
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var dialogue_service: DialogueService = $DialogueService
@onready var dialogue_ui: DialogueUI = $DialogueUI


func _ready() -> void:
	SceneRouter.register_host(scene_container, fade_rect, alex)
	dialogue_service.bind_host(alex, dialogue_ui)
	var err: Error = SceneRouter.change_location_immediate(
		WorldState.current_location_id,
		WorldState.current_spawn_id
	)
	if err != OK:
		push_error("Main failed to load initial location '%s' (err=%d)" % [String(WorldState.current_location_id), err])
