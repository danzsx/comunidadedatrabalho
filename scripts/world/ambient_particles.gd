class_name AmbientParticles
extends Node2D
## Ambient world particles: golden pollen/petals during day, warm glowing fireflies at night.

@export var area_size: Vector2 = Vector2(640.0, 448.0)

var _particles: CPUParticles2D = null


func _ready() -> void:
	z_index = 18
	_particles = CPUParticles2D.new()
	_particles.position = area_size * 0.5
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = area_size * 0.5
	_particles.amount = 28
	_particles.lifetime = 5.5
	_particles.preprocess = 3.0
	_particles.gravity = Vector2(4.0, 6.0)
	_particles.initial_velocity_min = 3.0
	_particles.initial_velocity_max = 10.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 2.6
	add_child(_particles)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"period_changed", _on_period_changed):
		var err: Error = bus.connect(&"period_changed", _on_period_changed)
		if err != OK:
			push_warning("AmbientParticles failed to connect period_changed.")

	var ws: Node = get_node_or_null("/root/WorldState")
	var period: int = int(ws.get("period")) if ws != null else 0
	_apply_period(period)


func _on_period_changed(_new_day: int, new_period: int) -> void:
	_apply_period(new_period)


func _apply_period(period: int) -> void:
	if _particles == null:
		return
	match period:
		0: # Manha: golden sunlit pollen
			_particles.color = Color(1.0, 0.96, 0.72, 0.55)
			_particles.gravity = Vector2(6.0, 5.0)
			_particles.amount = 24
		1: # Tarde: warm ipê flower petals
			_particles.color = Color(1.0, 0.84, 0.36, 0.72)
			_particles.gravity = Vector2(10.0, 9.0)
			_particles.amount = 32
		2: # Noite: glowing amber fireflies
			_particles.color = Color(1.0, 0.92, 0.48, 0.92)
			_particles.gravity = Vector2(0.0, -4.0)
			_particles.amount = 30
		3: # Madrugada: sparse mystical blue-gold motes
			_particles.color = Color(0.76, 0.88, 1.0, 0.65)
			_particles.gravity = Vector2(0.0, -3.0)
			_particles.amount = 20
