class_name ItemData
extends Resource
## Static definition for an inventory item or key document with narrative purpose.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: StringName = &"material" # key_doc, material, garden, personal
@export var icon: Texture2D = null
@export var stackable: bool = true
