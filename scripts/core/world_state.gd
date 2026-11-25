extends Node
## Single source of truth for all mutable game state.

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var day: int = 1
var week: int = 1
var month: int = 1
var season: StringName = &"spring"
var period: int = 0 # 0=Manha, 1=Tarde, 2=Noite, 3=Madrugada

var current_location_id: StringName = &"loc_casa_alex"
var current_spawn_id: StringName = &"spawn_bed"
var player_position: Vector2 = Vector2.ZERO

var facts: Dictionary = {}
var relationships: Dictionary = {}
var npc_states: Dictionary = {}
var family_states: Dictionary = {}
var household_records: Dictionary = {}
var field_visits: Dictionary = {}
var inventory: Dictionary = {}
var projects: Dictionary = {}
var world_patches: Dictionary = {}
var completed_events: Array[StringName] = []
var pending_events: Array[Dictionary] = []
var career_trajectory: Dictionary = {}
var unlocked_regions: Array[StringName] = []
var environmental_state: Dictionary = {}
var garden_state: Dictionary = {}


func _ready() -> void:
	reset_to_new_game()


func reset_to_new_game() -> void:
	schema_version = SCHEMA_VERSION
	day = 1
	week = 1
	month = 1
	season = &"spring"
	period = 0
	current_location_id = &"loc_casa_alex"
	current_spawn_id = &"spawn_bed"
	player_position = Vector2.ZERO
	facts = {}
	relationships = {}
	npc_states = {}
	family_states = {}
	household_records = {}
	field_visits = {}
	inventory = {}
	projects = {}
	world_patches = {}
	completed_events = []
	pending_events = []
	career_trajectory = {
		&"acs_engagement": 0,
		&"academic_focus": 0,
		&"community_ties": 0,
		&"self_reflection": 0,
	}
	unlocked_regions = [&"reg_bairro_central"]
	environmental_state = {}
	garden_state = {}


func set_fact(fact_id: StringName, value: Variant) -> void:
	facts[fact_id] = value
	EventBus.world_fact_changed.emit(fact_id, value)


func get_fact(fact_id: StringName, default_value: Variant = null) -> Variant:
	return facts.get(fact_id, default_value)


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"day": day,
		"week": week,
		"month": month,
		"season": String(season),
		"period": period,
		"current_location_id": String(current_location_id),
		"current_spawn_id": String(current_spawn_id),
		"player_position": {"x": player_position.x, "y": player_position.y},
		"facts": _stringify_keys(facts),
		"relationships": _stringify_keys(relationships),
		"npc_states": _stringify_keys(npc_states),
		"family_states": _stringify_keys(family_states),
		"household_records": _stringify_keys(household_records),
		"field_visits": _stringify_keys(field_visits),
		"inventory": _stringify_keys(inventory),
		"projects": _stringify_keys(projects),
		"world_patches": _stringify_keys(world_patches),
		"completed_events": _string_array(completed_events),
		"pending_events": pending_events.duplicate(true),
		"career_trajectory": _stringify_keys(career_trajectory),
		"unlocked_regions": _string_array(unlocked_regions),
		"environmental_state": _stringify_keys(environmental_state),
		"garden_state": _stringify_keys(garden_state),
	}


func from_dict(data: Dictionary) -> void:
	reset_to_new_game()
	schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	day = int(data.get("day", 1))
	week = int(data.get("week", 1))
	month = int(data.get("month", 1))
	season = StringName(str(data.get("season", "spring")))
	period = int(data.get("period", 0))
	current_location_id = StringName(str(data.get("current_location_id", "loc_casa_alex")))
	current_spawn_id = StringName(str(data.get("current_spawn_id", "spawn_bed")))

	var pos_raw: Variant = data.get("player_position", {"x": 0.0, "y": 0.0})
	if pos_raw is Dictionary:
		var pos_dict: Dictionary = pos_raw
		player_position = Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0)))

	facts = _symbolize_keys(data.get("facts", {}))
	relationships = _symbolize_keys(data.get("relationships", {}))
	npc_states = _symbolize_keys(data.get("npc_states", {}))
	family_states = _symbolize_keys(data.get("family_states", {}))
	household_records = _symbolize_keys(data.get("household_records", {}))
	field_visits = _symbolize_keys(data.get("field_visits", {}))
	inventory = _symbolize_keys(data.get("inventory", {}))
	projects = _symbolize_keys(data.get("projects", {}))
	world_patches = _symbolize_keys(data.get("world_patches", {}))
	completed_events = _to_string_name_array(data.get("completed_events", []))

	var raw_pending: Variant = data.get("pending_events", [])
	if raw_pending is Array:
		for entry: Variant in raw_pending:
			if entry is Dictionary:
				pending_events.append((entry as Dictionary).duplicate(true))

	var loaded_trajectory: Dictionary = _symbolize_keys(data.get("career_trajectory", {}))
	for key: Variant in loaded_trajectory.keys():
		career_trajectory[key] = int(loaded_trajectory[key])

	var loaded_regions: Array[StringName] = _to_string_name_array(data.get("unlocked_regions", ["reg_bairro_central"]))
	if not loaded_regions.is_empty():
		unlocked_regions = loaded_regions
	environmental_state = _symbolize_keys(data.get("environmental_state", {}))
	garden_state = _symbolize_keys(data.get("garden_state", {}))


func _stringify_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		result[str(key)] = _serialize_value(source[key])
	return result


func _serialize_value(value: Variant) -> Variant:
	if value is Dictionary:
		return _stringify_keys(value as Dictionary)
	if value is Array:
		var out: Array = []
		for item: Variant in (value as Array):
			out.append(_serialize_value(item))
		return out
	if value is StringName:
		return String(value)
	return value


func _symbolize_keys(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (source is Dictionary):
		return result
	var src: Dictionary = source
	for key: Variant in src.keys():
		var val: Variant = src[key]
		if val is float and is_equal_approx(val, round(val)):
			val = int(round(val))
		result[StringName(str(key))] = val
	return result


func _string_array(source: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for item: StringName in source:
		out.append(String(item))
	return out


func _to_string_name_array(source: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if not (source is Array):
		return out
	for item: Variant in (source as Array):
		out.append(StringName(str(item)))
	return out
