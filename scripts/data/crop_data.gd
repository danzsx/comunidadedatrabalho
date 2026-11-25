class_name CropData
extends Resource
## Static data definition for a Community Garden plant variety.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var seed_item_id: StringName = &""
@export var produce_item_id: StringName = &""
@export var growth_target: int = 4
@export var water_drain_per_day_period: int = 1
@export var regrows: bool = false
@export var regrow_stage: int = 1
@export var base_yield: int = 2
@export var required_garden_level: int = 0
@export var favorite_npcs: Array[StringName] = []
@export var sprite_sheet_path: String = ""
