class_name InspectionSite
extends Interactable
## World interactable yard/lot site that launches the Environmental Inspection minigame.

@export var zone_id: StringName = &"zone_quintal_fam_a"
@export var is_terreno: bool = false

var _sprite: Sprite2D = null
var _pulse_time: float = 0.0
var _status: String = "pending"


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "SiteSprite"
	add_child(_sprite)

	if not interacted.is_connected(_on_interacted):
		var err1: Error = interacted.connect(_on_interacted)
		if err1 != OK:
			push_warning("InspectionSite failed to connect interacted.")

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"environmental_state_changed", _on_env_state_changed):
		var err2: Error = bus.connect(&"environmental_state_changed", _on_env_state_changed)
		if err2 != OK:
			push_warning("InspectionSite failed to connect environmental_state_changed.")

	refresh_visual()


func _process(delta: float) -> void:
	if _status == "clean":
		return
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if _status == "clean":
		return
	var bob: float = sin(_pulse_time * 3.5) * 1.5
	var badge_pos: Vector2 = Vector2(0.0, -22.0 + bob)
	if _status == "infested":
		draw_circle(badge_pos, 4.5, Color(0.84, 0.22, 0.18, 0.92))
		draw_arc(badge_pos, 4.5, 0.0, TAU, 12, Color(1.0, 0.92, 0.78, 0.95), 1.0)
		draw_line(badge_pos + Vector2(0.0, -2.0), badge_pos + Vector2(0.0, 0.5), Color(1.0, 1.0, 1.0, 1.0), 1.2)
		draw_rect(Rect2(badge_pos + Vector2(-0.6, 1.4), Vector2(1.2, 1.2)), Color(1.0, 1.0, 1.0, 1.0))
	else:
		# Pending inspection subtle gold magnifying dot
		draw_circle(badge_pos, 3.8, Color(0.86, 0.68, 0.28, 0.85))
		draw_arc(badge_pos, 3.8, 0.0, TAU, 12, Color(0.24, 0.16, 0.10, 0.9), 1.0)


func refresh_visual() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var z_state: Dictionary = EnvironmentalInspectionService.get_zone_state(ws, zone_id)
	var z_def: Dictionary = EnvironmentalInspectionService.get_zone_def(zone_id)
	_status = str(z_state.get("status", "pending"))
	var title: String = str(z_def.get("title", "Área do bairro"))

	match _status:
		"infested":
			prompt_text = "Reinspecionar %s (Foco ativo!)" % title
		"clean":
			prompt_text = "Verificar %s (Limpo)" % title
		_:
			prompt_text = "Inspecionar %s" % title

	var tex_path: String = ""
	if is_terreno:
		tex_path = "res://assets/objects/inspection_terreno_clean.png" if _status == "clean" else "res://assets/objects/inspection_terreno_pending.png"
	else:
		tex_path = "res://assets/objects/inspection_quintal_clean.png" if _status == "clean" else "res://assets/objects/inspection_quintal_pending.png"

	if _sprite != null and ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path) as Texture2D
	queue_redraw()


func _on_env_state_changed(changed_zone_id: StringName, _new_status: String) -> void:
	if changed_zone_id == zone_id:
		refresh_visual()


func _on_interacted(_actor: Node) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(&"environmental_inspection_requested", zone_id)
