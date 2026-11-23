class_name NPCController
extends CharacterBody2D
## Visual and interactive representation of an NPC backed by CharacterData.

@export var character_id: StringName = &""
@export var dialogue_start_node: String = "start"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interactable: Interactable = $Interactable

var _character_data: CharacterData = null


func _ready() -> void:
	add_to_group(&"npcs")
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		var err: Error = interactable.interacted.connect(_on_interacted)
		if err != OK:
			push_warning("NPCController failed to connect interacted.")
	apply_character_data()


func apply_character_data() -> void:
	var registry: Node = get_node_or_null("/root/DataRegistry")
	if registry == null or character_id == &"":
		return
	_character_data = registry.call(&"get_character", character_id) as CharacterData
	if _character_data == null:
		return
	if sprite != null:
		sprite.modulate = _character_data.tint_color
	if interactable != null:
		interactable.prompt_text = "Falar com %s" % _character_data.display_name


func _on_interacted(_actor: Node) -> void:
	if _character_data == null:
		apply_character_data()
	if _character_data == null or _character_data.dialogue_id == &"":
		return
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(
			&"dialogue_requested",
			_character_data.dialogue_id,
			dialogue_start_node,
			{"npc_id": character_id}
		)
