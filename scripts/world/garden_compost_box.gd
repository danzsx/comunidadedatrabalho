class_name GardenCompostBox
extends Interactable
## Community compost bin unlocked at Garden Level 2, generating organic compost every 2 days.

var _sprite: Sprite2D = null


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "CompostSprite"
	add_child(_sprite)
	if not interacted.is_connected(_on_interacted):
		var err1: Error = interacted.connect(_on_interacted)
		if err1 != OK:
			push_warning("GardenCompostBox failed to connect interacted.")
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"garden_state_changed", refresh_visual):
		var err2: Error = bus.connect(&"garden_state_changed", refresh_visual)
		if err2 != OK:
			push_warning("GardenCompostBox failed to connect garden_state_changed.")
	refresh_visual()


func refresh_visual() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var level: int = CommunityGardenService.get_level(ws)
	var summary: Dictionary = CommunityGardenService.get_summary_counts(ws)
	var avail: int = int(summary.get("compost_available", 0))

	var tex_path: String = (
		"res://assets/objects/garden/compost_box_active.png"
		if level >= 2
		else "res://assets/objects/garden/compost_box_locked.png"
	)
	if _sprite != null and ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path) as Texture2D

	if level < 2:
		prompt_text = "Espaço da Composteira (Expansão 2)"
	elif avail > 0:
		prompt_text = "Coletar Composto Orgânico (%d pronto)" % avail
	else:
		prompt_text = "Composteira Comunitária (em preparo)"


func _on_interacted(_actor: Node) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	var level: int = CommunityGardenService.get_level(ws)
	if level < 2:
		if bus != null:
			bus.emit_signal(&"notification_requested", "A Composteira será construída na Expansão 2 da horta!", &"info")
		return
	var got: int = CommunityGardenService.collect_compost(ws, bus)
	if got <= 0 and bus != null:
		bus.emit_signal(&"notification_requested", "O composto ainda está maturando. Volte em breve!", &"garden")
