class_name GardenWaterSource
extends Interactable
## Screened rainwater cistern/pond in the Community Garden used to refill Alex's watering can.


func _ready() -> void:
	prompt_text = "Encher regador (Reservatório com tela)"
	if not interacted.is_connected(_on_interacted):
		var err: Error = interacted.connect(_on_interacted)
		if err != OK:
			push_warning("GardenWaterSource failed to connect interacted.")


func _on_interacted(_actor: Node) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	var _charges: int = CommunityGardenService.refill_watering_can(ws, bus)
