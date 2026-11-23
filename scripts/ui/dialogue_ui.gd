class_name DialogueUI
extends CanvasLayer
## Narrative dialogue box displaying speaker name, text, and branching choices.

signal advance_requested(next_id: String)

@onready var panel: PanelContainer = $Root/Panel
@onready var speaker_label: Label = $Root/Panel/Margin/VBox/SpeakerLabel
@onready var body_label: Label = $Root/Panel/Margin/VBox/BodyLabel
@onready var choices_box: VBoxContainer = $Root/Panel/Margin/VBox/ChoicesBox
@onready var continue_hint: Label = $Root/Panel/Margin/VBox/ContinueHint

var _current_line: DialogueLine = null


func _ready() -> void:
	visible = false


func show_line(line: DialogueLine) -> void:
	_current_line = line
	visible = true
	speaker_label.text = line.character if not line.character.is_empty() else ""
	speaker_label.visible = not line.character.is_empty()
	body_label.text = line.text

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
