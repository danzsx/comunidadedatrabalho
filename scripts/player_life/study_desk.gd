class_name StudyDesk
extends Interactable
## Interactive study desk in CasaAlex allowing Alex to study for university.


func _ready() -> void:
	prompt_text = "Estudar para a faculdade"
	if not interacted.is_connected(_on_interacted):
		var err: Error = interacted.connect(_on_interacted)
		if err != OK:
			push_warning("StudyDesk failed to connect interacted.")


func _on_interacted(_actor: Node) -> void:
	HomeActivityService.perform_study_session(
		get_node_or_null("/root/WorldState"),
		get_node_or_null("/root/TimeSystem"),
		get_node_or_null("/root/EventBus")
	)
