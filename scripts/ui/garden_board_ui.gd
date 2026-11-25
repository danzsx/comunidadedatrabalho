class_name GardenBoardUI
extends CanvasLayer
## Community Garden bulletin board panel for inspecting stats, unlocking expansions, and starting Saturday mutiroes.

@onready var summary_label: Label = $Root/Panel/Margin/VBox/SummaryLabel
@onready var upgrade_title_label: Label = $Root/Panel/Margin/VBox/UpgradeBox/UpgradeTitle
@onready var upgrade_req_label: Label = $Root/Panel/Margin/VBox/UpgradeBox/UpgradeReq
@onready var upgrade_button: Button = $Root/Panel/Margin/VBox/UpgradeBox/UpgradeButton
@onready var mutirao_label: Label = $Root/Panel/Margin/VBox/MutiraoBox/MutiraoLabel
@onready var mutirao_button: Button = $Root/Panel/Margin/VBox/MutiraoBox/MutiraoButton

var _player: Node = null
var _dialogue_service: Node = null


func _ready() -> void:
	add_to_group(&"garden_board_ui")
	visible = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"garden_state_changed", _on_garden_changed):
		var err: Error = bus.connect(&"garden_state_changed", _on_garden_changed)
		if err != OK:
			push_warning("GardenBoardUI failed to connect garden_state_changed.")


func bind_host(player: Node, dialogue_service: Node) -> void:
	_player = player
	_dialogue_service = dialogue_service


func open() -> void:
	if _dialogue_service != null and bool(_dialogue_service.get("is_active")):
		return
	refresh()
	visible = true
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", true)


func close() -> void:
	visible = false
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", false)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_garden_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return
	var s: Dictionary = CommunityGardenService.get_summary_counts(ws)
	if summary_label != null:
		if not bool(s.get("unlocked", false)):
			summary_label.text = "A Horta Comunitária ainda está fechada.\nConverse com Dona Rosa na praça para receber o kit inicial de sementes e abrir o espaço!"
		else:
			summary_label.text = (
				"Nível da Horta: %d/3  ·  Plantados: %d  ·  Prontos p/ colher: %d  ·  Secos: %d\n"
				+ "Colheitas totais: %d  ·  Alimentos compartilhados com vizinhos: %d"
			) % [
				int(s.get("level", 0)),
				int(s.get("planted", 0)),
				int(s.get("ready", 0)),
				int(s.get("dry", 0)),
				int(s.get("total_harvests", 0)),
				int(s.get("total_shares", 0)),
			]

	var upg: Dictionary = CommunityGardenService.get_upgrade_info(ws)
	if upgrade_title_label != null:
		upgrade_title_label.text = str(upg.get("title", ""))
	if upgrade_req_label != null:
		upgrade_req_label.text = str(upg.get("requirement_text", ""))
	if upgrade_button != null:
		var unlocked: bool = bool(s.get("unlocked", false))
		upgrade_button.disabled = not (unlocked and bool(upg.get("can_upgrade", false)))
		upgrade_button.text = "Horta Completa!" if bool(upg.get("maxed", false)) else "Construir Expansão"

	var mutirao_ok: bool = CommunityGardenService.is_mutirao_available(ws)
	if mutirao_label != null:
		if mutirao_ok:
			mutirao_label.text = "Mutirão de Sábado em andamento! Participe para regar todos os canteiros, limpar matos e trocar sementes."
		else:
			mutirao_label.text = "Mutirão Comunitário: acontece aos Sábados de Manhã após abrir a horta."
	if mutirao_button != null:
		mutirao_button.disabled = not mutirao_ok


func _on_upgrade_pressed() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	var _ok: bool = CommunityGardenService.try_upgrade_garden(ws, bus)
	refresh()


func _on_mutirao_pressed() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	var _ok: bool = CommunityGardenService.participate_mutirao(ws, bus)
	refresh()


func _on_close_pressed() -> void:
	close()
