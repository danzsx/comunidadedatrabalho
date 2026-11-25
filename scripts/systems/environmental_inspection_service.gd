class_name EnvironmentalInspectionService
extends RefCounted
## Manages environmental inspection zones, mosquito proliferation, and living dengue -> UBS dynamics.

const MAX_SIMULTANEOUS_DENGUE_CASES: int = 3
const UBS_DENGUE_SPOTS: Array[String] = ["spot_dengue_1", "spot_dengue_2", "spot_dengue_3"]

const ZONES: Dictionary = {
	"zone_quintal_fam_a": {
		"id": "zone_quintal_fam_a",
		"title": "Quintal da Família Alencar",
		"environment": "quintal",
		"description": "Quintal úmido nos fundos da casa com vasos, baldes e um pneu encostado no muro.",
		"linked_family": "fam_a",
		"linked_npcs": ["npc_a_2", "npc_a_3"],
		"world_pos": Vector2(82.0, 384.0),
	},
	"zone_terreno_leste": {
		"id": "zone_terreno_leste",
		"title": "Terreno Baldio (Leste)",
		"environment": "terreno",
		"description": "Terreno aberto próximo à praça com entulho, lona dobrada, garrafas e pneus.",
		"linked_family": "fam_b",
		"linked_npcs": ["npc_b_1", "npc_b_2", "npc_c_1"],
		"world_pos": Vector2(522.0, 236.0),
	},
	"zone_quintal_fam_c": {
		"id": "zone_quintal_fam_c",
		"title": "Quintal da Família Ferreira",
		"environment": "quintal_fundos",
		"description": "Área lateral com tonéis de água, calha baixa, vasos e tigela do quintal.",
		"linked_family": "fam_c",
		"linked_npcs": ["npc_c_1", "npc_b_2", "npc_a_3"],
		"world_pos": Vector2(548.0, 384.0),
	},
}


static func ensure_initialized(world_state: Node) -> void:
	if world_state == null:
		return
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	if not env_state.has(&"zones"):
		env_state[&"zones"] = {}
	var zones_dict: Dictionary = env_state[&"zones"] as Dictionary
	for zone_key: String in ZONES.keys():
		if not zones_dict.has(zone_key):
			zones_dict[zone_key] = {
				"status": "pending",
				"mosquito_level": 0,
				"last_inspected_day": 0,
				"failed_count": 0,
				"cleaned_count": 0,
			}
	if not env_state.has(&"dengue_cases"):
		env_state[&"dengue_cases"] = {}
	if not env_state.has(&"total_inspections_passed"):
		env_state[&"total_inspections_passed"] = 0
	if not env_state.has(&"total_inspections_failed"):
		env_state[&"total_inspections_failed"] = 0
	if not env_state.has(&"last_result"):
		env_state[&"last_result"] = ""
	world_state.set("environmental_state", env_state)


static func get_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in ZONES.keys():
		ids.append(key)
	return ids


static func get_zone_def(zone_id: StringName) -> Dictionary:
	return ZONES.get(String(zone_id), {}) as Dictionary


static func get_zone_state(world_state: Node, zone_id: StringName) -> Dictionary:
	ensure_initialized(world_state)
	if world_state == null:
		return {}
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var zones_dict: Dictionary = env_state.get(&"zones", {}) as Dictionary
	return zones_dict.get(String(zone_id), {}) as Dictionary


static func get_infested_zones(world_state: Node) -> Array[String]:
	ensure_initialized(world_state)
	var result: Array[String] = []
	if world_state == null:
		return result
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var zones_dict: Dictionary = env_state.get(&"zones", {}) as Dictionary
	for zone_key: Variant in zones_dict.keys():
		var z_state: Dictionary = zones_dict[zone_key] as Dictionary
		if str(z_state.get("status", "pending")) == "infested":
			result.append(str(zone_key))
	return result


static func get_total_mosquito_level(world_state: Node) -> int:
	ensure_initialized(world_state)
	if world_state == null:
		return 0
	var total: int = 0
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var zones_dict: Dictionary = env_state.get(&"zones", {}) as Dictionary
	for zone_key: Variant in zones_dict.keys():
		var z_state: Dictionary = zones_dict[zone_key] as Dictionary
		total += int(z_state.get("mosquito_level", 0))
	return total


static func is_npc_infected(world_state: Node, npc_id: StringName) -> bool:
	if world_state == null or npc_id == &"":
		return false
	ensure_initialized(world_state)
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var cases: Dictionary = env_state.get(&"dengue_cases", {}) as Dictionary
	return cases.has(String(npc_id))


static func get_infected_npcs(world_state: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	if world_state == null:
		return result
	ensure_initialized(world_state)
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var cases: Dictionary = env_state.get(&"dengue_cases", {}) as Dictionary
	for npc_key: Variant in cases.keys():
		result.append(StringName(str(npc_key)))
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func get_dengue_case(world_state: Node, npc_id: StringName) -> Dictionary:
	if world_state == null:
		return {}
	ensure_initialized(world_state)
	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var cases: Dictionary = env_state.get(&"dengue_cases", {}) as Dictionary
	return cases.get(String(npc_id), {}) as Dictionary


static func get_ubs_spot_for_infected_npc(world_state: Node, npc_id: StringName) -> String:
	var infected: Array[StringName] = get_infected_npcs(world_state)
	var idx: int = infected.find(npc_id)
	if idx < 0:
		return UBS_DENGUE_SPOTS[0]
	return UBS_DENGUE_SPOTS[idx % UBS_DENGUE_SPOTS.size()]


static func record_inspection_result(
	world_state: Node,
	event_bus: Node,
	zone_id: StringName,
	success: bool,
	found_count: int,
	total_foci: int,
	mistakes: int
) -> Dictionary:
	ensure_initialized(world_state)
	var zone_key: String = String(zone_id)
	var zone_def: Dictionary = get_zone_def(zone_id)
	var zone_title: String = str(zone_def.get("title", zone_key))
	if world_state == null or zone_def.is_empty():
		return {"ok": false}

	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var zones_dict: Dictionary = env_state[&"zones"] as Dictionary
	var z_state: Dictionary = zones_dict.get(zone_key, {}) as Dictionary
	var current_day: int = int(world_state.get("day"))
	z_state["last_inspected_day"] = current_day

	var new_status: String = "clean" if success else "infested"
	if success:
		z_state["status"] = "clean"
		z_state["mosquito_level"] = 0
		z_state["cleaned_count"] = int(z_state.get("cleaned_count", 0)) + 1
		env_state[&"total_inspections_passed"] = int(env_state.get(&"total_inspections_passed", 0)) + 1
		env_state[&"last_result"] = "success"

		var trajectory: Dictionary = world_state.get("career_trajectory") as Dictionary
		trajectory[&"acs_engagement"] = int(trajectory.get(&"acs_engagement", 0)) + 1
		trajectory[&"community_ties"] = int(trajectory.get(&"community_ties", 0)) + 1
		world_state.call(&"set_fact", &"env_inspections_passed", int(env_state[&"total_inspections_passed"]))
	else:
		z_state["status"] = "infested"
		z_state["mosquito_level"] = clampi(int(z_state.get("mosquito_level", 0)) + 1, 1, 2)
		z_state["failed_count"] = int(z_state.get("failed_count", 0)) + 1
		env_state[&"total_inspections_failed"] = int(env_state.get(&"total_inspections_failed", 0)) + 1
		env_state[&"last_result"] = "failed"
		world_state.call(&"set_fact", &"env_inspections_failed", int(env_state[&"total_inspections_failed"]))

	zones_dict[zone_key] = z_state
	env_state[&"zones"] = zones_dict
	world_state.set("environmental_state", env_state)

	var mosquitoes_active: bool = get_total_mosquito_level(world_state) > 0
	world_state.call(&"set_fact", &"env_mosquitoes_active", mosquitoes_active)

	if event_bus != null:
		event_bus.emit_signal(&"environmental_state_changed", zone_id, new_status)
		if success:
			event_bus.emit_signal(
				&"notification_requested",
				"Inspeção concluída em %s! Focos eliminados (%d/%d)." % [zone_title, found_count, total_foci],
				&"environment"
			)
		else:
			event_bus.emit_signal(
				&"notification_requested",
				"Focos ativos permaneceram em %s! Mosquitos começaram a surgir." % zone_title,
				&"warning"
			)

	return {
		"ok": true,
		"zone_id": zone_id,
		"status": new_status,
		"found_count": found_count,
		"total_foci": total_foci,
		"mistakes": mistakes,
		"mosquito_level": int(z_state.get("mosquito_level", 0)),
	}


static func process_tick(
	is_day_end: bool,
	world_state: Node,
	registry: Node,
	event_bus: Node = null
) -> Array[StringName]:
	var newly_infected: Array[StringName] = []
	if world_state == null:
		return newly_infected
	ensure_initialized(world_state)

	var env_state: Dictionary = world_state.get("environmental_state") as Dictionary
	var zones_dict: Dictionary = env_state.get(&"zones", {}) as Dictionary
	var cases: Dictionary = env_state.get(&"dengue_cases", {}) as Dictionary
	var current_day: int = int(world_state.get("day"))

	# 1. Process recoveries on day end when the originating zone (or all zones) is cleaned.
	if is_day_end and not cases.is_empty():
		var recovered_ids: Array[String] = []
		for npc_key: Variant in cases.keys():
			var npc_str: String = str(npc_key)
			var c_data: Dictionary = cases[npc_key] as Dictionary
			var origin_zone: String = str(c_data.get("zone_id", ""))
			var origin_state: Dictionary = zones_dict.get(origin_zone, {}) as Dictionary
			var origin_infested: bool = str(origin_state.get("status", "clean")) == "infested"
			if not origin_infested:
				var days_left: int = int(c_data.get("recovery_days_left", 1)) - 1
				c_data["recovery_days_left"] = days_left
				cases[npc_key] = c_data
				if days_left <= 0:
					recovered_ids.append(npc_str)
		for rec_id: String in recovered_ids:
			cases.erase(rec_id)
			var rec_sn: StringName = StringName(rec_id)
			if event_bus != null:
				event_bus.emit_signal(&"npc_dengue_status_changed", rec_sn, false)
				var disp_name: String = _get_character_display_name(registry, rec_sn)
				event_bus.emit_signal(
					&"notification_requested",
					"%s se recuperou da dengue e retornou à rotina." % disp_name,
					&"health"
				)

	# 2. Propagate dengue from infested zones to vulnerable residents.
	var infested_zones: Array[String] = get_infested_zones(world_state)
	if not infested_zones.is_empty() and cases.size() < MAX_SIMULTANEOUS_DENGUE_CASES:
		for zone_key: String in infested_zones:
			if cases.size() >= MAX_SIMULTANEOUS_DENGUE_CASES:
				break
			var z_state: Dictionary = zones_dict.get(zone_key, {}) as Dictionary
			var mosquito_lvl: int = int(z_state.get("mosquito_level", 1))
			# Each infested zone can cause a resident to contract dengue if none from this zone is sick yet,
			# or an extra case on day end if infestation is severe (level >= 2).
			var zone_cases_count: int = _count_cases_for_zone(cases, zone_key)
			var should_infect: bool = zone_cases_count == 0 or (is_day_end and mosquito_lvl >= 2 and zone_cases_count < 2)
			if not should_infect:
				continue

			var candidate: StringName = _pick_vulnerable_npc(world_state, registry, zone_key, cases)
			if candidate == &"":
				continue

			cases[String(candidate)] = {
				"infected_day": current_day,
				"zone_id": zone_key,
				"recovery_days_left": 1,
			}
			newly_infected.append(candidate)
			world_state.call(&"set_fact", &"dengue_outbreak_occurred", true)
			if event_bus != null:
				event_bus.emit_signal(&"npc_dengue_status_changed", candidate, true)
				var disp_name: String = _get_character_display_name(registry, candidate)
				event_bus.emit_signal(
					&"notification_requested",
					"%s apresentou sintomas de dengue e procurou a UBS!" % disp_name,
					&"warning"
				)

	env_state[&"dengue_cases"] = cases
	world_state.set("environmental_state", env_state)
	world_state.call(&"set_fact", &"dengue_active_count", cases.size())
	world_state.call(&"set_fact", &"env_mosquitoes_active", get_total_mosquito_level(world_state) > 0)
	return newly_infected


static func _count_cases_for_zone(cases: Dictionary, zone_key: String) -> int:
	var count: int = 0
	for npc_key: Variant in cases.keys():
		var c_data: Dictionary = cases[npc_key] as Dictionary
		if str(c_data.get("zone_id", "")) == zone_key:
			count += 1
	return count


static func _pick_vulnerable_npc(
	world_state: Node,
	registry: Node,
	zone_key: String,
	cases: Dictionary
) -> StringName:
	var zone_def: Dictionary = ZONES.get(zone_key, {}) as Dictionary
	var preferred: Array = zone_def.get("linked_npcs", []) as Array
	var npc_states: Dictionary = world_state.get("npc_states") as Dictionary
	var bruno_away: bool = bool(world_state.call(&"get_fact", &"fam_c_bruno_left_for_shift", false))

	for npc_str_var: Variant in preferred:
		var npc_str: String = str(npc_str_var)
		if _is_eligible_for_dengue(npc_str, cases, npc_states, registry, bruno_away):
			return StringName(npc_str)

	# Fallback to other neighborhood residents (never Hortencia, who staffs the UBS).
	var fallback_pool: Array[String] = ["npc_a_2", "npc_a_3", "npc_b_1", "npc_b_2", "npc_c_1"]
	for npc_str: String in fallback_pool:
		if _is_eligible_for_dengue(npc_str, cases, npc_states, registry, bruno_away):
			return StringName(npc_str)
	return &""


static func _is_eligible_for_dengue(
	npc_str: String,
	cases: Dictionary,
	npc_states: Dictionary,
	registry: Node,
	bruno_away: bool
) -> bool:
	if npc_str == "npc_hortencia" or npc_str == "npc_a_1":
		return false
	if bruno_away and npc_str == "npc_c_2":
		return false
	if cases.has(npc_str):
		return false
	var npc_sn: StringName = StringName(npc_str)
	if registry != null and registry.has_method(&"has_character"):
		if not bool(registry.call(&"has_character", npc_sn)):
			return false
	if npc_states.has(npc_sn):
		var st: Dictionary = npc_states[npc_sn] as Dictionary
		if not bool(st.get("alive", true)):
			return false
	return true


static func _get_character_display_name(registry: Node, npc_id: StringName) -> String:
	if registry != null and registry.has_method(&"get_character"):
		var ch: CharacterData = registry.call(&"get_character", npc_id) as CharacterData
		if ch != null and not ch.display_name.is_empty():
			return ch.display_name
	return String(npc_id)
