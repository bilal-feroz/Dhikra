# autoloads/time_manager.gd
extends Node
class_name TimeManagerClass

## Day/Night cycle manager. Tracks time and provides drain multipliers.
## Register as autoload: TimeManager

signal period_changed(new_period: int)
signal time_tick(time_of_day: float)

enum Period { NIGHT, DAWN, DAY, DUSK }

## Time of day as float: 0.0 = midnight, 0.5 = noon, 1.0 = next midnight
var time_of_day: float = 0.30:  # Start at early morning
	set(value):
		time_of_day = wrapf(value, 0.0, 1.0)

## Real seconds for one full day cycle (5 min default)
@export var day_length_seconds: float = 300.0

## Current time period (cached, updates on change)
var current_period: Period = Period.DAY

## Whether time is paused (for menus, cutscenes)
var time_paused: bool = false

## Drain multipliers per period
const DRAIN_MULTIPLIERS := {
	Period.NIGHT: 0.33,
	Period.DAWN: 0.66,
	Period.DAY: 1.0,
	Period.DUSK: 0.66,
}

## Period time boundaries (time_of_day ranges)
const PERIOD_BOUNDS := {
	Period.NIGHT: [0.0, 0.20],   # 00:00 - 04:48
	Period.DAWN:  [0.20, 0.30],  # 04:48 - 07:12
	Period.DAY:   [0.30, 0.70],  # 07:12 - 16:48
	Period.DUSK:  [0.70, 0.80],  # 16:48 - 19:12
	# NIGHT again: [0.80, 1.0]  # 19:12 - 00:00
}


func _ready() -> void:
	# Connect to UI pause events if needed
	if WorldManager:
		WorldManager.ui_active.connect(_on_ui_active)

	# Initialize period
	current_period = _calculate_period()


func _process(delta: float) -> void:
	if time_paused:
		return

	# Advance time
	var time_delta := delta / day_length_seconds
	time_of_day += time_delta

	# Check for period change
	var new_period := _calculate_period()
	if new_period != current_period:
		current_period = new_period
		period_changed.emit(current_period)

		# Also emit through WorldManager for consistency
		if WorldManager:
			WorldManager.time_period_changed.emit(current_period)

	# Emit time tick for UI updates
	time_tick.emit(time_of_day)


func _calculate_period() -> Period:
	# Check each period's bounds
	if time_of_day < 0.20 or time_of_day >= 0.80:
		return Period.NIGHT
	elif time_of_day < 0.30:
		return Period.DAWN
	elif time_of_day < 0.70:
		return Period.DAY
	else:
		return Period.DUSK


## Returns multiplier for water drain based on current time period.
## DAY = 1.0 (full drain), NIGHT = 0.33 (reduced drain)
func get_drain_multiplier() -> float:
	return DRAIN_MULTIPLIERS.get(current_period, 1.0)


## Returns sun angle in degrees (0 = midnight, 180 = noon, 360 = midnight)
## Useful for shadow casting in Milestone 2
func get_sun_angle() -> float:
	return time_of_day * 360.0


## Returns sun height (0.0 at night, 1.0 at noon)
## Useful for shadow length calculations
func get_sun_height() -> float:
	# Use sine curve: 0 at midnight, 1 at noon
	return maxf(0.0, sin(time_of_day * PI))


## Returns normalized time within current period (0.0 = start, 1.0 = end)
## Useful for transition effects
func get_period_progress() -> float:
	match current_period:
		Period.NIGHT:
			if time_of_day < 0.20:
				return time_of_day / 0.20
			else:
				return (time_of_day - 0.80) / 0.20
		Period.DAWN:
			return (time_of_day - 0.20) / 0.10
		Period.DAY:
			return (time_of_day - 0.30) / 0.40
		Period.DUSK:
			return (time_of_day - 0.70) / 0.10
	return 0.0


## Set time directly (for testing or story events)
func set_time(new_time: float) -> void:
	time_of_day = new_time
	current_period = _calculate_period()
	period_changed.emit(current_period)


## Skip to a specific period (jumps to middle of that period)
func skip_to_period(period: Period) -> void:
	match period:
		Period.NIGHT:
			set_time(0.10)
		Period.DAWN:
			set_time(0.25)
		Period.DAY:
			set_time(0.50)
		Period.DUSK:
			set_time(0.75)


## Pause/unpause time progression
func set_paused(paused: bool) -> void:
	time_paused = paused


func _on_ui_active(showing: bool) -> void:
	# Optionally pause time during UI
	# Uncomment if you want time to pause during menus:
	# time_paused = showing
	pass


## Get human-readable time string (for debug)
func get_time_string() -> String:
	var hours := int(time_of_day * 24)
	var minutes := int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]


## Get period name as string
func get_period_name() -> String:
	match current_period:
		Period.NIGHT: return "NIGHT"
		Period.DAWN: return "DAWN"
		Period.DAY: return "DAY"
		Period.DUSK: return "DUSK"
	return "UNKNOWN"
