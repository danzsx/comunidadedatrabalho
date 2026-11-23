class_name PlayerController
extends CharacterBody2D
## Top-down 4-direction movement controller for Alex.

@export var move_speed: float = 82.0

var _movement_locked: bool = false
var _facing: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group(&"player")


func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		velocity = Vector2.ZERO


func is_movement_locked() -> bool:
	return _movement_locked


func get_facing() -> Vector2:
	return _facing


func _physics_process(_delta: float) -> void:
	if _movement_locked:
		velocity = Vector2.ZERO
		return

	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input_dir == Vector2.ZERO:
		input_dir = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		_facing = input_dir
		if sprite != null and absf(input_dir.x) > 0.1:
			sprite.flip_h = input_dir.x < 0.0

	velocity = input_dir * move_speed
	var _collided: bool = move_and_slide()
	WorldState.player_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F5:
				TimeSystem.advance_period(1)
			elif key_event.keycode == KEY_F6:
				TimeSystem.sleep_until_morning()
