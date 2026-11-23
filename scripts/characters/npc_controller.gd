class_name NPCController
extends CharacterBody2D
## Visual and interactive representation of an NPC backed by CharacterData.

@export var character_id: StringName = &""
@export var dialogue_start_node: String = "start"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interactable: Interactable = $Interactable

var _character_data: CharacterData = null
var _idle_time: float = 0.0


func _ready() -> void:
	add_to_group(&"npcs")
	_idle_time = float(abs(hash(character_id)) % 100) * 0.06
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		var err: Error = interactable.interacted.connect(_on_interacted)
		if err != OK:
			push_warning("NPCController failed to connect interacted.")
	apply_character_data()


func _process(delta: float) -> void:
	if sprite != null:
		_idle_time += delta * 2.4
		sprite.offset.y = -12.0 + sin(_idle_time) * 0.45


func apply_character_data() -> void:
	var registry: Node = get_node_or_null("/root/DataRegistry")
	if registry == null or character_id == &"":
		return
	_character_data = registry.call(&"get_character", character_id) as CharacterData
	if _character_data == null:
		return
	if sprite != null:
		var custom_path: String = "res://assets/characters/%s.png" % String(character_id)
		if ResourceLoader.exists(custom_path):
			var tex: Texture2D = load(custom_path) as Texture2D
			if tex != null:
				sprite.texture = tex
				sprite.modulate = Color.WHITE
		else:
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
