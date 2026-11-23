class_name ProjectData
extends Resource
## Static definition for a relationship-unlocked personal or community project.

@export var id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var involved_npcs: Array[StringName] = []
@export var unlock_conditions: Array[Dictionary] = []
@export var stages: Array[Dictionary] = []
@export var world_patch_id: StringName = &""
