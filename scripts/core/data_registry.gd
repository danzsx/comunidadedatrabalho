extends Node
## Immutable runtime catalog of static game definitions loaded from res://data/.

const LOCATIONS_DIR: String = "res://data/locations/"

var locations: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	locations.clear()
	_load_locations()


func _load_locations() -> void:
	var dir: DirAccess = DirAccess.open(LOCATIONS_DIR)
	if dir == null:
		return
	var err: Error = dir.list_dir_begin()
	if err != OK:
		return
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(LOCATIONS_DIR + file_name)
			if res is LocationData:
				var loc: LocationData = res as LocationData
				if loc.id != &"":
					locations[loc.id] = loc
		file_name = dir.get_next()
	dir.list_dir_end()


func has_location(location_id: StringName) -> bool:
	return locations.has(location_id)


func get_location(location_id: StringName) -> LocationData:
	return locations.get(location_id, null) as LocationData


func get_all_location_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in locations.keys():
		ids.append(key as StringName)
	return ids


func validate_integrity() -> Array[String]:
	var errors: Array[String] = []
	for loc_id: Variant in locations.keys():
		var loc: LocationData = locations[loc_id] as LocationData
		if loc == null:
			errors.append("Null LocationData for key: %s" % str(loc_id))
			continue
		if loc.scene_path.is_empty() or not ResourceLoader.exists(loc.scene_path):
			errors.append("Missing scene_path '%s' for location '%s'" % [loc.scene_path, String(loc.id)])
	return errors
