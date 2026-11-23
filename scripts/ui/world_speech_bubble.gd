class_name WorldSpeechBubble
extends Node2D
## Ambient floating parchment speech bubble above NPCs (inspired by Graveyard Keeper).

var _panel: PanelContainer = null
var _label: Label = null
var _tween: Tween = null


func _ready() -> void:
	z_index = 45
	visible = false
	modulate.a = 0.0

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.91, 0.82, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.36, 0.25, 0.16, 0.95)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	_panel.add_theme_stylebox_override(&"panel", style)

	_label = Label.new()
	_label.add_theme_color_override(&"font_color", Color(0.18, 0.14, 0.1, 1.0))
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	add_child(_panel)


func show_message(text: String, duration: float = 3.2) -> void:
	if _label == null or _panel == null or text.is_empty():
		return
	_label.text = text
	_panel.reset_size()
	var panel_w: float = maxf(68.0, float(text.length()) * 4.2 + 12.0)
	_panel.position = Vector2(-panel_w * 0.5, -46.0)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	var err: Error = _tween.finished.connect(func() -> void: visible = false)
	if err != OK:
		push_warning("WorldSpeechBubble failed to connect tween finished.")
