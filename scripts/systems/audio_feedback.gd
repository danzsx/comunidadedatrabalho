class_name AudioFeedback
extends Node
## Lightweight event-driven SFX player for UI, notebook, projects, and dialogue.

var _player: AudioStreamPlayer = null
var _sfx_interact: AudioStream = null
var _sfx_notebook: AudioStream = null
var _sfx_project: AudioStream = null
var _sfx_save: AudioStream = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -8.0
	add_child(_player)

	_sfx_interact = load("res://assets/audio/sfx_interact.wav") as AudioStream
	_sfx_notebook = load("res://assets/audio/sfx_notebook.wav") as AudioStream
	_sfx_project = load("res://assets/audio/sfx_project.wav") as AudioStream
	_sfx_save = load("res://assets/audio/sfx_save.wav") as AudioStream

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		_safe_connect(bus, &"dialogue_requested", _on_dialogue_requested)
		_safe_connect(bus, &"household_record_updated", _on_notebook_updated)
		_safe_connect(bus, &"project_stage_changed", _on_project_changed)


func play_save_chime() -> void:
	_play(_sfx_save)


func _on_dialogue_requested(_dialogue_id: StringName, _start_node: String, _ctx: Dictionary) -> void:
	_play(_sfx_interact)


func _on_notebook_updated(_family_id: StringName) -> void:
	_play(_sfx_notebook)


func _on_project_changed(_project_id: StringName, _stage: int) -> void:
	_play(_sfx_project)


func _play(stream: AudioStream) -> void:
	if _player == null or stream == null:
		return
	_player.stream = stream
	_player.play()


func _safe_connect(bus: Node, sig: StringName, cb: Callable) -> void:
	if not bus.is_connected(sig, cb):
		var err: Error = bus.connect(sig, cb)
		if err != OK:
			push_warning("AudioFeedback failed to connect %s" % String(sig))
