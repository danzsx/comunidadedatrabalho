class_name DialogueUI
extends CanvasLayer
## Reference-inspired RPG dialogue UI: bust portrait above bottom-left, nameplate with live bond heart,
## crisp bottom dialogue box with typewriter reveal, and floating branching choices stacked on the right.

signal advance_requested(next_id: String)

const TYPEWRITER_CHARS_PER_SEC: float = 65.0

const SPEAKER_BUST_PORTRAITS: Dictionary = {
	"Alex": "res://assets/characters/portraits/bust_alex.png",
	"Dona Lúcia": "res://assets/characters/portraits/bust_npc_a_2.png",
	"Dona Lucia": "res://assets/characters/portraits/bust_npc_a_2.png",
}

const SPEAKER_PORTRAITS: Dictionary = {
	"Alex": "res://assets/characters/portraits/alex.png",
	"Hortência": "res://assets/characters/portraits/npc_hortencia.png",
	"Hortencia": "res://assets/characters/portraits/npc_hortencia.png",
	"Seu Antônio": "res://assets/characters/portraits/npc_a_1.png",
	"Dona Lúcia": "res://assets/characters/portraits/npc_a_2.png",
	"Dona Lucia": "res://assets/characters/portraits/npc_a_2.png",
	"Pedro": "res://assets/characters/portraits/npc_a_3.png",
	"Dona Rosa": "res://assets/characters/portraits/npc_b_1.png",
	"Tiago": "res://assets/characters/portraits/npc_b_2.png",
	"Camila": "res://assets/characters/portraits/npc_c_1.png",
	"Bruno": "res://assets/characters/portraits/npc_c_2.png",
}

const SPEAKER_TO_NPC_ID: Dictionary = {
	"Hortência": &"npc_hortencia",
	"Hortencia": &"npc_hortencia",
	"Seu Antônio": &"npc_a_1",
	"Dona Lúcia": &"npc_a_2",
	"Dona Lucia": &"npc_a_2",
	"Pedro": &"npc_a_3",
	"Dona Rosa": &"npc_b_1",
	"Tiago": &"npc_b_2",
	"Camila": &"npc_c_1",
	"Bruno": &"npc_c_2",
}

@onready var portrait_rect: TextureRect = $Root/PortraitRect
@onready var nameplate_panel: PanelContainer = $Root/NameplatePanel
@onready var heart_icon: DialogueHeartIcon = $Root/NameplatePanel/Margin/HBox/HeartIcon
@onready var speaker_label: Label = $Root/NameplatePanel/Margin/HBox/SpeakerLabel
@onready var panel: PanelContainer = $Root/DialoguePanel
@onready var body_label: Label = $Root/DialoguePanel/Margin/VBox/BodyLabel
@onready var continue_hint: Label = $Root/DialoguePanel/Margin/VBox/ContinueHint
@onready var choices_box: VBoxContainer = $Root/ChoicesBox

var _current_line: DialogueLine = null
var _active_npc_id: StringName = &""
var _full_text: String = ""
var _visible_chars_f: float = 0.0
var _is_typing: bool = false
var _choice_style_normal: StyleBoxFlat = null
var _choice_style_hover: StyleBoxFlat = null
var _choice_style_focus: StyleBoxFlat = null


func _ready() -> void:
	visible = false
	_build_choice_styles()


func set_dialogue_context(npc_id: StringName, _context: Dictionary = {}) -> void:
	_active_npc_id = npc_id


func show_line(line: DialogueLine) -> void:
	_current_line = line
	visible = true

	var speaker: String = line.character if not line.character.is_empty() else ""
	var has_speaker: bool = not speaker.is_empty()
	if nameplate_panel != null:
		nameplate_panel.visible = has_speaker
	if speaker_label != null:
		speaker_label.text = speaker

	_update_portrait(speaker)
	_update_heart_icon(speaker)

	_full_text = line.text
	if body_label != null:
		body_label.text = _full_text
		body_label.visible_characters = 0
	_visible_chars_f = 0.0
	_is_typing = not _full_text.is_empty()

	for child: Node in choices_box.get_children():
		child.queue_free()

	var responses: Array = line.responses
	var has_choices: bool = responses.size() > 0
	if continue_hint != null:
		continue_hint.visible = not has_choices

	if has_choices:
		# Reveal text immediately when branching choices are presented so the player can read & pick right away.
		_finish_typing()
		var first_btn: Button = null
		for resp: Variant in responses:
			if resp is DialogueResponse:
				var response: DialogueResponse = resp as DialogueResponse
				if not response.is_allowed:
					continue
				var btn := Button.new()
				btn.text = response.text
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				btn.custom_minimum_size = Vector2(210.0, 22.0)
				btn.add_theme_font_size_override(&"font_size", 9)
				btn.add_theme_color_override(&"font_color", Color(0.97, 0.96, 0.92, 1.0))
				btn.add_theme_color_override(&"font_hover_color", Color(1.0, 0.95, 0.72, 1.0))
				btn.add_theme_color_override(&"font_focus_color", Color(1.0, 0.95, 0.72, 1.0))
				if _choice_style_normal != null:
					btn.add_theme_stylebox_override(&"normal", _choice_style_normal)
				if _choice_style_hover != null:
					btn.add_theme_stylebox_override(&"hover", _choice_style_hover)
				if _choice_style_focus != null:
					btn.add_theme_stylebox_override(&"focus", _choice_style_focus)
					btn.add_theme_stylebox_override(&"pressed", _choice_style_focus)

				var target_id: String = response.next_id
				var err: Error = btn.pressed.connect(func() -> void: _choose(target_id))
				if err != OK:
					push_warning("DialogueUI failed to connect choice button.")
				choices_box.add_child(btn)
				if first_btn == null:
					first_btn = btn
		if first_btn != null:
			first_btn.grab_focus()


func hide_dialogue() -> void:
	_current_line = null
	_active_npc_id = &""
	_is_typing = false
	visible = false


func _process(delta: float) -> void:
	if not visible or not _is_typing or body_label == null:
		return
	_visible_chars_f += delta * TYPEWRITER_CHARS_PER_SEC
	var next_count: int = mini(int(_visible_chars_f), _full_text.length())
	body_label.visible_characters = next_count
	if next_count >= _full_text.length():
		_finish_typing()


func _finish_typing() -> void:
	_is_typing = false
	if body_label != null:
		body_label.visible_characters = -1


func _choose(next_id: String) -> void:
	advance_requested.emit(next_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_line == null:
		return
	if _current_line.responses.size() > 0:
		return
	var is_click: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		is_click = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or is_click:
		get_viewport().set_input_as_handled()
		if _is_typing:
			_finish_typing()
		else:
			advance_requested.emit(_current_line.next_id)


func _update_portrait(speaker: String) -> void:
	if portrait_rect == null:
		return
	var bust_path: String = str(SPEAKER_BUST_PORTRAITS.get(speaker, ""))
	if not bust_path.is_empty() and ResourceLoader.exists(bust_path):
		portrait_rect.texture = load(bust_path) as Texture2D
		portrait_rect.visible = true
		return
	var fallback_path: String = str(SPEAKER_PORTRAITS.get(speaker, ""))
	if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
		portrait_rect.texture = load(fallback_path) as Texture2D
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false


func _update_heart_icon(speaker: String) -> void:
	if heart_icon == null:
		return
	if speaker == "Alex" or speaker.is_empty():
		heart_icon.visible = false
		return
	var npc_id: StringName = SPEAKER_TO_NPC_ID.get(speaker, _active_npc_id) as StringName
	if npc_id == &"":
		heart_icon.visible = false
		return
	heart_icon.visible = true
	var ws: Node = get_node_or_null("/root/WorldState")
	var axes: Dictionary = RelationshipService.get_all_axes(ws, npc_id)
	heart_icon.set_bond_from_axes(axes)


func _build_choice_styles() -> void:
	_choice_style_normal = StyleBoxFlat.new()
	_choice_style_normal.bg_color = Color(0.11, 0.27, 0.48, 0.96)
	_choice_style_normal.border_width_left = 2
	_choice_style_normal.border_width_top = 2
	_choice_style_normal.border_width_right = 2
	_choice_style_normal.border_width_bottom = 2
	_choice_style_normal.border_color = Color(0.95, 0.94, 0.89, 0.98)
	_choice_style_normal.corner_radius_top_left = 4
	_choice_style_normal.corner_radius_top_right = 4
	_choice_style_normal.corner_radius_bottom_right = 4
	_choice_style_normal.corner_radius_bottom_left = 4
	_choice_style_normal.content_margin_left = 8.0
	_choice_style_normal.content_margin_right = 8.0
	_choice_style_normal.content_margin_top = 4.0
	_choice_style_normal.content_margin_bottom = 4.0

	_choice_style_hover = _choice_style_normal.duplicate() as StyleBoxFlat
	_choice_style_hover.bg_color = Color(0.16, 0.38, 0.64, 0.98)
	_choice_style_hover.border_color = Color(0.98, 0.86, 0.44, 1.0)

	_choice_style_focus = _choice_style_hover.duplicate() as StyleBoxFlat
	_choice_style_focus.bg_color = Color(0.19, 0.43, 0.70, 0.98)
