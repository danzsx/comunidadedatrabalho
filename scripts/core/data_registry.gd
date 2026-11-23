extends Node
## Immutable runtime catalog of static game definitions loaded from res://data/.

const LOCATIONS_DIR: String = "res://data/locations/"
const CHARACTERS_DIR: String = "res://data/characters/"
const FAMILIES_DIR: String = "res://data/families/"
const ITEMS_DIR: String = "res://data/items/"
const ROUTINES_DIR: String = "res://data/routines/"
const EVENTS_DIR: String = "res://data/events/"
const PROJECTS_DIR: String = "res://data/projects/"
const DIALOGUES_DIR: String = "res://data/dialogues/"

var locations: Dictionary = {}
var characters: Dictionary = {}
var families: Dictionary = {}
var items: Dictionary = {}
var routines: Dictionary = {}
var events: Dictionary = {}
var projects: Dictionary = {}
var dialogue_paths: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	locations.clear()
	characters.clear()
	families.clear()
	items.clear()
	routines.clear()
	events.clear()
	projects.clear()
	dialogue_paths.clear()

	_load_resources(LOCATIONS_DIR, locations, LocationData)
	_load_resources(CHARACTERS_DIR, characters, CharacterData)
	_load_resources(FAMILIES_DIR, families, FamilyData)
	_load_resources(ITEMS_DIR, items, ItemData)
	_load_resources(ROUTINES_DIR, routines, RoutineEntry)
	_load_resources(EVENTS_DIR, events, WorldEventData)
	_load_resources(PROJECTS_DIR, projects, ProjectData)
	_load_dialogue_paths()


func _load_resources(dir_path: String, target: Dictionary, expected_type: Variant) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var err: Error = dir.list_dir_begin()
	if err != OK:
		return
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(dir_path + file_name)
			if res != null and is_instance_of(res, expected_type):
				var res_id: StringName = res.get("id") as StringName
				if res_id != &"":
					target[res_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_dialogue_paths() -> void:
	var dir: DirAccess = DirAccess.open(DIALOGUES_DIR)
	if dir == null:
		return
	var err: Error = dir.list_dir_begin()
	if err != OK:
		return
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".dialogue"):
			var dialogue_id: StringName = StringName(file_name.get_basename())
			dialogue_paths[dialogue_id] = DIALOGUES_DIR + file_name
		file_name = dir.get_next()
	dir.list_dir_end()


func has_location(location_id: StringName) -> bool:
	return locations.has(location_id)


func get_location(location_id: StringName) -> LocationData:
	return locations.get(location_id, null) as LocationData


func get_all_location_ids() -> Array[StringName]:
	return _keys_as_string_names(locations)


func has_character(character_id: StringName) -> bool:
	return characters.has(character_id)


func get_character(character_id: StringName) -> CharacterData:
	return characters.get(character_id, null) as CharacterData


func get_all_character_ids() -> Array[StringName]:
	return _keys_as_string_names(characters)


func has_family(family_id: StringName) -> bool:
	return families.has(family_id)


func get_family(family_id: StringName) -> FamilyData:
	return families.get(family_id, null) as FamilyData


func get_all_family_ids() -> Array[StringName]:
	return _keys_as_string_names(families)


func has_item(item_id: StringName) -> bool:
	return items.has(item_id)


func get_item(item_id: StringName) -> ItemData:
	return items.get(item_id, null) as ItemData


func has_project(project_id: StringName) -> bool:
	return projects.has(project_id)


func get_project(project_id: StringName) -> ProjectData:
	return projects.get(project_id, null) as ProjectData


func get_all_project_ids() -> Array[StringName]:
	return _keys_as_string_names(projects)


func has_dialogue(dialogue_id: StringName) -> bool:
	return dialogue_paths.has(dialogue_id)


func get_dialogue_path(dialogue_id: StringName) -> String:
	return str(dialogue_paths.get(dialogue_id, ""))


func validate_integrity() -> Array[String]:
	var errors: Array[String] = []

	for loc_id: Variant in locations.keys():
		var loc: LocationData = locations[loc_id] as LocationData
		if loc == null:
			errors.append("Null LocationData for key: %s" % str(loc_id))
			continue
		if loc.scene_path.is_empty() or not ResourceLoader.exists(loc.scene_path):
			errors.append("Missing scene_path '%s' for location '%s'" % [loc.scene_path, String(loc.id)])

	for char_id: Variant in characters.keys():
		var ch: CharacterData = characters[char_id] as CharacterData
		if ch == null:
			errors.append("Null CharacterData for key: %s" % str(char_id))
			continue
		if ch.family_id != &"" and not families.has(ch.family_id):
			errors.append("Character '%s' references missing family '%s'" % [String(ch.id), String(ch.family_id)])
		if ch.residence_id != &"" and not locations.has(ch.residence_id):
			errors.append("Character '%s' references missing residence '%s'" % [String(ch.id), String(ch.residence_id)])
		if ch.dialogue_id != &"" and not dialogue_paths.has(ch.dialogue_id):
			errors.append("Character '%s' references missing dialogue '%s'" % [String(ch.id), String(ch.dialogue_id)])

	for fam_id: Variant in families.keys():
		var fam: FamilyData = families[fam_id] as FamilyData
		if fam == null:
			errors.append("Null FamilyData for key: %s" % str(fam_id))
			continue
		if fam.residence_id != &"" and not locations.has(fam.residence_id):
			errors.append("Family '%s' references missing residence '%s'" % [String(fam.id), String(fam.residence_id)])
		for member_id: StringName in fam.initial_members:
			if not characters.has(member_id):
				errors.append("Family '%s' references missing member '%s'" % [String(fam.id), String(member_id)])

	for r_id: Variant in routines.keys():
		var entry: RoutineEntry = routines[r_id] as RoutineEntry
		if entry == null:
			errors.append("Null RoutineEntry for key: %s" % str(r_id))
			continue
		if not characters.has(entry.npc_id):
			errors.append("Routine '%s' references missing npc '%s'" % [String(entry.id), String(entry.npc_id)])
		if entry.location_id != &"" and not locations.has(entry.location_id):
			errors.append("Routine '%s' references missing location '%s'" % [String(entry.id), String(entry.location_id)])

	for p_id: Variant in projects.keys():
		var proj: ProjectData = projects[p_id] as ProjectData
		if proj == null:
			errors.append("Null ProjectData for key: %s" % str(p_id))
			continue
		for npc_id: StringName in proj.involved_npcs:
			if not characters.has(npc_id):
				errors.append("Project '%s' references missing npc '%s'" % [String(proj.id), String(npc_id)])
		for stage_def: Dictionary in proj.stages:
			var req_items: Dictionary = stage_def.get("required_items", {}) as Dictionary
			for item_key: Variant in req_items.keys():
				if not items.has(StringName(str(item_key))):
					errors.append("Project '%s' references missing item '%s'" % [String(proj.id), str(item_key)])

	return errors


func _keys_as_string_names(dict: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in dict.keys():
		ids.append(key as StringName)
	return ids
