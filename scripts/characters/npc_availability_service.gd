class_name NPCAvailabilityService
extends RefCounted
## Evaluates an NPC's live availability state and residence door access from routine, period, personality, and health.


static func get_availability(world_state: Node, registry: Node, npc_id: StringName) -> Dictionary:
	var result: Dictionary = {
		"status": "available",
		"can_talk": true,
		"at_home": true,
		"label": "Disponível",
		"personality_tags": [],
		"location_id": "",
	}
	if world_state == null or npc_id == &"":
		return result

	var ch: CharacterData = null
	if registry != null and registry.has_method(&"get_character"):
		ch = registry.call(&"get_character", npc_id) as CharacterData
	if ch != null:
		result["personality_tags"] = ch.personality_tags.duplicate()

	var period: int = int(world_state.get("period"))
	var npc_states: Dictionary = world_state.get("npc_states") as Dictionary
	var st: Dictionary = npc_states.get(npc_id, {}) as Dictionary
	var current_loc: String = str(st.get("location_id", String(ch.residence_id) if ch != null else ""))
	var residence_loc: String = String(ch.residence_id) if ch != null else ""
	result["location_id"] = current_loc
	result["at_home"] = (not residence_loc.is_empty() and current_loc == residence_loc)

	if EnvironmentalInspectionService.is_npc_infected(world_state, npc_id):
		result["status"] = "at_ubs_dengue"
		result["can_talk"] = true
		result["at_home"] = false
		result["label"] = "Em atendimento na UBS (dengue)"
		return result

	if current_loc.is_empty():
		result["status"] = "away"
		result["can_talk"] = false
		result["at_home"] = false
		result["label"] = "Fora do bairro"
		return result

	if period == 3:
		result["status"] = "resting_night"
		result["can_talk"] = false
		result["label"] = "Descansando (Madrugada)"
		return result

	if not bool(result["at_home"]):
		result["status"] = "out_at_plaza"
		result["can_talk"] = true
		result["label"] = "Fora de casa (no bairro)"
		return result

	if period == 2:
		var is_tired_profile: bool = ch != null and (&"cansada" in ch.personality_tags or &"dedicada" in ch.personality_tags)
		if is_tired_profile:
			result["status"] = "busy_tired"
			result["can_talk"] = true
			result["label"] = "Em casa (cansada do dia)"
			return result

	result["status"] = "available"
	result["can_talk"] = true
	result["label"] = "Disponível em casa"
	return result


static func check_residence_entry(
	world_state: Node,
	registry: Node,
	family_id: StringName,
	primary_npc_id: StringName
) -> Dictionary:
	if world_state == null:
		return {"allowed": true, "reason": "available", "message": "Você entra na residência."}

	var period: int = int(world_state.get("period"))
	var fam_name: String = "a família"
	if registry != null and registry.has_method(&"get_family"):
		var fam: FamilyData = registry.call(&"get_family", family_id) as FamilyData
		if fam != null and not fam.family_name.is_empty():
			fam_name = fam.family_name

	var npc_name: String = "Morador"
	if registry != null and registry.has_method(&"get_character"):
		var ch: CharacterData = registry.call(&"get_character", primary_npc_id) as CharacterData
		if ch != null and not ch.display_name.is_empty():
			npc_name = ch.display_name

	if period == 3:
		return {
			"allowed": false,
			"reason": "resting_night",
			"message": "Está muito tarde (Madrugada). %s está descansando — melhor voltar pela manhã." % fam_name,
		}

	var avail: Dictionary = get_availability(world_state, registry, primary_npc_id)
	var status: String = str(avail.get("status", "available"))
	match status:
		"at_ubs_dengue":
			return {
				"allowed": true,
				"reason": "primary_at_ubs",
				"message": "%s foi à UBS por causa da dengue. Você entra para verificar a casa." % npc_name,
			}
		"out_at_plaza":
			return {
				"allowed": true,
				"reason": "primary_out",
				"message": "%s está pelo bairro agora, mas a casa está aberta." % npc_name,
			}
		"busy_tired":
			return {
				"allowed": true,
				"reason": "busy_tired",
				"message": "%s atende à porta um pouco cansada do dia, mas convida você a entrar." % npc_name,
			}
		_:
			return {
				"allowed": true,
				"reason": "available",
				"message": "%s abre a porta e convida você a entrar." % npc_name,
			}
