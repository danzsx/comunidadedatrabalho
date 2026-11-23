class_name RestPoint
extends Interactable
## Interactive bed/rest spot in CasaAlex allowing Alex to advance to the next morning.


func _ready() -> void:
	prompt_text = "Dormir ate amanha"
	if not interacted.is_connected(_on_interacted):
		var err: Error = interacted.connect(_on_interacted)
		if err != OK:
			push_warning("RestPoint failed to connect interacted.")


func _on_interacted(_actor: Node) -> void:
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null:
		ts.call(&"sleep_until_morning")
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(&"notification_requested", "Voce descansou. Um novo dia comecou.", &"time")
