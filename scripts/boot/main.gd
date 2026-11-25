extends Node
## Root host scene initializing SceneRouter, DialogueService, UIs, AudioFeedback, and booting into the active location.

@onready var scene_container: Node = $SceneContainer
@onready var alex: PlayerController = $Alex
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var dialogue_service: DialogueService = $DialogueService
@onready var dialogue_ui: DialogueUI = $DialogueUI
@onready var notebook_ui: NotebookUI = $NotebookUI
@onready var project_ui: ProjectUI = $ProjectUI
@onready var environmental_inspection_ui: EnvironmentalInspectionUI = $EnvironmentalInspectionUI
@onready var garden_hotbar_ui: GardenHotbarUI = $GardenHotbarUI
@onready var garden_board_ui: GardenBoardUI = $GardenBoardUI
@onready var pause_save_ui: PauseSaveUI = $PauseSaveUI
@onready var audio_feedback: AudioFeedback = $AudioFeedback


func _ready() -> void:
	SceneRouter.register_host(scene_container, fade_rect, alex)
	dialogue_service.bind_host(alex, dialogue_ui)
	notebook_ui.bind_host(alex, dialogue_service)
	project_ui.bind_host(alex, dialogue_service)
	environmental_inspection_ui.bind_host(alex, dialogue_service, audio_feedback)
	garden_hotbar_ui.bind_host(alex, dialogue_service)
	garden_board_ui.bind_host(alex, dialogue_service)
	pause_save_ui.bind_host(alex, dialogue_service, notebook_ui, project_ui, audio_feedback, environmental_inspection_ui, garden_board_ui)
	var err: Error = SceneRouter.change_location_immediate(
		WorldState.current_location_id,
		WorldState.current_spawn_id
	)
	if err != OK:
		push_error("Main failed to load initial location '%s' (err=%d)" % [String(WorldState.current_location_id), err])
