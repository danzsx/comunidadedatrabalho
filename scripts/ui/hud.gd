class_name GameHUD
extends CanvasLayer
## Minimal HUD showing Day/Weekday, current Period, Location name, and event notifications.

@onready var time_label: Label = $Root/TopLeftPanel/Margin/TimeLabel
@onready var location_label: Label = $Root/TopRightPanel/Margin/LocationLabel
@onready var toast_panel: PanelContainer = $Root/ToastPanel
@onready var toast_label: Label = $Root/ToastPanel/Margin/ToastLabel

var _toast_timer: SceneTreeTimer = null


func _ready() -> void:
	toast_panel.visible = false
	if not EventBus.period_changed.is_connected(_on_period_changed):
		var err1: Error = EventBus.period_changed.connect(_on_period_changed)
		if err1 != OK:
			push_warning("GameHUD failed to connect period_changed.")
	if not SceneRouter.location_loaded.is_connected(_on_location_loaded):
		var err2: Error = SceneRouter.location_loaded.connect(_on_location_loaded)
		if err2 != OK:
			push_warning("GameHUD failed to connect location_loaded.")
	if not EventBus.notification_requested.is_connected(_on_notification_requested):
		var err3: Error = EventBus.notification_requested.connect(_on_notification_requested)
		if err3 != OK:
			push_warning("GameHUD failed to connect notification_requested.")
	refresh()


func refresh() -> void:
	var weekday: String = TimeSystem.get_weekday_name(WorldState.day)
	var period_name: String = TimeSystem.get_period_name(WorldState.period)
	time_label.text = "Dia %d (%s) · %s" % [WorldState.day, weekday, period_name]

	var loc: LocationData = DataRegistry.get_location(WorldState.current_location_id)
	location_label.text = loc.display_name if loc != null else String(WorldState.current_location_id)


func _on_period_changed(_new_day: int, _new_period: int) -> void:
	refresh()


func _on_location_loaded(_location_id: StringName) -> void:
	refresh()


func _on_notification_requested(text: String, _category: StringName) -> void:
	toast_label.text = text
	toast_panel.visible = true
	_toast_timer = get_tree().create_timer(3.5)
	var err: Error = _toast_timer.timeout.connect(_hide_toast)
	if err != OK:
		push_warning("GameHUD failed to connect toast timer.")


func _hide_toast() -> void:
	toast_panel.visible = false
