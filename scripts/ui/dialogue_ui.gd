class_name DialogueUI
extends CanvasLayer
## Narrative dialogue box displaying speaker portrait, name, text, and branching choices.

signal advance_requested(next_id: String)

const SPEAKER_PORTRAITS: Dictionary = {
	"Alex": "res://assets/characters/portraits/alex.png",
	"Hortência": "res://assets/characters/portraits/npc_hortencia.png",
	"Hortencia": "res://assets/characters/portraits/npc_hortencia.png",
	"Seu Antônio": "res://assets/characters/portraits/npc_a_1.png",
	"Dona Lúcia": "res://assets/characters/portraits/npc_a_2.png",
	"Pedro": "res://assets/characters/portraits/npc_a_3.png",
	"Dona Rosa": "res://assets/characters/portraits/npc_b_1.png",
	"Tiago": "res://assets/characters/portraits/npc_b_2.png",
	"Camila": "res://assets/characters/portraits/npc_c_1.png",
	"Bruno": "res://assets/characters/portraits/npc_c_2.png",
}

@onready var panel: PanelContainer = $Root/Panel
@onready var portrait_rect: TextureRect = $Root/Panel/Margin/HBox/PortraitRect
@onready var speaker_label: Label = $Root/Panel/Margin/HBox/VBox/SpeakerLabel
@onready var body_label: Label = $Root/Panel/Margin/HBox/VBox/BodyLabel
@onready var choices_box: VBoxContainer = $Root/Panel/Margin/HBox/VBox/ChoicesBox
@onready var continue_hint: Label = $Root/Panel/Margin/HBox/VBox/ContinueHint

var _current_line: DialogueLine = null


func _ready() -> void:
	visible = false


func show_line(line: DialogueLine) -> void:
	_current_line = line
	visible = true
	speaker_label.text = line.character if not line.character.is_empty() else ""
	speaker_label.visible = not line.character.is_empty()
	body_label.text = line.text

	if portrait_rect != null:
		var portrait_path: String = str(SPEAKER_PORTRAITS.get(line.character, ""))
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			portrait_rect.texture = load(portrait_path) as Texture2D
			portrait_rect.visible = true
		else:
			portrait_rect.visible = false

	for child: Node in choices_box.get_children():
		child.queue_free()

	var responses: Array = line.responses
	var has_choices: bool = responses.size() > 0
	continue_hint.visible = not has_choices

	if has_choices:
		var first_btn: Button = null
		for resp: Variant in responses:
			if resp is DialogueResponse:
				var response: DialogueResponse = resp as DialogueResponse
				if not response.is_allowed:
					continue
				var btn := Button.new()
				btn.text = response.text
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	visible = false


func _choose(next_id: String) -> void:
	advance_requested.emit(next_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_line == null:
		return
	if _current_line.responses.size() > 0:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		advance_requested.emit(_current_line.next_id)
