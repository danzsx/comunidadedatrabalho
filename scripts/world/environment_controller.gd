class_name EnvironmentController
extends Node2D
## Controls CanvasModulate and PointLight2D intensities for the 4 day periods.

const EXTERIOR_COLORS: Dictionary = {
	0: Color("fffdf5"), # Manha
	1: Color("ffd7b3"), # Tarde
	2: Color("4e6294"), # Noite
	3: Color("2b3459"), # Madrugada
}

const INTERIOR_COLORS: Dictionary = {
	0: Color("fffdf8"),
	1: Color("ffe8d4"),
	2: Color("9ca8c8"),
	3: Color("7884aa"),
}

const LIGHT_ENERGIES: Dictionary = {
	0: 0.0,
	1: 0.2,
	2: 0.9,
	3: 0.7,
}

@export var is_interior: bool = false
@export var use_period_lighting: bool = true
@export var transition_duration: float = 0.45

@onready var canvas_modulate: CanvasModulate = get_node_or_null("CanvasModulate") as CanvasModulate

var _active_tween: Tween = null


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"period_changed", _on_period_changed):
		var err: Error = bus.connect(&"period_changed", _on_period_changed)
		if err != OK:
			push_warning("EnvironmentController failed to connect period_changed.")
	var ws: Node = get_node_or_null("/root/WorldState")
	var initial_period: int = int(ws.get("period")) if ws != null else 0
	apply_period(initial_period, false)


func _on_period_changed(_new_day: int, new_period: int) -> void:
	apply_period(new_period, true)


func apply_period(period: int, animate: bool) -> void:
	if not use_period_lighting:
		return
	var target_color: Color = get_period_color(period, is_interior)
	var target_energy: float = float(LIGHT_ENERGIES.get(period, 0.0))

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	if not animate or not is_inside_tree():
		if canvas_modulate != null:
			canvas_modulate.color = target_color
		_set_night_lights_energy(target_energy)
		return

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	if canvas_modulate != null:
		_active_tween.tween_property(canvas_modulate, "color", target_color, transition_duration)
	for node: Node in get_tree().get_nodes_in_group(&"night_lights"):
		if node is PointLight2D and is_ancestor_of(node):
			var light: PointLight2D = node as PointLight2D
			light.enabled = target_energy > 0.01
			_active_tween.tween_property(light, "energy", target_energy, transition_duration)


func _set_night_lights_energy(target_energy: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"night_lights"):
		if node is PointLight2D and is_ancestor_of(node):
			var light: PointLight2D = node as PointLight2D
			light.energy = target_energy
			light.enabled = target_energy > 0.01


static func get_period_color(period: int, interior: bool) -> Color:
	var table: Dictionary = INTERIOR_COLORS if interior else EXTERIOR_COLORS
	return table.get(period, Color.WHITE) as Color
