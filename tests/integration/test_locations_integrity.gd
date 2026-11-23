extends GutTest

const REQUIRED_LOCATIONS: Array[StringName] = [
	&"loc_bairro_praca",
	&"loc_casa_alex",
	&"loc_ubs",
	&"loc_casa_fam_a",
	&"loc_casa_fam_b",
	&"loc_casa_fam_c",
]


func test_required_locations_registered_and_valid() -> void:
	DataRegistry.reload_all()
	for loc_id: StringName in REQUIRED_LOCATIONS:
		assert_true(DataRegistry.has_location(loc_id), "Location '%s' should be registered." % String(loc_id))

	var errors: Array[String] = DataRegistry.validate_integrity()
	assert_eq(errors.size(), 0, "DataRegistry integrity errors: %s" % str(errors))


func test_all_scenes_have_required_layers_and_valid_portals() -> void:
	DataRegistry.reload_all()
	var scenes_by_id: Dictionary = {}

	for loc_id: StringName in DataRegistry.get_all_location_ids():
		var loc: LocationData = DataRegistry.get_location(loc_id)
		var packed: PackedScene = load(loc.scene_path) as PackedScene
		assert_not_null(packed, "Scene should load: %s" % loc.scene_path)
		var instance: Node = packed.instantiate()
		add_child_autofree(instance)
		scenes_by_id[loc_id] = instance

		assert_not_null(instance.get_node_or_null("SpawnPoints"), "%s missing SpawnPoints" % String(loc_id))
		assert_not_null(instance.get_node_or_null("CameraBounds"), "%s missing CameraBounds" % String(loc_id))
		assert_not_null(instance.get_node_or_null("EntitiesYSort"), "%s missing EntitiesYSort" % String(loc_id))
		assert_not_null(instance.get_node_or_null("LightingRoot/CanvasModulate"), "%s missing LightingRoot/CanvasModulate" % String(loc_id))

	for loc_id: Variant in scenes_by_id.keys():
		var scene_root: Node = scenes_by_id[loc_id] as Node
		var portals_node: Node = scene_root.get_node_or_null("Portals")
		assert_not_null(portals_node, "%s missing Portals container" % str(loc_id))
		for child: Node in portals_node.get_children():
			assert_true(child is ScenePortal, "Child in Portals must be ScenePortal")
			var portal: ScenePortal = child as ScenePortal
			assert_true(
				scenes_by_id.has(portal.target_location_id),
				"Portal '%s' in '%s' targets unknown location '%s'" % [portal.name, str(loc_id), String(portal.target_location_id)]
			)
			var target_scene: Node = scenes_by_id[portal.target_location_id] as Node
			var target_spawn: Node = target_scene.get_node_or_null("SpawnPoints/" + String(portal.target_spawn_id))
			assert_not_null(
				target_spawn,
				"Portal '%s' in '%s' targets missing spawn '%s' in '%s'" % [portal.name, str(loc_id), String(portal.target_spawn_id), String(portal.target_location_id)]
			)


func test_environment_controller_period_presets_are_distinct() -> void:
	var c_morning: Color = EnvironmentController.get_period_color(0, false)
	var c_afternoon: Color = EnvironmentController.get_period_color(1, false)
	var c_night: Color = EnvironmentController.get_period_color(2, false)
	var c_late: Color = EnvironmentController.get_period_color(3, false)
	assert_ne(c_morning, c_afternoon)
	assert_ne(c_afternoon, c_night)
	assert_ne(c_night, c_late)


func test_scene_router_immediate_transition() -> void:
	var container := Node.new()
	add_child_autofree(container)
	var player := Node2D.new()
	add_child_autofree(player)

	SceneRouter.register_host(container, null, player)
	var err: Error = SceneRouter.change_location_immediate(&"loc_ubs", &"spawn_door")
	assert_eq(err, OK)
	assert_eq(WorldState.current_location_id, &"loc_ubs")
	assert_eq(WorldState.current_spawn_id, &"spawn_door")
