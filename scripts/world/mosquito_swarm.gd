class_name MosquitoSwarm
extends Node2D
## Renders animated pixel-art mosquito swarms around infested zones and the plaza when inspections fail.

var _mosquitoes: Array[Dictionary] = []
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 19
	_rng.seed = 94217
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		if not bus.is_connected(&"environmental_state_changed", _on_env_changed):
			var err1: Error = bus.connect(&"environmental_state_changed", _on_env_changed)
			if err1 != OK:
				push_warning("MosquitoSwarm failed to connect environmental_state_changed.")
		if not bus.is_connected(&"period_changed", _on_period_changed):
			var err2: Error = bus.connect(&"period_changed", _on_period_changed)
			if err2 != OK:
				push_warning("MosquitoSwarm failed to connect period_changed.")
	rebuild_swarms()


func _on_env_changed(_zone_id: StringName, _status: String) -> void:
	rebuild_swarms()


func _on_period_changed(_day: int, _period: int) -> void:
	rebuild_swarms()


func rebuild_swarms() -> void:
	_mosquitoes.clear()
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		queue_redraw()
		return

	var infested: Array[String] = EnvironmentalInspectionService.get_infested_zones(ws)
	var total_level: int = EnvironmentalInspectionService.get_total_mosquito_level(ws)

	for zone_key: String in infested:
		var z_def: Dictionary = EnvironmentalInspectionService.get_zone_def(StringName(zone_key))
		var z_state: Dictionary = EnvironmentalInspectionService.get_zone_state(ws, StringName(zone_key))
		var origin: Vector2 = z_def.get("world_pos", Vector2(320.0, 228.0)) as Vector2
		var level: int = int(z_state.get("mosquito_level", 1))
		var count: int = 7 * maxi(1, level)
		for _i: int in range(count):
			_mosquitoes.append({
				"origin": origin + Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-14.0, 10.0)),
				"radius_x": _rng.randf_range(8.0, 24.0),
				"radius_y": _rng.randf_range(6.0, 16.0),
				"speed": _rng.randf_range(2.6, 5.2),
				"phase": _rng.randf_range(0.0, TAU),
			})

	# If infestation is high, mosquitoes also spread toward the central plaza.
	if total_level >= 2:
		var plaza_center: Vector2 = Vector2(320.0, 232.0)
		for _j: int in range(6):
			_mosquitoes.append({
				"origin": plaza_center + Vector2(_rng.randf_range(-44.0, 44.0), _rng.randf_range(-28.0, 28.0)),
				"radius_x": _rng.randf_range(12.0, 28.0),
				"radius_y": _rng.randf_range(8.0, 18.0),
				"speed": _rng.randf_range(2.4, 4.4),
				"phase": _rng.randf_range(0.0, TAU),
			})

	queue_redraw()


func _process(delta: float) -> void:
	if _mosquitoes.is_empty():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _mosquitoes.is_empty():
		return
	var wing_flip: bool = int(_time * 24.0) % 2 == 0
	var body_col: Color = Color(0.10, 0.09, 0.08, 0.95)
	var wing_col: Color = Color(0.92, 0.94, 0.98, 0.75)

	for m: Dictionary in _mosquitoes:
		var origin: Vector2 = m["origin"] as Vector2
		var rx: float = float(m["radius_x"])
		var ry: float = float(m["radius_y"])
		var spd: float = float(m["speed"])
		var ph: float = float(m["phase"])
		var t: float = _time * spd + ph

		var pos: Vector2 = Vector2(
			roundf(origin.x + cos(t) * rx),
			roundf(origin.y + sin(t * 1.7) * ry - 10.0)
		)
		# Crisp 2x1 pixel body + flickering 1px wings
		draw_rect(Rect2(pos, Vector2(2.0, 1.0)), body_col)
		var wy: float = -1.0 if wing_flip else 1.0
		draw_rect(Rect2(pos + Vector2(0.0, wy), Vector2(1.0, 1.0)), wing_col)
		draw_rect(Rect2(pos + Vector2(1.0, wy), Vector2(1.0, 1.0)), wing_col)
