class_name GardenBoard
extends Interactable
## Community garden bulletin board opening GardenBoardUI for upgrades and Saturday mutiroes.


func _ready() -> void:
	prompt_text = "Consultar Quadro da Horta"
	if not interacted.is_connected(_on_interacted):
		var err: Error = interacted.connect(_on_interacted)
		if err != OK:
			push_warning("GardenBoard failed to connect interacted.")


func _on_interacted(_actor: Node) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"garden_board_ui"):
		if node.has_method(&"open"):
			node.call(&"open")
			return
