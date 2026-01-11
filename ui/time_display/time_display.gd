# ui/time_display/time_display.gd
extends Control
class_name TimeDisplay

## Displays current time period and optional time-of-day indicator

@export var sun_texture: Texture2D
@export var moon_texture: Texture2D
@export var dawn_color: Color = Color("ff9966")
@export var day_color: Color = Color("ffff99")
@export var dusk_color: Color = Color("ff6633")
@export var night_color: Color = Color("6666cc")

@onready var time_icon: TextureRect = $HBoxContainer/TimeIcon
@onready var period_label: Label = $HBoxContainer/PeriodLabel

var current_period: int = -1


func _ready() -> void:
	# Connect to TimeManager signals
	if TimeManager:
		TimeManager.period_changed.connect(_on_period_changed)
		# Initialize with current period
		_on_period_changed(TimeManager.current_period)
	else:
		push_warning("TimeDisplay: TimeManager autoload not found")
		period_label.text = "NO TIME"


func _on_period_changed(period: int) -> void:
	if period == current_period:
		return

	current_period = period

	# Update icon and label
	match period:
		TimeManager.Period.NIGHT:
			if moon_texture:
				time_icon.texture = moon_texture
			period_label.text = "NIGHT"
			period_label.modulate = night_color
		TimeManager.Period.DAWN:
			if sun_texture:
				time_icon.texture = sun_texture
			period_label.text = "DAWN"
			period_label.modulate = dawn_color
		TimeManager.Period.DAY:
			if sun_texture:
				time_icon.texture = sun_texture
			period_label.text = "DAY"
			period_label.modulate = day_color
		TimeManager.Period.DUSK:
			if sun_texture:
				time_icon.texture = sun_texture
			period_label.text = "DUSK"
			period_label.modulate = dusk_color
