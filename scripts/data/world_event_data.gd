class_name WorldEventData
extends Resource
## Declarative world event evaluated during period/day transitions.

@export var id: StringName = &""
@export var title: String = ""
@export var can_happen_offscreen: bool = true
@export var once: bool = true
@export var min_day: int = 1
@export var target_period: int = -1 # -1 means any period
@export var conditions: Array[Dictionary] = []
@export var effects: Array[Dictionary] = []
@export var notification_hint: String = ""
