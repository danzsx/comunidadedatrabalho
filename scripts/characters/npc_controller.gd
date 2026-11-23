class_name NPCController
extends CharacterBody2D
## Living NPC with 4-direction animations, gentle wandering AI, and spontaneous speech bubbles.

const AMBIENT_LINES: Dictionary = {
	&"npc_hortencia": [
		"Café fresco na UBS ajuda a começar o dia...",
		"Escutar com calma resolve metade do caminho.",
		"Como será que está a Família Alencar hoje?",
	],
	&"npc_a_1": [
		"O rádio hoje só toca moda antiga...",
		"Esse corredor anda meio úmido.",
	],
	&"npc_a_2": [
		"Tanta costura pra entregar ainda hoje...",
		"Preciso organizar aquelas receitas.",
	],
	&"npc_a_3": [
		"A praça fica boa no fim da tarde!",
		"Tô terminando um desenho novo.",
	],
	&"npc_b_1": [
		"Esses ipês estão lindos nesta época.",
		"Terra boa precisa de paciência e água.",
		"Aquele canteiro ainda vai dar flor...",
	],
	&"npc_b_2": [
		"Falta apertar a corrente daquela bicicleta.",
		"Fim de tarde bom pra tomar um ar.",
	],
	&"npc_c_1": [
		"Semana corrida no comércio!",
		"Oi vizinhança!",
	],
	&"npc_c_2": [
		"Será que vale aceitar aquele turno fora?",
		"O interior tem um silêncio diferente...",
	],
}

@export var character_id: StringName = &""
@export var dialogue_start_node: String = "start"
@export var wander_radius: float = 30.0
@export var wander_speed: float = 20.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interactable: Interactable = $Interactable

var _character_data: CharacterData = null
var _speech_bubble: WorldSpeechBubble = null
var _home_spot: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _is_wandering: bool = false
var _wander_timer: float = 2.0
var _bubble_timer: float = 5.0
var _facing_dir: String = "down"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"npcs")
	_rng.seed = abs(hash(character_id)) + Time.get_ticks_msec()
	_home_spot = position
	_wander_timer = _rng.randf_range(1.8, 4.2)
	_bubble_timer = _rng.randf_range(4.0, 9.5)

	_speech_bubble = WorldSpeechBubble.new()
	add_child(_speech_bubble)

	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		var err: Error = interactable.interacted.connect(_on_interacted)
		if err != OK:
			push_warning("NPCController failed to connect interacted.")
	apply_character_data()


func apply_character_data() -> void:
	var registry: Node = get_node_or_null("/root/DataRegistry")
	if registry == null or character_id == &"":
		return
	_character_data = registry.call(&"get_character", character_id) as CharacterData
	if _character_data == null:
		return
	if anim_sprite != null:
		var sheet_path: String = "res://assets/characters/sheets/%s_sheet.png" % String(character_id)
		if ResourceLoader.exists(sheet_path):
			var tex: Texture2D = load(sheet_path) as Texture2D
			if tex != null:
				anim_sprite.sprite_frames = CharacterAnimBuilder.build_from_sheet(tex, 24, 32)
				anim_sprite.play(&"idle_down")
	if interactable != null:
		interactable.prompt_text = "Falar com %s" % _character_data.display_name


func _physics_process(delta: float) -> void:
	# Pause AI if Alex is currently locked (dialogue/UI open)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	var player_node: Node2D = players[0] as Node2D if players.size() > 0 and players[0] is Node2D else null
	if player_node != null and player_node.has_method(&"is_movement_locked") and bool(player_node.call(&"is_movement_locked")):
		velocity = Vector2.ZERO
		_play_anim(false)
		return

	# Gentle ambient speech bubble when Alex is nearby
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = _rng.randf_range(8.0, 15.0)
		if player_node != null and global_position.distance_to(player_node.global_position) < 150.0:
			_say_ambient_line()

	# Seu Antonio rests quietly in place (just looks around gently)
	if character_id == &"npc_a_1":
		velocity = Vector2.ZERO
		_play_anim(false)
		return

	if _is_wandering:
		var to_target: Vector2 = _wander_target - position
		if to_target.length() < 3.0:
			_is_wandering = false
			velocity = Vector2.ZERO
			_wander_timer = _rng.randf_range(2.2, 5.2)
			_play_anim(false)
		else:
			var dir: Vector2 = to_target.normalized()
			_facing_dir = _dir_to_name(dir)
			velocity = dir * wander_speed
			var collided: bool = move_and_slide()
			_play_anim(true)
			if collided:
				_is_wandering = false
				velocity = Vector2.ZERO
				_wander_timer = _rng.randf_range(1.8, 3.5)
				_play_anim(false)
	else:
		velocity = Vector2.ZERO
		_play_anim(false)
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			var angle: float = _rng.randf_range(0.0, TAU)
			var dist: float = _rng.randf_range(10.0, wander_radius)
			_wander_target = _home_spot + Vector2(cos(angle), sin(angle)) * dist
			_is_wandering = true


func _say_ambient_line() -> void:
	if _speech_bubble == null:
		return
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		if bool(ws.call(&"get_fact", &"praca_canteiro_recuperado", false)) and character_id in [&"npc_b_1", &"npc_hortencia", &"npc_c_1"]:
			_speech_bubble.show_message("O canteiro da praça ficou lindo!", 3.2)
			return
		if bool(ws.call(&"get_fact", &"fam_c_bruno_left_for_shift", false)) and character_id == &"npc_c_1":
			_speech_bubble.show_message("A casa ficou tão quieta sem o Bruno...", 3.2)
			return

	var lines: Array = AMBIENT_LINES.get(character_id, []) as Array
	if lines.is_empty():
		return
	var text: String = str(lines[_rng.randi_range(0, lines.size() - 1)])
	_speech_bubble.show_message(text, 3.0)


func _play_anim(moving: bool) -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	var anim_name := StringName(("walk_" if moving else "idle_") + _facing_dir)
	if anim_sprite.sprite_frames.has_animation(anim_name) and anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)


func _dir_to_name(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "left" if dir.x < 0.0 else "right"
	return "up" if dir.y < 0.0 else "down"


func _on_interacted(actor: Node) -> void:
	if actor is Node2D:
		var look: Vector2 = (actor as Node2D).global_position - global_position
		if look.length() > 0.1:
			_facing_dir = _dir_to_name(look.normalized())
			_play_anim(false)
	_is_wandering = false
	velocity = Vector2.ZERO

	if _character_data == null:
		apply_character_data()
	if _character_data == null or _character_data.dialogue_id == &"":
		return
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(
			&"dialogue_requested",
			_character_data.dialogue_id,
			dialogue_start_node,
			{"npc_id": character_id}
		)
