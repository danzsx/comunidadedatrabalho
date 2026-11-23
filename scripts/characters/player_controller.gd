class_name PlayerController
extends CharacterBody2D
## Top-down 4-direction animated movement controller for Alex with footstep dust particles.

@export var move_speed: float = 84.0

var _movement_locked: bool = false
var _facing: Vector2 = Vector2.DOWN
var _facing_dir_name: String = "down"

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footstep_dust: CPUParticles2D = get_node_or_null("FootstepDust") as CPUParticles2D


func _ready() -> void:
	add_to_group(&"player")
	if anim_sprite != null:
		var sheet: Texture2D = load("res://assets/characters/sheets/alex_sheet.png") as Texture2D
		if sheet != null:
			anim_sprite.sprite_frames = CharacterAnimBuilder.build_from_sheet(sheet, 24, 32)
			anim_sprite.play(&"idle_down")


func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		velocity = Vector2.ZERO
		_update_animation(false)


func is_movement_locked() -> bool:
	return _movement_locked


func get_facing() -> Vector2:
	return _facing


func _physics_process(_delta: float) -> void:
	if _movement_locked:
		velocity = Vector2.ZERO
		_update_animation(false)
		return

	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input_dir == Vector2.ZERO:
		input_dir = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")

	var moving: bool = input_dir != Vector2.ZERO
	if moving:
		input_dir = input_dir.normalized()
		_facing = input_dir
		_facing_dir_name = _dir_to_name(input_dir)

	velocity = input_dir * move_speed
	var _collided: bool = move_and_slide()
	WorldState.player_position = global_position
	_update_animation(moving)


func _update_animation(moving: bool) -> void:
	if footstep_dust != null:
		footstep_dust.emitting = moving
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	var anim_name := StringName(("walk_" if moving else "idle_") + _facing_dir_name)
	if anim_sprite.sprite_frames.has_animation(anim_name) and anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)


func _dir_to_name(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "left" if dir.x < 0.0 else "right"
	return "up" if dir.y < 0.0 else "down"


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
