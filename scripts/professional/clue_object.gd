class_name ClueObject
extends Interactable
## Observable environmental clue inside a residence during an ACS home visit.

@export var family_id: StringName = &"fam_a"
@export var clue_id: StringName = &""
@export var clue_title: String = "Observar detalhe"
@export var observation_note: String = ""

@onready var marker_rect: ColorRect = get_node_or_null("MarkerRect") as ColorRect


func _ready() -> void:
	prompt_text = clue_title
	if not interacted.is_connected(_on_interacted):
		var err: Error = interacted.connect(_on_interacted)
		if err != OK:
			push_warning("ClueObject failed to connect interacted.")
	_refresh_visual()


func _on_interacted(_actor: Node) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	if ws == null:
		return
	var added: bool = FieldVisitService.register_observation(ws, bus, family_id, clue_id, observation_note)
	if not added and bus != null:
		bus.emit_signal(&"notification_requested", "Voce ja anotou esta observacao no Caderno.", &"notebook")
	_refresh_visual()


func _refresh_visual() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null or marker_rect == null:
		return
	var rec: Dictionary = HouseholdRecordService.get_record(ws, family_id)
	var clues: Array = rec.get("discovered_clues", []) as Array
	var already_found: bool = String(clue_id) in clues
	marker_rect.color = Color(0.55, 0.78, 0.55, 0.55) if already_found else Color(0.95, 0.82, 0.35, 0.88)
