class_name FamilyData
extends Resource
## Static definition of a household/family in the community.

@export var id: StringName = &""
@export var family_name: String = ""
@export var residence_id: StringName = &""
@export var initial_members: Array[StringName] = []
@export var summary: String = ""
@export var initial_conditions: Array[StringName] = []
@export var notes_seed: String = ""
