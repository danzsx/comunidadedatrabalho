class_name RoutineEntry
extends Resource
## Declarative NPC schedule entry resolved by RoutineResolver on period/day ticks.

@export var id: StringName = &""
@export var npc_id: StringName = &""
@export var day_filter: Array[int] = [] # Empty means all days
@export var period: int = -1 # -1 means any period; 0..3 = Manha/Tarde/Noite/Madrugada
@export var location_id: StringName = &"" # Empty means off-map / away from neighborhood
@export var marker_name: StringName = &"spot_default"
@export var priority: int = 0
@export var conditions: Array[Dictionary] = []
@export var ambient_line: String = ""
