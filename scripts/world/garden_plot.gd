class_name GardenPlot
extends Interactable
## Interactive soil bed in HortaComunitaria with visual growth stages, moisture, weeds, and particles.

@export var plot_id: StringName = &"plot_0"

var _soil_sprite: Sprite2D = null
var _border_sprite: Sprite2D = null
var _crop_sprite: Sprite2D = null
var _weed_sprite: Sprite2D = null
var _state_cache: Dictionary = {}
var _anim_time: float = 0.0
var _crop_tex_cache: Dictionary = {}


func _ready() -> void:
	_soil_sprite = Sprite2D.new()
	_soil_sprite.name = "SoilSprite"
	add_child(_soil_sprite)

	_border_sprite = Sprite2D.new()
	_border_sprite.name = "WoodBorder"
	_border_sprite.visible = false
	if ResourceLoader.exists("res://assets/objects/garden/plot_wood_border.png"):
		_border_sprite.texture = load("res://assets/objects/garden/plot_wood_border.png") as Texture2D
	add_child(_border_sprite)

	_crop_sprite = Sprite2D.new()
	_crop_sprite.name = "CropSprite"
	_crop_sprite.position = Vector2(0.0, -3.0)
	_crop_sprite.visible = false
	add_child(_crop_sprite)

	_weed_sprite = Sprite2D.new()
	_weed_sprite.name = "WeedSprite"
	_weed_sprite.visible = false
	if ResourceLoader.exists("res://assets/objects/garden/plot_weed_overlay.png"):
		_weed_sprite.texture = load("res://assets/objects/garden/plot_weed_overlay.png") as Texture2D
	add_child(_weed_sprite)

	if not interacted.is_connected(_on_interacted):
		var err1: Error = interacted.connect(_on_interacted)
		if err1 != OK:
			push_warning("GardenPlot failed to connect interacted.")

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		if not bus.is_connected(&"garden_plot_changed", _on_plot_changed):
			var err2: Error = bus.connect(&"garden_plot_changed", _on_plot_changed)
			if err2 != OK:
				push_warning("GardenPlot failed to connect garden_plot_changed.")
		if not bus.is_connected(&"garden_state_changed", _on_garden_state_changed):
			var err3: Error = bus.connect(&"garden_state_changed", _on_garden_state_changed)
			if err3 != OK:
				push_warning("GardenPlot failed to connect garden_state_changed.")

	refresh_visual()


func _process(delta: float) -> void:
	var st: String = str(_state_cache.get("state", "locked"))
	var needs_anim: bool = (
		st == "harvestable"
		or int(_state_cache.get("dry_ticks", 0)) >= 1
		or not str(_state_cache.get("watered_by_npc", "")).is_empty()
	)
	if not needs_anim:
		return
	_anim_time += delta
	queue_redraw()


func _draw() -> void:
	var st: String = str(_state_cache.get("state", "locked"))
	if st == "harvestable":
		# Gentle golden sparkle above mature crop
		var bob: float = sin(_anim_time * 4.5) * 1.5
		var sp: Vector2 = Vector2(0.0, -16.0 + bob)
		draw_line(sp + Vector2(-3.0, 0.0), sp + Vector2(3.0, 0.0), Color(1.0, 0.92, 0.42, 0.95), 1.0)
		draw_line(sp + Vector2(0.0, -3.0), sp + Vector2(0.0, 3.0), Color(1.0, 0.92, 0.42, 0.95), 1.0)
	elif st == "planted" and int(_state_cache.get("dry_ticks", 0)) >= 1:
		# Subtle blue/gray water droplet icon when dry
		var bob: float = sin(_anim_time * 3.2) * 1.2
		var dp: Vector2 = Vector2(7.0, -12.0 + bob)
		draw_circle(dp, 2.5, Color(0.56, 0.78, 0.94, 0.9))
		draw_arc(dp, 2.5, 0.0, TAU, 8, Color(0.16, 0.24, 0.34, 0.9), 1.0)
	elif not str(_state_cache.get("watered_by_npc", "")).is_empty():
		var bob: float = sin(_anim_time * 3.0) * 1.2
		var hp: Vector2 = Vector2(-7.0, -13.0 + bob)
		draw_circle(hp, 2.5, Color(0.46, 0.86, 0.48, 0.9))
		draw_arc(hp, 2.5, 0.0, TAU, 8, Color(0.16, 0.36, 0.18, 0.9), 1.0)


func refresh_visual() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var reg: Node = get_node_or_null("/root/DataRegistry")
	if ws == null:
		return
	_state_cache = CommunityGardenService.get_plot_state(ws, plot_id)
	var st: String = str(_state_cache.get("state", "locked"))
	var moisture: int = int(_state_cache.get("moisture", 0))
	var weeds: int = int(_state_cache.get("weed_level", 0))
	var level: int = CommunityGardenService.get_level(ws)

	# Soil texture
	var soil_path: String = "res://assets/objects/garden/plot_locked.png"
	if st == "overgrown":
		soil_path = "res://assets/objects/garden/plot_overgrown.png"
	elif st == "tilled" or st == "planted" or st == "harvestable":
		soil_path = "res://assets/objects/garden/plot_tilled_wet.png" if moisture > 0 else "res://assets/objects/garden/plot_tilled_dry.png"

	if _soil_sprite != null and ResourceLoader.exists(soil_path):
		_soil_sprite.texture = load(soil_path) as Texture2D

	if _border_sprite != null:
		_border_sprite.visible = (st != "locked" and level >= 1)

	if _weed_sprite != null:
		_weed_sprite.visible = (st == "planted" and weeds > 0)

	# Crop sprite frame
	var crop_key: String = str(_state_cache.get("crop_id", ""))
	if _crop_sprite != null:
		if (st == "planted" or st == "harvestable") and not crop_key.is_empty() and reg != null:
			var crop: CropData = reg.call(&"get_crop", StringName(crop_key)) as CropData
			if crop != null and ResourceLoader.exists(crop.sprite_sheet_path):
				var sheet: Texture2D = _get_cached_tex(crop.sprite_sheet_path)
				var stage: int = clampi(int(_state_cache.get("stage", 0)), 0, 3)
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(float(stage * 24), 0.0, 24.0, 24.0)
				_crop_sprite.texture = atlas
				_crop_sprite.visible = true
				# Subtle wilted tint if dry for >= 1 day
				_crop_sprite.modulate = Color(0.86, 0.84, 0.72, 1.0) if int(_state_cache.get("dry_ticks", 0)) >= 1 else Color.WHITE
			else:
				_crop_sprite.visible = false
		else:
			_crop_sprite.visible = false

	_update_prompt(reg)
	queue_redraw()


func _update_prompt(reg: Node) -> void:
	var st: String = str(_state_cache.get("state", "locked"))
	match st:
		"locked":
			prompt_text = "Espaço reservado (Expandir horta)"
		"overgrown":
			prompt_text = "Preparar canteiro"
		"tilled":
			prompt_text = "Canteiro pronto (Plantar / Regar)"
		"harvestable":
			var cname: String = _get_crop_name(reg)
			prompt_text = "Colher %s!" % cname
		"planted":
			var cname: String = _get_crop_name(reg)
			if int(_state_cache.get("weed_level", 0)) > 0:
				prompt_text = "Limpar mato / Cuidar (%s)" % cname
			elif int(_state_cache.get("moisture", 0)) == 0:
				prompt_text = "Regar %s" % cname
			else:
				prompt_text = "Acompanhar %s" % cname
		_:
			prompt_text = "Canteiro"


func _get_crop_name(reg: Node) -> String:
	var crop_key: String = str(_state_cache.get("crop_id", ""))
	if reg != null and not crop_key.is_empty():
		var crop: CropData = reg.call(&"get_crop", StringName(crop_key)) as CropData
		if crop != null:
			return crop.display_name
	return "Planta"


func _on_plot_changed(changed_id: StringName) -> void:
	if changed_id == plot_id:
		refresh_visual()


func _on_garden_state_changed() -> void:
	refresh_visual()


func _on_interacted(_actor: Node) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var reg: Node = get_node_or_null("/root/DataRegistry")
	var bus: Node = get_node_or_null("/root/EventBus")
	if ws == null:
		return

	if not CommunityGardenService.is_unlocked(ws):
		if bus != null:
			bus.emit_signal(&"notification_requested", "Converse com Dona Rosa para abrir a Horta Comunitária!", &"info")
		return

	var st: String = str(_state_cache.get("state", "locked"))
	if st == "locked":
		if bus != null:
			bus.emit_signal(&"notification_requested", "Este bloco será liberado ao expandir a horta no Quadro Comunitário.", &"info")
		return

	var tool_idx: int = _get_active_tool_index()
	var selected_crop: StringName = _get_selected_seed_crop()

	# Tool 5 = Magnifier / Inspect
	if tool_idx == 5:
		_show_inspect_toast(reg, bus)
		return

	# Quality-of-life: harvesting a mature crop works with any tool (except magnifier)
	if st == "harvestable":
		var h_res: Dictionary = CommunityGardenService.harvest_plot(ws, reg, bus, plot_id)
		if bool(h_res.get("ok", false)):
			_play_squash_fx()
			_spawn_burst(Color(0.54, 0.86, 0.36, 1.0))
			_spawn_floating_text("+%d %s" % [int(h_res.get("amount", 1)), str(h_res.get("display_name", ""))])
		return

	match tool_idx:
		0: # Regador
			var w_res: Dictionary = CommunityGardenService.water_plot(ws, bus, plot_id)
			if bool(w_res.get("ok", false)):
				_play_squash_fx()
				_spawn_burst(Color(0.46, 0.78, 0.98, 1.0))
		1: # Enxada
			var p_res: Dictionary = CommunityGardenService.prepare_plot(ws, bus, plot_id)
			if bool(p_res.get("ok", false)):
				_play_squash_fx()
				_spawn_burst(Color(0.62, 0.44, 0.28, 1.0))
		2: # Sementes
			if st == "overgrown":
				if bus != null:
					bus.emit_signal(&"notification_requested", "Use a Enxada [2] para preparar a terra primeiro.", &"info")
				return
			if selected_crop == &"":
				if bus != null:
					bus.emit_signal(&"notification_requested", "Sem sementes na mochila. Converse com Dona Rosa ou participe do mutirão!", &"info")
				return
			var s_res: Dictionary = CommunityGardenService.plant_seed(ws, reg, bus, plot_id, selected_crop)
			if bool(s_res.get("ok", false)):
				_play_squash_fx()
				_spawn_burst(Color(0.92, 0.82, 0.46, 1.0))
		3: # Composto
			var f_res: Dictionary = CommunityGardenService.fertilize_plot(ws, bus, plot_id)
			if bool(f_res.get("ok", false)):
				_play_squash_fx()
				_spawn_burst(Color(0.76, 0.62, 0.32, 1.0))
				_spawn_floating_text("Adubado!")
		4: # Cesta (se ainda não está maduro)
			_show_inspect_toast(reg, bus)


func _show_inspect_toast(reg: Node, bus: Node) -> void:
	if bus == null:
		return
	var st: String = str(_state_cache.get("state", "locked"))
	if st == "overgrown":
		bus.emit_signal(&"notification_requested", "Terra com mato: use a Enxada [2] para preparar.", &"garden")
	elif st == "tilled":
		bus.emit_signal(&"notification_requested", "Canteiro preparado! Selecione Sementes [3] para plantar.", &"garden")
	elif st == "planted":
		var cname: String = _get_crop_name(reg)
		var stage: int = int(_state_cache.get("stage", 0))
		var moist: String = "Úmido" if int(_state_cache.get("moisture", 0)) > 0 else "Seco (precisa de água)"
		var fert: String = " · Adubado" if bool(_state_cache.get("fertilized", false)) else ""
		bus.emit_signal(&"notification_requested", "%s (Estágio %d/3) · %s%s" % [cname, stage, moist, fert], &"garden")


func _get_active_tool_index() -> int:
	for ui: Node in get_tree().get_nodes_in_group(&"garden_hotbar_ui"):
		if ui.has_method(&"get_selected_tool"):
			return int(ui.call(&"get_selected_tool"))
	return 0


func _get_selected_seed_crop() -> StringName:
	for ui: Node in get_tree().get_nodes_in_group(&"garden_hotbar_ui"):
		if ui.has_method(&"get_selected_seed_crop"):
			return ui.call(&"get_selected_seed_crop") as StringName
	return &""


func _play_squash_fx() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 0.88), 0.08)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)


func _spawn_burst(col: Color) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.42
	p.explosiveness = 0.9
	p.direction = Vector2(0.0, -1.0)
	p.spread = 75.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 38.0
	p.gravity = Vector2(0.0, 90.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = col
	add_child(p)
	var timer: SceneTreeTimer = get_tree().create_timer(0.55)
	var err: Error = timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
	if err != OK:
		push_warning("GardenPlot failed to connect particle cleanup timer.")


func _spawn_floating_text(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.position = Vector2(-28.0, -24.0)
	lbl.z_index = 40
	lbl.add_theme_font_size_override(&"font_size", 8)
	lbl.add_theme_color_override(&"font_color", Color(1.0, 0.96, 0.72, 1.0))
	lbl.add_theme_color_override(&"font_shadow_color", Color(0.12, 0.08, 0.05, 0.95))
	lbl.add_theme_constant_override(&"shadow_offset_x", 1)
	lbl.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(lbl)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 16.0, 0.75)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75)
	var err: Error = tw.finished.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)
	if err != OK:
		push_warning("GardenPlot failed to connect floating label cleanup.")


func _get_cached_tex(path: String) -> Texture2D:
	if not _crop_tex_cache.has(path):
		_crop_tex_cache[path] = load(path) as Texture2D
	return _crop_tex_cache[path] as Texture2D
