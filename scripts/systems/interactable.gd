class_name Interactable
extends Area2D
## Reusable world interaction target (NPCs, doors, clues, home objects).

signal interacted(actor: Node)

@export var prompt_text: String = "Interagir"
@export var interaction_priority: int = 0
@export var enabled: bool = true


func trigger(actor: Node) -> void:
	if not enabled:
		return
	interacted.emit(actor)
