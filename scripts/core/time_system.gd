extends Node
## Manages flexible 4-period time (Manha/Tarde/Noite/Madrugada), calendar, and simulation ticks.

const PERIOD_NAMES: Array[String] = ["Manhã", "Tarde", "Noite", "Madrugada"]
const WEEKDAY_NAMES: Array[String] = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
const PERIODS_PER_DAY: int = 4

var autosave_on_day_end: bool = true


func _ready() -> void:
	# Initialize routines for Day 1, Morning as soon as DataRegistry is ready.
	WorldSimulationTick.process_tick(false, WorldState, DataRegistry, EventBus)


func get_period_name(period: int = -1) -> String:
	var idx: int = WorldState.period if period < 0 else period
	if idx >= 0 and idx < PERIOD_NAMES.size():
		return PERIOD_NAMES[idx]
	return "Manhã"


func get_weekday_name(day_number: int = -1) -> String:
	var d: int = WorldState.day if day_number < 0 else day_number
	var idx: int = posmod(d - 1, WEEKDAY_NAMES.size())
	return WEEKDAY_NAMES[idx]


func advance_period(steps: int = 1) -> void:
	var count: int = maxi(1, steps)
	for _i: int in range(count):
		var ended_day: int = WorldState.day
		var wrapped_day: bool = false
		WorldState.period += 1
		if WorldState.period >= PERIODS_PER_DAY:
			WorldState.period = 0
			WorldState.day += 1
			WorldState.week = ((WorldState.day - 1) / 7) + 1
			wrapped_day = true

		WorldSimulationTick.process_tick(wrapped_day, WorldState, DataRegistry, EventBus)

		if wrapped_day:
			EventBus.day_ended.emit(ended_day)
			if autosave_on_day_end:
				var _save_err: Error = SaveSystem.save_autosave()

		EventBus.period_changed.emit(WorldState.day, WorldState.period)


func sleep_until_morning() -> void:
	var ended_day: int = WorldState.day
	WorldState.day += 1
	WorldState.week = ((WorldState.day - 1) / 7) + 1
	WorldState.period = 0

	WorldSimulationTick.process_tick(true, WorldState, DataRegistry, EventBus)
	EventBus.day_ended.emit(ended_day)
	if autosave_on_day_end:
		var _save_err: Error = SaveSystem.save_autosave()
	EventBus.period_changed.emit(WorldState.day, WorldState.period)
