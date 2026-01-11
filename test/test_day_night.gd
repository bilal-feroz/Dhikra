# test/test_day_night.gd
extends Node2D

## Test scene for day/night cycle
## Accelerated time for testing: 30 second full day cycle
##
## Controls:
##   F1 = Skip to DAWN
##   F2 = Skip to DAY
##   F3 = Skip to DUSK
##   F4 = Skip to NIGHT
##   P  = Pause/unpause time

@onready var debug_label: Label = $CanvasLayer/DebugPanel/DebugLabel
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.3, 0.3, 0.5, 1.0)
const DAWN_COLOR := Color(0.9, 0.8, 0.7, 1.0)
const DUSK_COLOR := Color(0.8, 0.6, 0.5, 1.0)


func _ready() -> void:
	# Set fast time for testing
	if TimeManager:
		TimeManager.day_length_seconds = 30.0  # 30 second full cycle for testing
		TimeManager.period_changed.connect(_on_period_changed)
		_on_period_changed(TimeManager.current_period)
	else:
		push_error("TimeManager autoload not found! Add it in Project Settings -> Autoload")

	print("=== DAY/NIGHT TEST SCENE ===")
	print("Controls:")
	print("  F1 = Skip to DAWN")
	print("  F2 = Skip to DAY")
	print("  F3 = Skip to DUSK")
	print("  F4 = Skip to NIGHT")
	print("  P  = Pause/unpause time")
	print("============================")


func _process(_delta: float) -> void:
	# Update debug display
	if TimeManager and debug_label:
		var drain_text := "UNKNOWN"
		if TimeManager.get_drain_multiplier() < 0.5:
			drain_text = "SLOW (night)"
		elif TimeManager.get_drain_multiplier() < 0.8:
			drain_text = "MEDIUM (transition)"
		else:
			drain_text = "FAST (day)"

		debug_label.text = """Time: %s
Period: %s
Drain: x%.2f (%s)
Sun Height: %.2f
Paused: %s

[F1-F4] Skip periods
[P] Pause time""" % [
			TimeManager.get_time_string(),
			TimeManager.get_period_name(),
			TimeManager.get_drain_multiplier(),
			drain_text,
			TimeManager.get_sun_height(),
			"YES" if TimeManager.time_paused else "NO"
		]


func _input(event: InputEvent) -> void:
	if not TimeManager:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				TimeManager.skip_to_period(TimeManager.Period.DAWN)
				print("Skipped to DAWN")
			KEY_F2:
				TimeManager.skip_to_period(TimeManager.Period.DAY)
				print("Skipped to DAY")
			KEY_F3:
				TimeManager.skip_to_period(TimeManager.Period.DUSK)
				print("Skipped to DUSK")
			KEY_F4:
				TimeManager.skip_to_period(TimeManager.Period.NIGHT)
				print("Skipped to NIGHT")
			KEY_P:
				TimeManager.set_paused(not TimeManager.time_paused)
				print("Time paused: ", TimeManager.time_paused)


func _on_period_changed(period: int) -> void:
	print(">>> Period changed to: ", TimeManager.get_period_name())

	# Tint the screen based on period
	if canvas_modulate:
		var target_color: Color
		match period:
			TimeManager.Period.NIGHT:
				target_color = NIGHT_COLOR
			TimeManager.Period.DAWN:
				target_color = DAWN_COLOR
			TimeManager.Period.DAY:
				target_color = DAY_COLOR
			TimeManager.Period.DUSK:
				target_color = DUSK_COLOR
			_:
				target_color = DAY_COLOR

		var tween := create_tween()
		tween.tween_property(canvas_modulate, "color", target_color, 1.5)
