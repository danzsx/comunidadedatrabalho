class_name EnvironmentalInspectionUI
extends CanvasLayer
## Interactive Environmental Inspection minigame (observation & identification of mosquito breeding sites).

const MAX_MISTAKES: int = 3
const INSPECTION_DURATION_SEC: float = 55.0

@onready var title_label: Label = $Root/MainPanel/Margin/VBox/HeaderBar/Margin/HBox/TitleLabel
@onready var stats_label: Label = $Root/MainPanel/Margin/VBox/HeaderBar/Margin/HBox/StatsLabel
@onready var canvas: EnvironmentalInspectionCanvas = $Root/MainPanel/Margin/VBox/ContentSplit/SceneFrame/InspectionCanvas
@onready var obs_title: Label = $Root/MainPanel/Margin/VBox/ContentSplit/ObserverPanel/Margin/VBox/ObsTitle
@onready var obs_clue: Label = $Root/MainPanel/Margin/VBox/ContentSplit/ObserverPanel/Margin/VBox/ObsClue
@onready var btn_eliminate: Button = $Root/MainPanel/Margin/VBox/ContentSplit/ObserverPanel/Margin/VBox/ActionBox/BtnEliminate
@onready var btn_safe: Button = $Root/MainPanel/Margin/VBox/ContentSplit/ObserverPanel/Margin/VBox/ActionBox/BtnSafe
@onready var feedback_label: Label = $Root/MainPanel/Margin/VBox/ContentSplit/ObserverPanel/Margin/VBox/FeedbackLabel
@onready var summary_overlay: PanelContainer = $Root/SummaryOverlay
@onready var summary_title: Label = $Root/SummaryOverlay/Margin/VBox/SummaryTitle
@onready var summary_body: Label = $Root/SummaryOverlay/Margin/VBox/SummaryBody

var is_active: bool = false

var _player: Node = null
var _dialogue_service: Node = null
var _audio_feedback: Node = null
var _zone_id: StringName = &""
var _items: Array[Dictionary] = []
var _selected_index: int = -1
var _found_foci: int = 0
var _total_foci: int = 0
var _mistakes: int = 0
var _time_left: float = INSPECTION_DURATION_SEC
var _finished: bool = false


func _ready() -> void:
	add_to_group(&"environmental_inspection_ui")
	visible = false
	if summary_overlay != null:
		summary_overlay.visible = false
	if canvas != null and not canvas.item_selected.is_connected(_on_item_selected):
		var err1: Error = canvas.item_selected.connect(_on_item_selected)
		if err1 != OK:
			push_warning("EnvironmentalInspectionUI failed to connect item_selected.")
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"environmental_inspection_requested", _on_inspection_requested):
		var err2: Error = bus.connect(&"environmental_inspection_requested", _on_inspection_requested)
		if err2 != OK:
			push_warning("EnvironmentalInspectionUI failed to connect environmental_inspection_requested.")


func bind_host(player: Node, dialogue_service: Node, audio_feedback: Node = null) -> void:
	_player = player
	_dialogue_service = dialogue_service
	_audio_feedback = audio_feedback


func _on_inspection_requested(zone_id: StringName) -> void:
	if _dialogue_service != null and bool(_dialogue_service.get("is_active")):
		return
	open_inspection(zone_id)


func open_inspection(zone_id: StringName) -> void:
	var zone_def: Dictionary = EnvironmentalInspectionService.get_zone_def(zone_id)
	if zone_def.is_empty():
		return

	_zone_id = zone_id
	_items = _build_items_for_zone(String(zone_id))
	_selected_index = -1
	_found_foci = 0
	_total_foci = 0
	for item: Dictionary in _items:
		if bool(item.get("is_foco", false)):
			_total_foci += 1
	_mistakes = 0
	_time_left = INSPECTION_DURATION_SEC
	_finished = false
	is_active = true
	visible = true

	if summary_overlay != null:
		summary_overlay.visible = false
	if title_label != null:
		title_label.text = "Inspeção — %s" % str(zone_def.get("title", String(zone_id)))
	if canvas != null:
		canvas.setup_scene(str(zone_def.get("environment", "quintal")), _items)

	_reset_observer_panel()
	_update_stats_header()

	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", true)


func _process(delta: float) -> void:
	if not is_active or _finished:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_stats_header()
	if _time_left <= 0.0:
		_complete_inspection(false, "O tempo da inspeção acabou antes de eliminar todos os focos.")


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _finished:
			_close()
		else:
			_on_abort_pressed()
		get_viewport().set_input_as_handled()


func _on_item_selected(index: int) -> void:
	if _finished or index < 0 or index >= _items.size():
		return
	_selected_index = index
	var item: Dictionary = _items[index]
	var state: String = str(item.get("state", "uninspected"))

	if obs_title != null:
		obs_title.text = str(item.get("name", "Recipiente"))
	if obs_clue != null:
		if state == "cleaned":
			obs_clue.text = str(item.get("cleaned_text", "Foco neutralizado!"))
		elif state == "verified_safe":
			obs_clue.text = str(item.get("safe_text", "Verificado sem risco."))
		else:
			obs_clue.text = str(item.get("clue", "Observe atentamente este objeto."))

	var resolved: bool = state != "uninspected"
	if btn_eliminate != null:
		btn_eliminate.disabled = resolved
	if btn_safe != null:
		btn_safe.disabled = resolved


func _on_eliminate_pressed() -> void:
	_evaluate_decision(true)


func _on_safe_pressed() -> void:
	_evaluate_decision(false)


func _evaluate_decision(marked_as_foco: bool) -> void:
	if _finished or _selected_index < 0 or _selected_index >= _items.size():
		return
	var item: Dictionary = _items[_selected_index]
	if str(item.get("state", "uninspected")) != "uninspected":
		return

	var is_foco: bool = bool(item.get("is_foco", false))
	if marked_as_foco == is_foco:
		if is_foco:
			item["state"] = "cleaned"
			_found_foci += 1
			_set_feedback(str(item.get("cleaned_text", "Foco eliminado!")), Color(0.14, 0.48, 0.22, 1.0))
		else:
			item["state"] = "verified_safe"
			_set_feedback(str(item.get("safe_text", "Sem risco confirmado.")), Color(0.18, 0.38, 0.58, 1.0))
		_items[_selected_index] = item
		if _audio_feedback != null and _audio_feedback.has_method(&"play_save_chime"):
			_audio_feedback.call(&"play_save_chime")
	else:
		_mistakes += 1
		if is_foco:
			_set_feedback("Atenção! Esse recipiente tinha água parada com risco de larvas.", Color(0.72, 0.18, 0.16, 1.0))
		else:
			_set_feedback("Alarme falso! Esse objeto estava protegido e não acumula água.", Color(0.72, 0.18, 0.16, 1.0))

	if canvas != null:
		canvas.queue_redraw()
	_on_item_selected(_selected_index)
	_update_stats_header()

	if _found_foci >= _total_foci:
		_complete_inspection(true, "Todos os focos de mosquito foram identificados e eliminados!")
	elif _mistakes >= MAX_MISTAKES:
		_complete_inspection(false, "Muitos erros na avaliação. Focos ativos ficaram para trás.")


func _on_abort_pressed() -> void:
	if _finished:
		_close()
		return
	if _found_foci < _total_foci:
		_complete_inspection(false, "Inspeção encerrada antes de eliminar todos os focos.")
	else:
		_complete_inspection(true, "Todos os focos foram eliminados.")


func _complete_inspection(success: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	if btn_eliminate != null:
		btn_eliminate.disabled = true
	if btn_safe != null:
		btn_safe.disabled = true

	var ws: Node = get_node_or_null("/root/WorldState")
	var bus: Node = get_node_or_null("/root/EventBus")
	var _res: Dictionary = EnvironmentalInspectionService.record_inspection_result(
		ws,
		bus,
		_zone_id,
		success,
		_found_foci,
		_total_foci,
		_mistakes
	)

	if summary_overlay != null:
		summary_overlay.visible = true
	if summary_title != null:
		if success:
			summary_title.text = "Inspeção Ambiental Concluída!"
			summary_title.add_theme_color_override(&"font_color", Color(0.14, 0.46, 0.22, 1.0))
		else:
			summary_title.text = "Atenção: Focos Não Eliminados!"
			summary_title.add_theme_color_override(&"font_color", Color(0.72, 0.18, 0.16, 1.0))
	if summary_body != null:
		var consequence: String = (
			"O local está protegido contra a proliferação do Aedes aegypti."
			if success
			else "Mosquitos começaram a aparecer no bairro. Se o foco continuar ativo, moradores podem contrair dengue e precisar ir à UBS."
		)
		summary_body.text = "%s\n\nFocos eliminados: %d/%d  ·  Erros: %d/%d\n\n%s" % [
			reason,
			_found_foci,
			_total_foci,
			_mistakes,
			MAX_MISTAKES,
			consequence,
		]


func _on_summary_close_pressed() -> void:
	_close()


func _close() -> void:
	is_active = false
	visible = false
	if summary_overlay != null:
		summary_overlay.visible = false
	if _player != null and _player.has_method(&"set_movement_locked"):
		_player.call(&"set_movement_locked", false)


func _reset_observer_panel() -> void:
	if obs_title != null:
		obs_title.text = "Lupa de Campo"
	if obs_clue != null:
		obs_clue.text = "Clique nos recipientes do terreno para observar de perto e decidir se há foco de mosquito ou se o objeto está seguro."
	if btn_eliminate != null:
		btn_eliminate.disabled = true
	if btn_safe != null:
		btn_safe.disabled = true
	if feedback_label != null:
		feedback_label.text = ""


func _set_feedback(text: String, col: Color) -> void:
	if feedback_label == null:
		return
	feedback_label.text = text
	feedback_label.add_theme_color_override(&"font_color", col)


func _update_stats_header() -> void:
	if stats_label == null:
		return
	stats_label.text = "Focos: %d/%d · Erros: %d/%d · %ds" % [
		_found_foci,
		_total_foci,
		_mistakes,
		MAX_MISTAKES,
		int(ceilf(_time_left)),
	]


func _build_items_for_zone(zone_key: String) -> Array[Dictionary]:
	match zone_key:
		"zone_terreno_leste":
			return [
				{
					"kind": "tarp_puddle",
					"name": "Lona azul dobrada",
					"pos": Vector2(0.24, 0.38),
					"radius": 22.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Dobras da lona formaram uma poça funda de água parada na sombra.",
					"cleaned_text": "Lona escorrida e enrolada corretamente!",
				},
				{
					"kind": "tire",
					"name": "Pneu descartado",
					"pos": Vector2(0.74, 0.36),
					"radius": 20.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Água escura acumulada no fundo da borracha com larvas se movendo.",
					"cleaned_text": "Pneu drenado e coberto contra chuva!",
				},
				{
					"kind": "bottle_up",
					"name": "Garrafa aberta em pé",
					"pos": Vector2(0.50, 0.28),
					"radius": 18.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Garrafa virada para cima no entulho, com água da chuva no gargalo.",
					"cleaned_text": "Garrafa esvaziada e virada de boca pra baixo!",
				},
				{
					"kind": "can_open",
					"name": "Lata destampada",
					"pos": Vector2(0.36, 0.74),
					"radius": 18.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Lata enferrujada com dois dedos de água parada no fundo.",
					"cleaned_text": "Lata esvaziada e recolhida para descarte!",
				},
				{
					"kind": "tire_covered",
					"name": "Pneu coberto e seco",
					"pos": Vector2(0.18, 0.72),
					"radius": 20.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Pneu furado e coberto por tábua de madeira. Interior completamente seco.",
					"safe_text": "Correto! Pneu coberto e seco não gera foco.",
				},
				{
					"kind": "bottle_down",
					"name": "Garrafa virada",
					"pos": Vector2(0.64, 0.74),
					"radius": 18.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Garrafa deitada e seca sobre o solo. Não retém água da chuva.",
					"safe_text": "Correto! Garrafa emborcada não acumula água.",
				},
				{
					"kind": "bricks_dry",
					"name": "Pilha de tijolos",
					"pos": Vector2(0.84, 0.66),
					"radius": 19.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Tijolos secos empilhados ao sol, sem nenhuma poça formada.",
					"safe_text": "Correto! Material drenado e seco sem risco.",
				},
			]
		"zone_quintal_fam_c":
			return [
				{
					"kind": "barrel_open",
					"name": "Tonel mal tampado",
					"pos": Vector2(0.22, 0.36),
					"radius": 20.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Tampa de madeira deslocada deixando fresta aberta sobre a água.",
					"cleaned_text": "Tonel vedado firmemente com tampa e tela!",
				},
				{
					"kind": "gutter_clogged",
					"name": "Calha baixa entupida",
					"pos": Vector2(0.56, 0.24),
					"radius": 22.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Folhas secas travaram o escoamento e acumularam água parada.",
					"cleaned_text": "Folhas removidas e calha desobstruída!",
				},
				{
					"kind": "pet_bowl_old",
					"name": "Tigela esquecida",
					"pos": Vector2(0.78, 0.56),
					"radius": 18.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Tigela velha no canto sombreado com água turva parada há dias.",
					"cleaned_text": "Tigela lavada com escova e seca!",
				},
				{
					"kind": "saucer_water",
					"name": "Vaso com água no prato",
					"pos": Vector2(0.38, 0.72),
					"radius": 19.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Prato sob o vaso cheio de água parada na sombra da parede.",
					"cleaned_text": "Água eliminada e prato preenchido com areia!",
				},
				{
					"kind": "barrel_sealed",
					"name": "Reservatório vedado",
					"pos": Vector2(0.82, 0.28),
					"radius": 20.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Tonel com tampa bem ajustada e tela protetora intacta.",
					"safe_text": "Correto! Reservatório bem vedado está seguro.",
				},
				{
					"kind": "pet_bowl_clean",
					"name": "Tigela de água fresca",
					"pos": Vector2(0.18, 0.74),
					"radius": 18.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Água limpa recém-trocada e bordas bem higienizadas.",
					"safe_text": "Correto! Troca diária e lavagem evitam larvas.",
				},
				{
					"kind": "bucket_inverted",
					"name": "Balde emborcado",
					"pos": Vector2(0.62, 0.76),
					"radius": 18.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Balde seco guardado de boca para baixo junto ao muro.",
					"safe_text": "Correto! Balde emborcado não acumula água.",
				},
			]
		_:
			# Default: zone_quintal_fam_a (Quintal da Familia Alencar)
			return [
				{
					"kind": "tire",
					"name": "Pneu no canto do muro",
					"pos": Vector2(0.22, 0.40),
					"radius": 20.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Água escura acumulada no fundo do pneu. Pequenos movimentos na superfície.",
					"cleaned_text": "Pneu drenado e coberto em local seco!",
				},
				{
					"kind": "saucer_water",
					"name": "Pratinho de vaso",
					"pos": Vector2(0.52, 0.36),
					"radius": 19.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Água parada acumulando ao redor do vaso de barro sem areia.",
					"cleaned_text": "Pratinho seco e preenchido com areia até a borda!",
				},
				{
					"kind": "bucket_open",
					"name": "Balde azul destampado",
					"pos": Vector2(0.78, 0.38),
					"radius": 19.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Balde deixado aberto no quintal com água da chuva acumulada.",
					"cleaned_text": "Balde esvaziado, lavado e virado de boca pra baixo!",
				},
				{
					"kind": "bottle_up",
					"name": "Garrafa aberta em pé",
					"pos": Vector2(0.66, 0.74),
					"radius": 18.0,
					"is_foco": true,
					"state": "uninspected",
					"clue": "Garrafa virada para cima acumulando água da chuva no gargalo.",
					"cleaned_text": "Garrafa esvaziada e guardada de boca pra baixo!",
				},
				{
					"kind": "saucer_sand",
					"name": "Vaso com areia",
					"pos": Vector2(0.20, 0.74),
					"radius": 19.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Pratinho preenchido com areia grossa até a borda. Sem água parada.",
					"safe_text": "Correto! Areia até a borda protege o vaso.",
				},
				{
					"kind": "bucket_inverted",
					"name": "Balde emborcado",
					"pos": Vector2(0.44, 0.72),
					"radius": 18.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Balde completamente seco e virado de boca para baixo.",
					"safe_text": "Correto! Recipiente emborcado não acumula água.",
				},
				{
					"kind": "watering_can_dry",
					"name": "Regador seco",
					"pos": Vector2(0.84, 0.72),
					"radius": 18.0,
					"is_foco": false,
					"state": "uninspected",
					"clue": "Regador vazio guardado sob a cobertura. Sem água no interior.",
					"safe_text": "Correto! Regador seco não oferece risco.",
				},
			]
