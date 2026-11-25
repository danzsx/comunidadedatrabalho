class_name EnvironmentalInspectionCanvas
extends Control
## Interactive pixel-art observation canvas for the Environmental Inspection minigame.

signal item_selected(item_index: int)

var environment_type: String = "quintal"
var items: Array[Dictionary] = []
var selected_index: int = -1
var hovered_index: int = -1

var _anim_time: float = 0.0
var _mouse_pos: Vector2 = Vector2(-100.0, -100.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func setup_scene(env_type: String, scene_items: Array[Dictionary]) -> void:
	environment_type = env_type
	items = scene_items
	selected_index = -1
	hovered_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_anim_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_mouse_pos = mm.position
		hovered_index = _hit_test(_mouse_pos)
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var idx: int = _hit_test(mb.position)
			if idx >= 0:
				selected_index = idx
				item_selected.emit(idx)
				queue_redraw()
				accept_event()


func _hit_test(pos: Vector2) -> int:
	for i: int in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		var center: Vector2 = _item_screen_pos(item)
		var radius: float = float(item.get("radius", 20.0))
		if pos.distance_to(center) <= radius:
			return i
	return -1


func _item_screen_pos(item: Dictionary) -> Vector2:
	var norm_pos: Vector2 = item.get("pos", Vector2(0.5, 0.5)) as Vector2
	return Vector2(roundf(norm_pos.x * size.x), roundf(norm_pos.y * size.y))


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 2.0 or h <= 2.0:
		return

	_draw_backdrop(w, h)

	for i: int in range(items.size()):
		var item: Dictionary = items[i]
		var center: Vector2 = _item_screen_pos(item)
		var state: String = str(item.get("state", "uninspected"))
		var is_selected: bool = (i == selected_index)
		var is_hovered: bool = (i == hovered_index)
		_draw_item(item, center, state, is_selected, is_hovered)

	# Draw subtle magnifying-glass reticle on hovered or selected object.
	if hovered_index >= 0 and hovered_index < items.size():
		var h_center: Vector2 = _item_screen_pos(items[hovered_index])
		draw_arc(h_center, 18.0, 0.0, TAU, 24, Color(1.0, 0.94, 0.68, 0.75), 1.0)


func _draw_backdrop(w: float, h: float) -> void:
	var grass_base: Color = Color(0.42, 0.56, 0.28, 1.0)
	var dirt_patch: Color = Color(0.56, 0.44, 0.31, 1.0)
	var wall_color: Color = Color(0.76, 0.68, 0.56, 1.0)
	var wall_trim: Color = Color(0.48, 0.36, 0.26, 1.0)

	if environment_type == "terreno":
		grass_base = Color(0.46, 0.52, 0.26, 1.0)
		dirt_patch = Color(0.52, 0.40, 0.28, 1.0)
		wall_color = Color(0.54, 0.44, 0.34, 1.0)
	elif environment_type == "quintal_fundos":
		grass_base = Color(0.38, 0.52, 0.30, 1.0)
		dirt_patch = Color(0.60, 0.54, 0.44, 1.0)
		wall_color = Color(0.80, 0.73, 0.62, 1.0)

	# Base ground
	draw_rect(Rect2(0.0, 0.0, w, h), grass_base)

	# Top wall / wooden fence strip
	draw_rect(Rect2(0.0, 0.0, w, 26.0), wall_color)
	draw_rect(Rect2(0.0, 24.0, w, 3.0), wall_trim)
	if environment_type == "terreno":
		# Wooden fence posts
		var x: float = 12.0
		while x < w:
			draw_rect(Rect2(x, 4.0, 6.0, 22.0), Color(0.42, 0.30, 0.20, 1.0))
			x += 34.0
	else:
		# Subtle brick/plaster texture lines
		draw_line(Vector2(0.0, 12.0), Vector2(w, 12.0), Color(0.66, 0.58, 0.48, 0.5), 1.0)

	# Organic dirt path / yard floor
	draw_rect(Rect2(18.0, 42.0, w - 36.0, h - 58.0), dirt_patch)
	draw_rect(Rect2(24.0, 48.0, w - 48.0, h - 70.0), dirt_patch.lightened(0.06))

	# Small grass tufts & pebbles for texture
	var tufts: Array[Vector2] = [
		Vector2(14.0, 38.0), Vector2(w - 16.0, 44.0), Vector2(12.0, h - 18.0),
		Vector2(w - 20.0, h - 22.0), Vector2(w * 0.5, 34.0), Vector2(w * 0.32, h - 14.0),
	]
	for t: Vector2 in tufts:
		draw_line(t, t + Vector2(-2.0, -4.0), Color(0.28, 0.42, 0.18, 1.0), 1.0)
		draw_line(t, t + Vector2(2.0, -3.0), Color(0.52, 0.68, 0.32, 1.0), 1.0)


func _draw_item(item: Dictionary, c: Vector2, state: String, is_selected: bool, is_hovered: bool) -> void:
	var kind: String = str(item.get("kind", "bucket_open"))
	var is_foco: bool = bool(item.get("is_foco", false))
	var cleaned: bool = (state == "cleaned")
	var show_water: bool = is_foco and not cleaned

	var outline: Color = Color(0.17, 0.12, 0.09, 1.0)
	var water_col: Color = Color(0.32, 0.52, 0.47, 1.0)
	var water_shine: Color = Color(0.62, 0.84, 0.78, 0.85)
	var shadow_col: Color = Color(0.10, 0.08, 0.06, 0.32)

	# Selection / hover glow ring underneath
	if is_selected:
		draw_circle(c, 20.0, Color(1.0, 0.88, 0.46, 0.28))
		draw_arc(c, 20.0, 0.0, TAU, 24, Color(0.98, 0.82, 0.34, 0.95), 1.5)
	elif is_hovered:
		draw_circle(c, 18.0, Color(1.0, 0.96, 0.78, 0.16))

	# Ground shadow
	draw_circle(c + Vector2(1.0, 4.0), 13.0, shadow_col)

	match kind:
		"tire", "tire_covered":
			draw_circle(c, 13.0, outline)
			draw_circle(c, 11.5, Color(0.22, 0.23, 0.26, 1.0))
			draw_circle(c, 9.0, Color(0.30, 0.31, 0.35, 1.0))
			if show_water:
				draw_circle(c, 6.5, water_col)
				_draw_water_details(c, 4.5, water_shine)
			elif kind == "tire_covered" or cleaned:
				draw_rect(Rect2(c.x - 10.0, c.y - 4.0, 20.0, 8.0), Color(0.58, 0.42, 0.26, 1.0))
				draw_rect(Rect2(c.x - 10.0, c.y - 4.0, 20.0, 8.0), outline, false, 1.0)
			else:
				draw_circle(c, 6.0, Color(0.40, 0.32, 0.24, 1.0))

		"saucer_water", "saucer_sand":
			draw_circle(c + Vector2(0.0, 5.0), 11.0, outline)
			draw_circle(c + Vector2(0.0, 5.0), 9.5, Color(0.56, 0.30, 0.20, 1.0))
			if show_water:
				draw_circle(c + Vector2(0.0, 5.0), 8.0, water_col)
				_draw_water_details(c + Vector2(0.0, 5.0), 5.0, water_shine)
			else:
				draw_circle(c + Vector2(0.0, 5.0), 8.0, Color(0.84, 0.74, 0.54, 1.0))
			# Terracotta pot + plant
			draw_rect(Rect2(c.x - 5.0, c.y - 5.0, 10.0, 10.0), Color(0.72, 0.40, 0.26, 1.0))
			draw_rect(Rect2(c.x - 5.0, c.y - 5.0, 10.0, 10.0), outline, false, 1.0)
			draw_circle(c + Vector2(-4.0, -8.0), 4.0, Color(0.32, 0.56, 0.24, 1.0))
			draw_circle(c + Vector2(4.0, -9.0), 4.5, Color(0.42, 0.66, 0.30, 1.0))

		"bucket_open", "bucket_inverted":
			if kind == "bucket_inverted" or cleaned:
				# Overturned safe bucket
				draw_rect(Rect2(c.x - 8.0, c.y - 5.0, 16.0, 12.0), Color(0.24, 0.40, 0.56, 1.0))
				draw_rect(Rect2(c.x - 8.0, c.y - 5.0, 16.0, 12.0), outline, false, 1.0)
				draw_rect(Rect2(c.x - 6.0, c.y - 7.0, 12.0, 4.0), Color(0.44, 0.62, 0.78, 1.0))
			else:
				draw_rect(Rect2(c.x - 8.0, c.y - 4.0, 16.0, 12.0), Color(0.30, 0.50, 0.68, 1.0))
				draw_rect(Rect2(c.x - 8.0, c.y - 4.0, 16.0, 12.0), outline, false, 1.0)
				draw_circle(c + Vector2(0.0, -4.0), 7.5, outline)
				draw_circle(c + Vector2(0.0, -4.0), 6.5, water_col)
				_draw_water_details(c + Vector2(0.0, -4.0), 4.0, water_shine)

		"bottle_up", "bottle_down":
			if kind == "bottle_down" or cleaned:
				# Bottle lying/inverted safely
				draw_rect(Rect2(c.x - 9.0, c.y - 3.0, 14.0, 6.0), Color(0.36, 0.62, 0.42, 1.0))
				draw_rect(Rect2(c.x - 9.0, c.y - 3.0, 14.0, 6.0), outline, false, 1.0)
				draw_rect(Rect2(c.x + 5.0, c.y - 1.5, 4.0, 3.0), Color(0.46, 0.72, 0.52, 1.0))
			else:
				draw_rect(Rect2(c.x - 4.0, c.y - 4.0, 8.0, 12.0), Color(0.36, 0.62, 0.42, 1.0))
				draw_rect(Rect2(c.x - 4.0, c.y - 4.0, 8.0, 12.0), outline, false, 1.0)
				draw_rect(Rect2(c.x - 2.0, c.y - 10.0, 4.0, 6.0), water_col)
				draw_rect(Rect2(c.x - 2.0, c.y - 10.0, 4.0, 6.0), outline, false, 1.0)
				_draw_water_details(c + Vector2(0.0, -7.0), 1.5, water_shine)

		"tarp_puddle":
			if cleaned:
				draw_rect(Rect2(c.x - 11.0, c.y - 4.0, 22.0, 8.0), Color(0.32, 0.44, 0.62, 1.0))
				draw_rect(Rect2(c.x - 11.0, c.y - 4.0, 22.0, 8.0), outline, false, 1.0)
			else:
				var pts: PackedVector2Array = PackedVector2Array([
					c + Vector2(-14.0, -8.0),
					c + Vector2(13.0, -10.0),
					c + Vector2(15.0, 8.0),
					c + Vector2(-12.0, 10.0),
				])
				draw_colored_polygon(pts, Color(0.32, 0.44, 0.62, 1.0))
				draw_polyline(pts, outline, 1.0)
				draw_circle(c, 7.0, water_col)
				_draw_water_details(c, 4.5, water_shine)

		"barrel_open", "barrel_sealed":
			draw_rect(Rect2(c.x - 9.0, c.y - 7.0, 18.0, 16.0), Color(0.36, 0.54, 0.72, 1.0))
			draw_rect(Rect2(c.x - 9.0, c.y - 7.0, 18.0, 16.0), outline, false, 1.0)
			if show_water:
				draw_rect(Rect2(c.x - 8.0, c.y - 6.0, 16.0, 5.0), water_col)
				_draw_water_details(c + Vector2(0.0, -4.0), 4.0, water_shine)
				# Crooked wooden lid
				draw_rect(Rect2(c.x - 2.0, c.y - 10.0, 12.0, 4.0), Color(0.58, 0.42, 0.26, 1.0))
			else:
				# Sealed cover + mesh
				draw_rect(Rect2(c.x - 10.0, c.y - 9.0, 20.0, 4.0), Color(0.24, 0.36, 0.48, 1.0))
				draw_rect(Rect2(c.x - 10.0, c.y - 9.0, 20.0, 4.0), outline, false, 1.0)

		"gutter_clogged":
			draw_rect(Rect2(c.x - 16.0, c.y - 4.0, 32.0, 8.0), Color(0.56, 0.58, 0.62, 1.0))
			draw_rect(Rect2(c.x - 16.0, c.y - 4.0, 32.0, 8.0), outline, false, 1.0)
			if show_water:
				draw_rect(Rect2(c.x - 14.0, c.y - 2.0, 28.0, 4.0), water_col)
				draw_circle(c + Vector2(8.0, 0.0), 3.0, Color(0.46, 0.34, 0.18, 1.0))
				_draw_water_details(c + Vector2(-4.0, 0.0), 3.0, water_shine)

		"pet_bowl_old", "pet_bowl_clean":
			draw_circle(c, 9.0, outline)
			draw_circle(c, 8.0, Color(0.76, 0.44, 0.30, 1.0))
			if show_water:
				draw_circle(c, 6.0, water_col)
				_draw_water_details(c, 3.5, water_shine)
			else:
				draw_circle(c, 6.0, Color(0.62, 0.84, 0.94, 1.0))

		"can_open":
			if cleaned:
				draw_rect(Rect2(c.x - 6.0, c.y - 2.0, 12.0, 5.0), Color(0.64, 0.52, 0.44, 1.0))
				draw_rect(Rect2(c.x - 6.0, c.y - 2.0, 12.0, 5.0), outline, false, 1.0)
			else:
				draw_rect(Rect2(c.x - 5.0, c.y - 5.0, 10.0, 10.0), Color(0.68, 0.44, 0.32, 1.0))
				draw_rect(Rect2(c.x - 5.0, c.y - 5.0, 10.0, 10.0), outline, false, 1.0)
				draw_circle(c + Vector2(0.0, -4.0), 4.0, water_col)
				_draw_water_details(c + Vector2(0.0, -4.0), 2.0, water_shine)

		"watering_can_dry":
			draw_rect(Rect2(c.x - 6.0, c.y - 4.0, 12.0, 10.0), Color(0.32, 0.58, 0.44, 1.0))
			draw_rect(Rect2(c.x - 6.0, c.y - 4.0, 12.0, 10.0), outline, false, 1.0)
			draw_line(c + Vector2(6.0, 2.0), c + Vector2(12.0, -4.0), Color(0.32, 0.58, 0.44, 1.0), 2.0)

		"bricks_dry":
			draw_rect(Rect2(c.x - 10.0, c.y - 4.0, 10.0, 5.0), Color(0.72, 0.38, 0.26, 1.0))
			draw_rect(Rect2(c.x - 10.0, c.y - 4.0, 10.0, 5.0), outline, false, 1.0)
			draw_rect(Rect2(c.x + 1.0, c.y - 4.0, 10.0, 5.0), Color(0.68, 0.34, 0.24, 1.0))
			draw_rect(Rect2(c.x + 1.0, c.y - 4.0, 10.0, 5.0), outline, false, 1.0)
			draw_rect(Rect2(c.x - 5.0, c.y - 9.0, 10.0, 5.0), Color(0.76, 0.42, 0.30, 1.0))
			draw_rect(Rect2(c.x - 5.0, c.y - 9.0, 10.0, 5.0), outline, false, 1.0)

	# Status badge on already resolved items
	if state == "cleaned":
		_draw_check_badge(c + Vector2(10.0, -10.0), Color(0.20, 0.64, 0.30, 1.0))
	elif state == "verified_safe":
		_draw_check_badge(c + Vector2(10.0, -10.0), Color(0.28, 0.52, 0.76, 1.0))


func _draw_water_details(center: Vector2, spread: float, shine_col: Color) -> void:
	# Subtle animated shimmer + tiny wriggling larvae dots
	var shimmer_x: float = sin(_anim_time * 3.2 + center.x) * 1.2
	draw_line(
		center + Vector2(-spread * 0.45 + shimmer_x, -spread * 0.25),
		center + Vector2(spread * 0.2 + shimmer_x, -spread * 0.25),
		shine_col,
		1.0
	)
	var larva1: Vector2 = center + Vector2(
		sin(_anim_time * 5.0 + center.y) * (spread * 0.45),
		cos(_anim_time * 4.2 + center.x) * (spread * 0.35)
	)
	draw_rect(Rect2(larva1, Vector2(1.5, 1.5)), Color(0.12, 0.10, 0.08, 0.9))


func _draw_check_badge(pos: Vector2, bg: Color) -> void:
	draw_circle(pos, 5.0, bg)
	draw_arc(pos, 5.0, 0.0, TAU, 12, Color(0.98, 0.96, 0.90, 0.95), 1.0)
	draw_line(pos + Vector2(-2.5, 0.0), pos + Vector2(-0.5, 2.0), Color(1.0, 1.0, 1.0, 1.0), 1.2)
	draw_line(pos + Vector2(-0.5, 2.0), pos + Vector2(2.8, -2.0), Color(1.0, 1.0, 1.0, 1.0), 1.2)
