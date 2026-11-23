extends Node
## Manages map/interior transitions, spawn placement, camera bounds, and dynamic NPC spawning.

signal location_loaded(location_id: StringName)

const FADE_DURATION: float = 0.22
const NPC_SCENE_PATH: String = "res://scenes/npcs/NPCBase.tscn"

var is_transitioning: bool = false

var _scene_container: Node = null
var _fade_rect: ColorRect = null
var _player: Node2D = null
var _active_scene: Node = null
var _npc_packed: PackedScene = null


func _ready() -> void:
	if not EventBus.scene_change_requested.is_connected(_on_scene_change_requested):
		var err1: Error = EventBus.scene_change_requested.connect(_on_scene_change_requested)
		if err1 != OK:
			push_warning("SceneRouter failed to connect scene_change_requested.")
	if not EventBus.period_changed.is_connected(_on_period_changed):
		var err2: Error = EventBus.period_changed.connect(_on_period_changed)
		if err2 != OK:
			push_warning("SceneRouter failed to connect period_changed.")


func register_host(scene_container: Node, fade_rect: ColorRect, player: Node2D) -> void:
	_scene_container = scene_container
	_fade_rect = fade_rect
	_player = player
	if _fade_rect != null:
		_fade_rect.color.a = 0.0
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_scene_change_requested(location_id: StringName, spawn_id: StringName) -> void:
	if is_transitioning:
		return
	var err: Error = await change_location(location_id, spawn_id)
	if err != OK:
		push_error("SceneRouter failed to change location to '%s' (err=%d)" % [String(location_id), err])


func _on_period_changed(_new_day: int, _new_period: int) -> void:
	if _active_scene != null and is_instance_valid(_active_scene):
		_sync_npcs_for_scene(_active_scene, WorldState.current_location_id)


func change_location(location_id: StringName, spawn_id: StringName) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not DataRegistry.has_location(location_id):
		return ERR_DOES_NOT_EXIST

	is_transitioning = true
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", true)

	if _fade_rect != null and is_inside_tree():
		var fade_out: Tween = create_tween()
		fade_out.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
		await fade_out.finished

	var err: Error = _swap_scene_sync(location_id, spawn_id)

	if _fade_rect != null and is_inside_tree():
		var fade_in: Tween = create_tween()
		fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
		await fade_in.finished

	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", false)

	if is_inside_tree():
		await get_tree().physics_frame
		await get_tree().physics_frame

	is_transitioning = false
	if err == OK:
		location_loaded.emit(location_id)
	return err


func change_location_immediate(location_id: StringName, spawn_id: StringName) -> Error:
	var err: Error = _swap_scene_sync(location_id, spawn_id)
	if err == OK:
		location_loaded.emit(location_id)
	return err


func _swap_scene_sync(location_id: StringName, spawn_id: StringName) -> Error:
	if _scene_container == null:
		return ERR_UNCONFIGURED
	var loc: LocationData = DataRegistry.get_location(location_id)
	if loc == null:
		return ERR_DOES_NOT_EXIST
	var packed: PackedScene = load(loc.scene_path) as PackedScene
	if packed == null:
		return ERR_CANT_OPEN

	if _active_scene != null:
		# Detach player before freeing previous scene so Alex is preserved.
		if _player != null and _player.get_parent() != null and _active_scene.is_ancestor_of(_player):
			_player.get_parent().remove_child(_player)
		_active_scene.queue_free()
		_active_scene = null

	var next_scene: Node = packed.instantiate()
	_scene_container.add_child(next_scene)
	_active_scene = next_scene

	_place_player_at_spawn(next_scene, spawn_id)
	_apply_camera_bounds(next_scene)

	WorldState.current_location_id = location_id
	WorldState.current_spawn_id = spawn_id
	if _player != null:
		WorldState.player_position = _player.global_position

	_sync_npcs_for_scene(next_scene, location_id)
	return OK


func _sync_npcs_for_scene(scene_root: Node, location_id: StringName) -> void:
	var y_sort: Node = scene_root.get_node_or_null("EntitiesYSort")
	if y_sort == null:
		return

	# Remove previously spawned dynamic NPCs in this scene.
	for child: Node in y_sort.get_children():
		if child.is_in_group(&"npcs"):
			child.queue_free()

	if _npc_packed == null:
		_npc_packed = load(NPC_SCENE_PATH) as PackedScene
	if _npc_packed == null:
		return

	var scheduled: Array[Dictionary] = RoutineResolver.get_npcs_for_location(location_id, WorldState)
	var spots_root: Node = scene_root.get_node_or_null("NPCSpots")
	var fallback_index: int = 0

	for entry: Dictionary in scheduled:
		var npc_id: StringName = entry["npc_id"] as StringName
		var marker_name: StringName = entry["marker_name"] as StringName
		var npc: Node2D = _npc_packed.instantiate() as Node2D
		npc.name = "NPC_" + String(npc_id)
		npc.set("character_id", npc_id)

		var pos: Vector2 = Vector2(128.0 + float(fallback_index * 24), 96.0)
		if spots_root != null:
			var spot: Node2D = spots_root.get_node_or_null(NodePath(String(marker_name))) as Node2D
			if spot == null and spots_root.get_child_count() > 0:
				spot = spots_root.get_child(fallback_index % spots_root.get_child_count()) as Node2D
			if spot != null:
				pos = spot.global_position

		npc.position = pos
		y_sort.add_child(npc)
		fallback_index += 1


func _place_player_at_spawn(scene_root: Node, spawn_id: StringName) -> void:
	if _player == null:
		return
	var target_pos: Vector2 = Vector2.ZERO
	var spawn_points: Node = scene_root.get_node_or_null("SpawnPoints")
	if spawn_points != null:
		var marker: Node2D = spawn_points.get_node_or_null(NodePath(String(spawn_id))) as Node2D
		if marker == null and spawn_points.get_child_count() > 0:
			marker = spawn_points.get_child(0) as Node2D
		if marker != null:
			target_pos = marker.global_position

	var y_sort_root: Node = scene_root.get_node_or_null("EntitiesYSort")
	if y_sort_root != null:
		if _player.get_parent() != null:
			_player.get_parent().remove_child(_player)
		y_sort_root.add_child(_player)
	_player.global_position = target_pos


func _apply_camera_bounds(scene_root: Node) -> void:
	if _player == null:
		return
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var bounds: ReferenceRect = scene_root.get_node_or_null("CameraBounds") as ReferenceRect
	if bounds != null:
		var top_left: Vector2 = bounds.global_position
		var bottom_right: Vector2 = top_left + bounds.size
		cam.limit_left = int(top_left.x)
		cam.limit_top = int(top_left.y)
		cam.limit_right = int(bottom_right.x)
		cam.limit_bottom = int(bottom_right.y)
	else:
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
