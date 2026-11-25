class_name GardenHotbarUI
extends CanvasLayer
## Reference-inspired wooden pixel-art tool hotbar shown only inside HortaComunitaria.

const TOOL_NAMES: Array[String] = [
	"Regador",
	"Enxada de Mão",
	"Sementes",
	"Composto Orgânico",
	"Cesta de Colheita",
	"Lupa da Horta",
]

const TOOL_ICONS: Array[String] = [
	"res://assets/objects/garden/icons/icon_watering_can.png",
	"res://assets/objects/garden/icons/icon_hoe.png",
	"res://assets/objects/garden/icons/icon_seed_bag.png",
	"res://assets/objects/garden/icons/icon_compost.png",
	"res://assets/objects/garden/icons/icon_basket.png",
	"res://assets/objects/garden/icons/icon_magnifier.png",
]

@onready var status_pill_label: Label = $Root/ToolLabelPanel/Margin/ToolLabel
@onready var slots_hbox: HBoxContainer = $Root/HotbarPanel/Margin/SlotsHBox

var _player: Node = null
var _dialogue_service: Node = null
var _selected_tool: int = 0
var _selected_seed_index: int = 0
var _available_seeds: Array[StringName] = []
var _slot_buttons: Array[Button] = []
var _slot_badges: Array[Label] = []
var _style_normal: StyleBoxFlat = null
var _style_selected: StyleBoxFlat = null


func _ready() -> void:
	add_to_group(&"garden_hotbar_ui")
	visible = false
	_build_slot_styles()
	_build_slots()

	if not SceneRouter.location_loaded.is_connected(_on_location_loaded):
		var err1: Error = SceneRouter.location_loaded.connect(_on_location_loaded)
		if err1 != OK:
			push_warning("GardenHotbarUI failed to connect location_loaded.")
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"garden_state_changed", _on_garden_state_changed):
		var err2: Error = bus.connect(&"garden_state_changed", _on_garden_state_changed)
		if err2 != OK:
			push_warning("GardenHotbarUI failed to connect garden_state_changed.")
	refresh()


func bind_host(player: Node, dialogue_service: Node) -> void:
	_player = player
	_dialogue_service = dialogue_service


func get_selected_tool() -> int:
	return _selected_tool


func get_selected_seed_crop() -> StringName:
	_refresh_seed_list()
	if _available_seeds.is_empty():
		return &""
	_selected_seed_index = posmod(_selected_seed_index, _available_seeds.size())
	return _available_seeds[_selected_seed_index]


func _on_location_loaded(_location_id: StringName) -> void:
	refresh()


func _on_garden_state_changed() -> void:
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _dialogue_service != null and bool(_dialogue_service.get("is_active")):
		return
	if _player != null and _player.has_method(&"is_movement_locked") and bool(_player.call(&"is_movement_locked")):
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode >= KEY_1 and ke.keycode <= KEY_6:
				var idx: int = int(ke.keycode - KEY_1)
				if idx == 2 and _selected_tool == 2:
					cycle_seed()
				else:
					select_tool(idx)
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_Q:
				cycle_seed()
				select_tool(2)
				get_viewport().set_input_as_handled()


func select_tool(index: int) -> void:
	_selected_tool = clampi(index, 0, TOOL_NAMES.size() - 1)
	refresh()


func cycle_seed() -> void:
	_refresh_seed_list()
	if _available_seeds.size() > 1:
		_selected_seed_index = (_selected_seed_index + 1) % _available_seeds.size()
	refresh()


func refresh() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var in_garden: bool = ws != null and (ws.get("current_location_id") as StringName) == &"loc_horta_comunitaria"
	visible = in_garden
	if not in_garden:
		return

	_refresh_seed_list()
	var gs: Dictionary = ws.get("garden_state") as Dictionary
	var water_cur: int = int(gs.get(&"watering_can_charges", CommunityGardenService.INITIAL_WATER_MAX))
	var water_max: int = int(gs.get(&"watering_can_max", CommunityGardenService.INITIAL_WATER_MAX))
	var compost_cnt: int = InventorySystem.get_count(ws, &"item_composto_organico")

	var active_crop: StringName = get_selected_seed_crop()
	var seed_cnt: int = 0
	var seed_label: String = "Sem sementes"
	if active_crop != &"":
		var crop: CropData = DataRegistry.get_crop(active_crop)
		if crop != null:
			seed_cnt = InventorySystem.get_count(ws, crop.seed_item_id)
			seed_label = "%s (x%d)" % [crop.display_name, seed_cnt]

	for i: int in range(_slot_buttons.size()):
		var btn: Button = _slot_buttons[i]
		var st_box: StyleBoxFlat = _style_selected if i == _selected_tool else _style_normal
		btn.add_theme_stylebox_override(&"normal", st_box)
		btn.add_theme_stylebox_override(&"hover", _style_selected)
		btn.add_theme_stylebox_override(&"focus", st_box)

		var badge: Label = _slot_badges[i]
		if i == 0:
			badge.text = "%d/%d" % [water_cur, water_max]
		elif i == 2:
			badge.text = "x%d" % seed_cnt
		elif i == 3:
			badge.text = "x%d" % compost_cnt
		else:
			badge.text = str(i + 1)

	if status_pill_label != null:
		if _selected_tool == 2:
			status_pill_label.text = "[3] Sementes: %s  ·  [Q] Trocar" % seed_label
		elif _selected_tool == 0:
			status_pill_label.text = "[1] Regador (%d/%d água)  ·  [E] Usar no canteiro" % [water_cur, water_max]
		else:
			status_pill_label.text = "[%d] %s  ·  [E] Usar no canteiro" % [_selected_tool + 1, TOOL_NAMES[_selected_tool]]


func _refresh_seed_list() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var reg: Node = get_node_or_null("/root/DataRegistry")
	_available_seeds = CommunityGardenService.get_available_seed_crops(ws, reg)


func _build_slots() -> void:
	if slots_hbox == null:
		return
	for child: Node in slots_hbox.get_children():
		child.queue_free()
	_slot_buttons.clear()
	_slot_badges.clear()

	for i: int in range(TOOL_NAMES.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(30.0, 28.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = "[%d] %s" % [i + 1, TOOL_NAMES[i]]

		var icon_rect := TextureRect.new()
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.anchors_preset = Control.PRESET_CENTER
		icon_rect.offset_left = -8.0
		icon_rect.offset_top = -9.0
		icon_rect.offset_right = 8.0
		icon_rect.offset_bottom = 7.0
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(TOOL_ICONS[i]):
			icon_rect.texture = load(TOOL_ICONS[i]) as Texture2D
		btn.add_child(icon_rect)

		var badge := Label.new()
		badge.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		badge.offset_left = -26.0
		badge.offset_top = -11.0
		badge.offset_right = -2.0
		badge.offset_bottom = -1.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override(&"font_size", 7)
		badge.add_theme_color_override(&"font_color", Color(0.98, 0.96, 0.88, 1.0))
		badge.add_theme_color_override(&"font_shadow_color", Color(0.14, 0.08, 0.04, 0.95))
		badge.add_theme_constant_override(&"shadow_offset_x", 1)
		badge.add_theme_constant_override(&"shadow_offset_y", 1)
		btn.add_child(badge)

		var idx: int = i
		var err: Error = btn.pressed.connect(func() -> void:
			if idx == 2 and _selected_tool == 2:
				cycle_seed()
			else:
				select_tool(idx)
		)
		if err != OK:
			push_warning("GardenHotbarUI failed to connect slot button.")

		slots_hbox.add_child(btn)
		_slot_buttons.append(btn)
		_slot_badges.append(badge)


func _build_slot_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.76, 0.58, 0.36, 0.96)
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 1
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 1
	_style_normal.border_color = Color(0.36, 0.24, 0.14, 1.0)
	_style_normal.corner_radius_top_left = 3
	_style_normal.corner_radius_top_right = 3
	_style_normal.corner_radius_bottom_right = 3
	_style_normal.corner_radius_bottom_left = 3

	_style_selected = _style_normal.duplicate() as StyleBoxFlat
	_style_selected.bg_color = Color(0.92, 0.76, 0.44, 1.0)
	_style_selected.border_width_left = 2
	_style_selected.border_width_top = 2
	_style_selected.border_width_right = 2
	_style_selected.border_width_bottom = 2
	_style_selected.border_color = Color(1.0, 0.94, 0.64, 1.0)
