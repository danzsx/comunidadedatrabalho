class_name CommunityGardenService
extends RefCounted
## Pure-domain simulation service for the Horta Comunitaria minigame:
## plots, watering, fertilizing, deterministic time growth, mild neglect, neighbor help, sharing, and upgrades.

const PLOT_COUNT: int = 16
const PLOTS_PER_BLOCK: int = 4
const INITIAL_WATER_MAX: int = 6
const UPGRADED_WATER_MAX: int = 12
const MAX_COMPOST_STORED: int = 3
const MAX_GARDEN_LEVEL: int = 3


static func ensure_initialized(world_state: Node) -> void:
	if world_state == null:
		return
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	if not gs.has(&"unlocked"):
		gs[&"unlocked"] = false
	if not gs.has(&"level"):
		gs[&"level"] = 0
	if not gs.has(&"watering_can_charges"):
		gs[&"watering_can_charges"] = INITIAL_WATER_MAX
	if not gs.has(&"watering_can_max"):
		gs[&"watering_can_max"] = INITIAL_WATER_MAX
	if not gs.has(&"compost_ready_days"):
		gs[&"compost_ready_days"] = 0
	if not gs.has(&"compost_available"):
		gs[&"compost_available"] = 0
	if not gs.has(&"total_harvests"):
		gs[&"total_harvests"] = 0
	if not gs.has(&"total_shares"):
		gs[&"total_shares"] = 0
	if not gs.has(&"shared_npcs_ever"):
		gs[&"shared_npcs_ever"] = []
	if not gs.has(&"shared_today"):
		gs[&"shared_today"] = []
	if not gs.has(&"mutirao_done_days"):
		gs[&"mutirao_done_days"] = []
	if not gs.has(&"plots"):
		gs[&"plots"] = {}

	var plots: Dictionary = gs[&"plots"] as Dictionary
	var unlocked_level: int = int(gs.get(&"level", 0))
	for i: int in range(PLOT_COUNT):
		var plot_key: String = "plot_%d" % i
		var block_idx: int = i / PLOTS_PER_BLOCK
		if not plots.has(plot_key):
			plots[plot_key] = {
				"block": block_idx,
				"state": "overgrown" if block_idx <= unlocked_level else "locked",
				"crop_id": "",
				"stage": 0,
				"growth_points": 0,
				"moisture": 0,
				"fertilized": false,
				"dry_ticks": 0,
				"weed_level": 0,
				"watered_by_npc": "",
			}
	gs[&"plots"] = plots
	world_state.set("garden_state", gs)


static func is_unlocked(world_state: Node) -> bool:
	if world_state == null:
		return false
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	return bool(gs.get(&"unlocked", false))


static func get_level(world_state: Node) -> int:
	if world_state == null:
		return 0
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	return int(gs.get(&"level", 0))


static func get_plot_state(world_state: Node, plot_id: StringName) -> Dictionary:
	if world_state == null:
		return {}
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs.get(&"plots", {}) as Dictionary
	return plots.get(String(plot_id), {}) as Dictionary


static func unlock_garden(world_state: Node, event_bus: Node) -> bool:
	if world_state == null:
		return false
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	if bool(gs.get(&"unlocked", false)):
		return false

	gs[&"unlocked"] = true
	world_state.set("garden_state", gs)
	world_state.call(&"set_fact", &"horta_unlocked", true)

	# Starter community seed kit gifted by Dona Rosa
	InventorySystem.add_item(world_state, &"item_semente_cheiro_verde", 2)
	InventorySystem.add_item(world_state, &"item_semente_alface", 2)
	InventorySystem.add_item(world_state, &"item_semente_cenoura", 2)

	if event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")
		event_bus.emit_signal(
			&"notification_requested",
			"Horta Comunitária aberta! Dona Rosa separou sementes iniciais na mochila.",
			&"project"
		)
	return true


static func prepare_plot(world_state: Node, event_bus: Node, plot_id: StringName) -> Dictionary:
	if world_state == null:
		return {"ok": false, "reason": "no_state"}
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs[&"plots"] as Dictionary
	var key: String = String(plot_id)
	if not plots.has(key):
		return {"ok": false, "reason": "missing_plot"}
	var p: Dictionary = plots[key] as Dictionary
	var st: String = str(p.get("state", "locked"))

	if st == "overgrown":
		p["state"] = "tilled"
		p["weed_level"] = 0
		p["dry_ticks"] = 0
		plots[key] = p
		if event_bus != null:
			event_bus.emit_signal(&"garden_plot_changed", plot_id)
			event_bus.emit_signal(&"garden_state_changed")
		return {"ok": true, "action": "tilled"}

	if st == "planted" and int(p.get("weed_level", 0)) > 0:
		p["weed_level"] = 0
		plots[key] = p
		if event_bus != null:
			event_bus.emit_signal(&"garden_plot_changed", plot_id)
			event_bus.emit_signal(&"garden_state_changed")
		return {"ok": true, "action": "weeded"}

	return {"ok": false, "reason": "cannot_prepare"}


static func plant_seed(
	world_state: Node,
	registry: Node,
	event_bus: Node,
	plot_id: StringName,
	crop_id: StringName
) -> Dictionary:
	if world_state == null or registry == null:
		return {"ok": false, "reason": "unconfigured"}
	ensure_initialized(world_state)
	var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
	if crop == null:
		return {"ok": false, "reason": "unknown_crop"}

	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs[&"plots"] as Dictionary
	var key: String = String(plot_id)
	if not plots.has(key):
		return {"ok": false, "reason": "missing_plot"}
	var p: Dictionary = plots[key] as Dictionary
	if str(p.get("state", "")) != "tilled":
		return {"ok": false, "reason": "not_tilled"}
	if InventorySystem.get_count(world_state, crop.seed_item_id) < 1:
		return {"ok": false, "reason": "no_seeds"}

	var removed: bool = InventorySystem.remove_item(world_state, crop.seed_item_id, 1)
	if not removed:
		return {"ok": false, "reason": "no_seeds"}

	p["state"] = "planted"
	p["crop_id"] = String(crop.id)
	p["stage"] = 0
	p["growth_points"] = 0
	p["dry_ticks"] = 0
	p["weed_level"] = 0
	p["watered_by_npc"] = ""
	plots[key] = p

	if event_bus != null:
		event_bus.emit_signal(&"garden_plot_changed", plot_id)
		event_bus.emit_signal(&"garden_state_changed")
	return {"ok": true, "crop_id": crop.id}


static func water_plot(world_state: Node, event_bus: Node, plot_id: StringName) -> Dictionary:
	if world_state == null:
		return {"ok": false, "reason": "no_state"}
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var charges: int = int(gs.get(&"watering_can_charges", 0))
	if charges <= 0:
		if event_bus != null:
			event_bus.emit_signal(&"notification_requested", "Regador vazio! Encha no reservatório da horta.", &"info")
		return {"ok": false, "reason": "empty_can"}

	var plots: Dictionary = gs[&"plots"] as Dictionary
	var key: String = String(plot_id)
	if not plots.has(key):
		return {"ok": false, "reason": "missing_plot"}
	var p: Dictionary = plots[key] as Dictionary
	var st: String = str(p.get("state", "locked"))
	if st != "tilled" and st != "planted":
		return {"ok": false, "reason": "invalid_state"}

	gs[&"watering_can_charges"] = charges - 1
	p["moisture"] = 2
	p["dry_ticks"] = 0
	p["watered_by_npc"] = ""
	plots[key] = p
	world_state.set("garden_state", gs)

	if event_bus != null:
		event_bus.emit_signal(&"garden_plot_changed", plot_id)
		event_bus.emit_signal(&"garden_state_changed")
	return {"ok": true, "charges_left": charges - 1}


static func refill_watering_can(world_state: Node, event_bus: Node) -> int:
	if world_state == null:
		return 0
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var max_c: int = int(gs.get(&"watering_can_max", INITIAL_WATER_MAX))
	gs[&"watering_can_charges"] = max_c
	world_state.set("garden_state", gs)
	if event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")
		event_bus.emit_signal(&"notification_requested", "Regador cheio (%d/%d) no reservatório protegido!" % [max_c, max_c], &"garden")
	return max_c


static func fertilize_plot(world_state: Node, event_bus: Node, plot_id: StringName) -> Dictionary:
	if world_state == null:
		return {"ok": false, "reason": "no_state"}
	ensure_initialized(world_state)
	if InventorySystem.get_count(world_state, &"item_composto_organico") < 1:
		if event_bus != null:
			event_bus.emit_signal(&"notification_requested", "Sem Composto Orgânico na mochila.", &"info")
		return {"ok": false, "reason": "no_compost"}

	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs[&"plots"] as Dictionary
	var key: String = String(plot_id)
	if not plots.has(key):
		return {"ok": false, "reason": "missing_plot"}
	var p: Dictionary = plots[key] as Dictionary
	var st: String = str(p.get("state", "locked"))
	if st != "tilled" and st != "planted":
		return {"ok": false, "reason": "invalid_state"}
	if bool(p.get("fertilized", false)):
		return {"ok": false, "reason": "already_fertilized"}

	var _removed: bool = InventorySystem.remove_item(world_state, &"item_composto_organico", 1)
	p["fertilized"] = true
	plots[key] = p
	if event_bus != null:
		event_bus.emit_signal(&"garden_plot_changed", plot_id)
		event_bus.emit_signal(&"garden_state_changed")
	return {"ok": true}


static func harvest_plot(
	world_state: Node,
	registry: Node,
	event_bus: Node,
	plot_id: StringName
) -> Dictionary:
	if world_state == null or registry == null:
		return {"ok": false, "reason": "unconfigured"}
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs[&"plots"] as Dictionary
	var key: String = String(plot_id)
	if not plots.has(key):
		return {"ok": false, "reason": "missing_plot"}
	var p: Dictionary = plots[key] as Dictionary
	if str(p.get("state", "")) != "harvestable":
		return {"ok": false, "reason": "not_ready"}

	var crop_id: StringName = StringName(str(p.get("crop_id", "")))
	var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
	if crop == null:
		return {"ok": false, "reason": "unknown_crop"}

	var bonus: int = 1 if bool(p.get("fertilized", false)) else 0
	var amount: int = crop.base_yield + bonus
	var _new_count: int = InventorySystem.add_item(world_state, crop.produce_item_id, amount)

	var total_harvests: int = int(gs.get(&"total_harvests", 0)) + 1
	gs[&"total_harvests"] = total_harvests
	world_state.call(&"set_fact", &"horta_total_harvests", total_harvests)

	if crop.regrows:
		p["state"] = "planted"
		p["stage"] = clampi(crop.regrow_stage, 1, 2)
		p["growth_points"] = int(floor(float(p["stage"]) * float(crop.growth_target) / 3.0))
		p["fertilized"] = false
		p["dry_ticks"] = 0
		p["watered_by_npc"] = ""
	else:
		p["state"] = "tilled"
		p["crop_id"] = ""
		p["stage"] = 0
		p["growth_points"] = 0
		p["fertilized"] = false
		p["dry_ticks"] = 0
		p["weed_level"] = 0
		p["watered_by_npc"] = ""

	plots[key] = p
	world_state.set("garden_state", gs)

	if event_bus != null:
		event_bus.emit_signal(&"garden_harvested", crop.id, amount)
		event_bus.emit_signal(&"garden_plot_changed", plot_id)
		event_bus.emit_signal(&"garden_state_changed")
		event_bus.emit_signal(
			&"notification_requested",
			"Colhido +%d %s!" % [amount, crop.display_name],
			&"garden"
		)

	return {
		"ok": true,
		"crop_id": crop.id,
		"produce_item_id": crop.produce_item_id,
		"amount": amount,
		"display_name": crop.display_name,
	}


static func collect_compost(world_state: Node, event_bus: Node) -> int:
	if world_state == null:
		return 0
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var avail: int = int(gs.get(&"compost_available", 0))
	if avail <= 0:
		return 0
	var _added: int = InventorySystem.add_item(world_state, &"item_composto_organico", avail)
	gs[&"compost_available"] = 0
	world_state.set("garden_state", gs)
	if event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")
		event_bus.emit_signal(&"notification_requested", "Coletado +%d Composto Orgânico da composteira!" % avail, &"garden")
	return avail


static func get_upgrade_info(world_state: Node) -> Dictionary:
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var level: int = int(gs.get(&"level", 0))
	if level >= MAX_GARDEN_LEVEL:
		return {
			"next_level": MAX_GARDEN_LEVEL,
			"maxed": true,
			"can_upgrade": false,
			"title": "Horta Comunitária Plena",
			"requirement_text": "Todas as expansões da horta já foram concluídas!",
		}

	var total_shares: int = int(gs.get(&"total_shares", 0))
	var total_harvests: int = int(gs.get(&"total_harvests", 0))
	var shared_ever: Array = gs.get(&"shared_npcs_ever", []) as Array
	var mutiroes: Array = gs.get(&"mutirao_done_days", []) as Array

	match level:
		0:
			var tiago_fam: int = RelationshipService.get_axis(world_state, &"npc_b_2", &"familiarity")
			var ok: bool = total_shares >= 3 and tiago_fam >= 2
			return {
				"next_level": 1,
				"maxed": false,
				"can_upgrade": ok,
				"title": "Expansão 1 — Canteiros de Madeira (+4 canteiros, Couve e Hortelã)",
				"requirement_text": "Colheitas compartilhadas: %d/3 · Familiaridade com Tiago: %d/2" % [total_shares, tiago_fam],
			}
		1:
			var rosa_coop: int = RelationshipService.get_axis(world_state, &"npc_b_1", &"cooperation")
			var ok: bool = total_harvests >= 6 and rosa_coop >= 2
			return {
				"next_level": 2,
				"maxed": false,
				"can_upgrade": ok,
				"title": "Expansão 2 — Composteira & Regador 12x (+4 canteiros, Tomate-Cereja)",
				"requirement_text": "Colheitas totais: %d/6 · Cooperação com Dona Rosa: %d/2" % [total_harvests, rosa_coop],
			}
		_:
			var ok: bool = shared_ever.size() >= 4 and mutiroes.size() >= 1
			return {
				"next_level": 3,
				"maxed": false,
				"can_upgrade": ok,
				"title": "Expansão 3 — Horta Comunitária Plena (+4 canteiros, espaço de convivência)",
				"requirement_text": "Moradores presenteados: %d/4 · Mutirões realizados: %d/1" % [shared_ever.size(), mutiroes.size()],
			}


static func try_upgrade_garden(world_state: Node, event_bus: Node) -> bool:
	if world_state == null:
		return false
	var info: Dictionary = get_upgrade_info(world_state)
	if not bool(info.get("can_upgrade", false)):
		return false

	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var next_level: int = int(info["next_level"])
	gs[&"level"] = next_level

	# Unlock the new 4-plot block
	var plots: Dictionary = gs[&"plots"] as Dictionary
	for i: int in range(PLOT_COUNT):
		var key: String = "plot_%d" % i
		var p: Dictionary = plots[key] as Dictionary
		if int(p.get("block", 0)) <= next_level and str(p.get("state", "locked")) == "locked":
			p["state"] = "overgrown"
			plots[key] = p
	gs[&"plots"] = plots

	if next_level == 1:
		InventorySystem.add_item(world_state, &"item_semente_couve", 2)
		InventorySystem.add_item(world_state, &"item_semente_hortela", 2)
	elif next_level == 2:
		gs[&"watering_can_max"] = UPGRADED_WATER_MAX
		gs[&"watering_can_charges"] = UPGRADED_WATER_MAX
		InventorySystem.add_item(world_state, &"item_semente_tomate_cereja", 2)
		InventorySystem.add_item(world_state, &"item_composto_organico", 1)
	elif next_level == 3:
		EffectApplier.apply_one({"type": "inc_career_axis", "axis": "community_ties", "delta": 2}, world_state, event_bus)

	world_state.set("garden_state", gs)
	EffectApplier.apply_one({"type": "set_world_patch", "patch_id": "patch_horta_expansao", "stage": next_level}, world_state, event_bus)

	if event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")
		event_bus.emit_signal(&"notification_requested", "Horta expandida! " + str(info["title"]), &"project")
	return true


static func can_share_today(world_state: Node, npc_id: StringName) -> bool:
	if world_state == null or npc_id == &"":
		return false
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var shared_today: Array = gs.get(&"shared_today", []) as Array
	return not (String(npc_id) in shared_today)


static func get_available_produce_items(world_state: Node, registry: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	if world_state == null or registry == null:
		return result
	for crop_id: StringName in registry.call(&"get_all_crop_ids") as Array[StringName]:
		var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
		if crop != null and InventorySystem.get_count(world_state, crop.produce_item_id) > 0:
			if not (crop.produce_item_id in result):
				result.append(crop.produce_item_id)
	return result


static func get_available_seed_crops(world_state: Node, registry: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	if world_state == null or registry == null:
		return result
	for crop_id: StringName in registry.call(&"get_all_crop_ids") as Array[StringName]:
		var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
		if crop != null and InventorySystem.get_count(world_state, crop.seed_item_id) > 0:
			result.append(crop.id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func share_produce_with_npc(
	world_state: Node,
	registry: Node,
	event_bus: Node,
	npc_id: StringName,
	produce_item_id: StringName
) -> Dictionary:
	if world_state == null or registry == null or npc_id == &"" or produce_item_id == &"":
		return {"ok": false, "reason": "invalid"}
	ensure_initialized(world_state)
	if not can_share_today(world_state, npc_id):
		return {"ok": false, "reason": "already_shared_today"}
	if InventorySystem.get_count(world_state, produce_item_id) < 1:
		return {"ok": false, "reason": "no_produce"}

	var matched_crop: CropData = null
	for crop_id: StringName in registry.call(&"get_all_crop_ids") as Array[StringName]:
		var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
		if crop != null and crop.produce_item_id == produce_item_id:
			matched_crop = crop
			break

	var _removed: bool = InventorySystem.remove_item(world_state, produce_item_id, 1)
	var is_favorite: bool = matched_crop != null and (npc_id in matched_crop.favorite_npcs)

	if is_favorite:
		if npc_id == &"npc_hortencia":
			RelationshipService.adjust(world_state, event_bus, npc_id, &"trust", 2)
			RelationshipService.adjust(world_state, event_bus, npc_id, &"affinity", 1)
		elif npc_id == &"npc_b_2":
			RelationshipService.adjust(world_state, event_bus, npc_id, &"cooperation", 2)
			RelationshipService.adjust(world_state, event_bus, npc_id, &"familiarity", 1)
		elif npc_id == &"npc_b_1":
			RelationshipService.adjust(world_state, event_bus, npc_id, &"affinity", 2)
			RelationshipService.adjust(world_state, event_bus, npc_id, &"cooperation", 1)
		else:
			RelationshipService.adjust(world_state, event_bus, npc_id, &"affinity", 2)
			RelationshipService.adjust(world_state, event_bus, npc_id, &"trust", 1)
	else:
		RelationshipService.adjust(world_state, event_bus, npc_id, &"affinity", 1)
		RelationshipService.adjust(world_state, event_bus, npc_id, &"familiarity", 1)

	EffectApplier.apply_one({"type": "inc_career_axis", "axis": "community_ties", "delta": 1}, world_state, event_bus)

	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	gs[&"total_shares"] = int(gs.get(&"total_shares", 0)) + 1
	var shared_today: Array = gs.get(&"shared_today", []) as Array
	shared_today.append(String(npc_id))
	gs[&"shared_today"] = shared_today

	var shared_ever: Array = gs.get(&"shared_npcs_ever", []) as Array
	if not (String(npc_id) in shared_ever):
		shared_ever.append(String(npc_id))
	gs[&"shared_npcs_ever"] = shared_ever
	world_state.set("garden_state", gs)

	# Dona Rosa reciprocates with a seed if Alex is low on seeds
	var gifted_seed: StringName = &""
	if npc_id == &"npc_b_1" and is_favorite:
		gifted_seed = &"item_semente_tomate_cereja" if int(gs.get(&"level", 0)) >= 2 else &"item_semente_cheiro_verde"
		InventorySystem.add_item(world_state, gifted_seed, 1)

	if event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")
		var item_data: ItemData = registry.call(&"get_item", produce_item_id) as ItemData
		var item_name: String = item_data.display_name if item_data != null else String(produce_item_id)
		var msg: String = "Você compartilhou %s! (Favorito!)" % item_name if is_favorite else "Você compartilhou %s da horta!" % item_name
		event_bus.emit_signal(&"notification_requested", msg, &"garden")

	return {
		"ok": true,
		"is_favorite": is_favorite,
		"gifted_seed": gifted_seed,
	}


static func share_best_produce_with_npc(
	world_state: Node,
	registry: Node,
	event_bus: Node,
	npc_id: StringName
) -> Dictionary:
	var available: Array[StringName] = get_available_produce_items(world_state, registry)
	if available.is_empty():
		return {"ok": false, "reason": "no_produce"}
	# Prefer a favorite produce of this NPC if Alex is carrying one
	for item_id: StringName in available:
		for crop_id: StringName in registry.call(&"get_all_crop_ids") as Array[StringName]:
			var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
			if crop != null and crop.produce_item_id == item_id and (npc_id in crop.favorite_npcs):
				return share_produce_with_npc(world_state, registry, event_bus, npc_id, item_id)
	return share_produce_with_npc(world_state, registry, event_bus, npc_id, available[0])


static func is_mutirao_available(world_state: Node) -> bool:
	if world_state == null or not is_unlocked(world_state):
		return false
	var day: int = int(world_state.get("day"))
	var period: int = int(world_state.get("period"))
	if (day % 7) != 6 or period != 0:
		return false
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var done_days: Array = gs.get(&"mutirao_done_days", []) as Array
	return not (day in done_days)


static func participate_mutirao(world_state: Node, event_bus: Node) -> bool:
	if not is_mutirao_available(world_state):
		return false
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs[&"plots"] as Dictionary
	for key: Variant in plots.keys():
		var p: Dictionary = plots[key] as Dictionary
		var st: String = str(p.get("state", "locked"))
		if st == "planted" or st == "tilled":
			p["moisture"] = 2
			p["dry_ticks"] = 0
			p["weed_level"] = 0
			p["watered_by_npc"] = "npc_b_1"
			plots[key] = p
	gs[&"plots"] = plots

	var done_days: Array = gs.get(&"mutirao_done_days", []) as Array
	done_days.append(int(world_state.get("day")))
	gs[&"mutirao_done_days"] = done_days
	world_state.set("garden_state", gs)

	InventorySystem.add_item(world_state, &"item_semente_cheiro_verde", 1)
	InventorySystem.add_item(world_state, &"item_semente_alface", 1)
	RelationshipService.adjust(world_state, event_bus, &"npc_b_1", &"cooperation", 1)
	RelationshipService.adjust(world_state, event_bus, &"npc_b_2", &"cooperation", 1)
	EffectApplier.apply_one({"type": "inc_career_axis", "axis": "community_ties", "delta": 1}, world_state, event_bus)

	if event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")
		event_bus.emit_signal(&"notification_requested", "Mutirão de sábado concluído! Canteiros regados e sementes trocadas.", &"project")
	return true


static func process_tick(
	is_day_end: bool,
	world_state: Node,
	registry: Node,
	event_bus: Node = null
) -> void:
	if world_state == null or registry == null:
		return
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary

	if is_day_end:
		gs[&"shared_today"] = []
		if int(gs.get(&"level", 0)) >= 2:
			var ready_days: int = int(gs.get(&"compost_ready_days", 0)) + 1
			if ready_days >= 2:
				ready_days = 0
				var avail: int = int(gs.get(&"compost_available", 0))
				gs[&"compost_available"] = mini(MAX_COMPOST_STORED, avail + 1)
			gs[&"compost_ready_days"] = ready_days

	var plots: Dictionary = gs.get(&"plots", {}) as Dictionary
	var current_day: int = int(world_state.get("day"))
	var current_period: int = int(world_state.get("period"))
	var is_hot_day_transition: bool = (current_period == 1 or current_period == 2)
	var any_planted: bool = false
	var any_changed: bool = false

	for i: int in range(PLOT_COUNT):
		var key: String = "plot_%d" % i
		if not plots.has(key):
			continue
		var p: Dictionary = plots[key] as Dictionary
		var st: String = str(p.get("state", "locked"))
		if st == "tilled":
			var m: int = int(p.get("moisture", 0))
			if m > 0 and (is_day_end or is_hot_day_transition):
				p["moisture"] = maxi(0, m - 1)
				plots[key] = p
				any_changed = true
			continue
		if st != "planted":
			continue

		any_planted = true
		var crop_id: StringName = StringName(str(p.get("crop_id", "")))
		var crop: CropData = registry.call(&"get_crop", crop_id) as CropData
		if crop == null:
			continue

		var moisture: int = int(p.get("moisture", 0))
		var weeds: int = int(p.get("weed_level", 0))
		var fertilized: bool = bool(p.get("fertilized", false))

		# 1. Growth step if soil is moist
		if moisture > 0:
			var gain: int = 2 if (fertilized and weeds == 0) else 1
			var next_pts: int = int(p.get("growth_points", 0)) + gain
			p["growth_points"] = next_pts
			p["dry_ticks"] = 0
			if next_pts >= crop.growth_target:
				p["stage"] = 3
				p["state"] = "harvestable"
			else:
				p["stage"] = clampi(int(floor(float(next_pts * 3) / float(crop.growth_target))), 0, 2)
			any_changed = true

		# 2. Moisture drain
		if is_day_end:
			if moisture == 0:
				var dry_t: int = int(p.get("dry_ticks", 0)) + 1
				p["dry_ticks"] = dry_t
				if dry_t >= 2 and weeds == 0 and ((current_day + i) % 2 == 0):
					p["weed_level"] = 1
					p["fertilized"] = false
				any_changed = true
			else:
				p["moisture"] = maxi(0, moisture - 1)
				any_changed = true
		elif is_hot_day_transition and crop.water_drain_per_day_period > 0 and moisture > 0:
			p["moisture"] = maxi(0, moisture - crop.water_drain_per_day_period)
			any_changed = true

		plots[key] = p

	# 3. Spontaneous neighbor help at start of a new day (only if player has planted crops)
	if is_day_end and any_planted:
		_process_spontaneous_npc_help(world_state, plots, event_bus)
		any_changed = true

	gs[&"plots"] = plots
	world_state.set("garden_state", gs)
	if any_changed and event_bus != null:
		event_bus.emit_signal(&"garden_state_changed")


static func _process_spontaneous_npc_help(world_state: Node, plots: Dictionary, event_bus: Node) -> void:
	# Dona Rosa waters up to 2 dry plots if affinity >= 3 or cooperation >= 2 and healthy
	var rosa_aff: int = RelationshipService.get_axis(world_state, &"npc_b_1", &"affinity")
	var rosa_coop: int = RelationshipService.get_axis(world_state, &"npc_b_1", &"cooperation")
	if (rosa_aff >= 3 or rosa_coop >= 2) and not EnvironmentalInspectionService.is_npc_infected(world_state, &"npc_b_1"):
		var watered: int = 0
		for i: int in range(PLOT_COUNT):
			if watered >= 2:
				break
			var key: String = "plot_%d" % i
			var p: Dictionary = plots[key] as Dictionary
			if str(p.get("state", "")) == "planted" and int(p.get("moisture", 0)) == 0:
				p["moisture"] = 2
				p["dry_ticks"] = 0
				p["watered_by_npc"] = "npc_b_1"
				plots[key] = p
				watered += 1
		if watered > 0 and event_bus != null:
			event_bus.emit_signal(
				&"notification_requested",
				"Dona Rosa passou cedo na horta e regou %d canteiro(s)!" % watered,
				&"garden"
			)

	# Tiago clears weeds from up to 2 plots if cooperation >= 2 and healthy
	var tiago_coop: int = RelationshipService.get_axis(world_state, &"npc_b_2", &"cooperation")
	if tiago_coop >= 2 and not EnvironmentalInspectionService.is_npc_infected(world_state, &"npc_b_2"):
		var weeded: int = 0
		for i: int in range(PLOT_COUNT):
			if weeded >= 2:
				break
			var key: String = "plot_%d" % i
			var p: Dictionary = plots[key] as Dictionary
			if str(p.get("state", "")) == "planted" and int(p.get("weed_level", 0)) > 0:
				p["weed_level"] = 0
				plots[key] = p
				weeded += 1
		if weeded > 0 and event_bus != null:
			event_bus.emit_signal(
				&"notification_requested",
				"Tiago ajudou a limpar mato de %d canteiro(s) na horta!" % weeded,
				&"garden"
			)

	# Pedro waters 1 dry plot if Family A trusts Alex and Pedro is healthy
	var lucia_trust: int = RelationshipService.get_axis(world_state, &"npc_a_2", &"trust")
	if lucia_trust >= 2 and not EnvironmentalInspectionService.is_npc_infected(world_state, &"npc_a_3"):
		for i: int in range(PLOT_COUNT):
			var key: String = "plot_%d" % i
			var p: Dictionary = plots[key] as Dictionary
			if str(p.get("state", "")) == "planted" and int(p.get("moisture", 0)) == 0:
				p["moisture"] = 2
				p["dry_ticks"] = 0
				p["watered_by_npc"] = "npc_a_3"
				plots[key] = p
				if event_bus != null:
					event_bus.emit_signal(&"notification_requested", "Pedro passou na horta e regou um canteiro!", &"garden")
				break


static func get_summary_counts(world_state: Node) -> Dictionary:
	ensure_initialized(world_state)
	var gs: Dictionary = world_state.get("garden_state") as Dictionary
	var plots: Dictionary = gs.get(&"plots", {}) as Dictionary
	var ready: int = 0
	var dry: int = 0
	var planted: int = 0
	for key: Variant in plots.keys():
		var p: Dictionary = plots[key] as Dictionary
		var st: String = str(p.get("state", "locked"))
		if st == "harvestable":
			ready += 1
		elif st == "planted":
			planted += 1
			if int(p.get("moisture", 0)) == 0:
				dry += 1
	return {
		"unlocked": bool(gs.get(&"unlocked", false)),
		"level": int(gs.get(&"level", 0)),
		"ready": ready,
		"dry": dry,
		"planted": planted,
		"total_harvests": int(gs.get(&"total_harvests", 0)),
		"total_shares": int(gs.get(&"total_shares", 0)),
		"compost_available": int(gs.get(&"compost_available", 0)),
	}
