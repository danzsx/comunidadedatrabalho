class_name CharacterData
extends Resource
## Static profile for an NPC or playable character, decoupled from scene nodes.

@export var id: StringName = &""
@export var display_name: String = ""
@export var age: int = 0
@export var occupation: String = ""
@export var family_id: StringName = &""
@export var residence_id: StringName = &""
@export var personality_tags: Array[StringName] = []
@export var interests: Array[StringName] = []
@export var knowledge_tags: Array[StringName] = []
@export var tint_color: Color = Color.WHITE
@export var portrait_set: Dictionary = {}
@export var sprite_frames: SpriteFrames = null
@export var dialogue_id: StringName = &""
