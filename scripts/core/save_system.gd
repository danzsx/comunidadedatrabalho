extends Node
## Versioned JSON persistence manager for WorldState.

const SAVE_DIR: String = "user://saves/"
const AUTOSAVE_FILE: String = "user://saves/autosave.json"
const CURRENT_SCHEMA_VERSION: int = 1


func save_slot(slot_index: int) -> Error:
	return save_to_path("%sslot_%d.json" % [SAVE_DIR, slot_index])


func load_slot(slot_index: int) -> Error:
	return load_from_path("%sslot_%d.json" % [SAVE_DIR, slot_index])


func save_autosave() -> Error:
	return save_to_path(AUTOSAVE_FILE)


func load_autosave() -> Error:
	return load_from_path(AUTOSAVE_FILE)


func save_to_path(file_path: String) -> Error:
	var dir_path: String = file_path.get_base_dir()
	var mkdir_err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if mkdir_err != OK:
		return mkdir_err

	var payload: Dictionary = {
		"meta": {
			"schema_version": CURRENT_SCHEMA_VERSION,
			"timestamp_iso": Time.get_datetime_string_from_system(true, true),
			"day": WorldState.day,
			"period": WorldState.period,
			"current_location_id": String(WorldState.current_location_id),
		},
		"world_state": WorldState.to_dict(),
	}

	var json_text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.close()
	return OK


func load_from_path(file_path: String) -> Error:
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return ERR_PARSE_ERROR

	var migrated: Dictionary = migrate_save_data(parsed as Dictionary)
	var state_dict: Variant = migrated.get("world_state", {})
	if not (state_dict is Dictionary):
		return ERR_INVALID_DATA

	WorldState.from_dict(state_dict as Dictionary)
	return OK


func migrate_save_data(raw: Dictionary) -> Dictionary:
	var result: Dictionary = raw.duplicate(true)
	var meta: Dictionary = result.get("meta", {})
	var version: int = int(meta.get("schema_version", 1))
	# Future schema migrations (v1 -> v2, etc.) will be chained here.
	meta["schema_version"] = maxi(version, CURRENT_SCHEMA_VERSION)
	result["meta"] = meta
	return result
