# ui/time_display/time_display.gd
extends Control
class_name TimeDisplay

## Displays current time period and countdown to next period

@export var sun_texture: Texture2D
@export var moon_texture: Texture2D
@export var dawn_color: Color = Color("ff9966")
@export var day_color: Color = Color("ffff99")
@export var dusk_color: Color = Color("ff6633")
@export var night_color: Color = Color("6666cc")

@onready var time_icon: TextureRect = $HBoxContainer/TimeIcon
@onready var period_label: Label = $HBoxContainer/PeriodLabel
@onready var countdown_label: Label = $HBoxContainer/CountdownLabel

var current_period: int = -1


func _ready() -> void:
	# Connect to TimeManager signals
	if TimeManager:
		TimeManager.period_changed.connect(_on_period_changed)
		TimeManager.time_tick.connect(_on_time_tick)
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


func _on_time_tick(_time_of_day: float) -> void:
	# Update countdown to next period
	if countdown_label and TimeManager:
		var countdown := _get_time_until_next_period()
		var next_period := _get_next_period_name()
		countdown_label.text = "%s in %s" % [next_period, countdown]


func _get_time_until_next_period() -> String:
	if not TimeManager:
		return "??:??"

	var time := TimeManager.time_of_day
	var next_boundary: float

	# Find the next period boundary
	match TimeManager.current_period:
		TimeManager.Period.NIGHT:
			if time < 0.20:
				next_boundary = 0.20  # Dawn starts
			else:
				next_boundary = 1.0  # Wrap to midnight, then dawn at 0.20
		TimeManager.Period.DAWN:
			next_boundary = 0.30  # Day starts
		TimeManager.Period.DAY:
			next_boundary = 0.70  # Dusk starts
		TimeManager.Period.DUSK:
			next_boundary = 0.80  # Night starts
		_:
			next_boundary = 1.0

	# Calculate time remaining
	var time_remaining: float
	if TimeManager.current_period == TimeManager.Period.NIGHT and time >= 0.80:
		# Night wraps around midnight
		time_remaining = (1.0 - time) + 0.20
	else:
		time_remaining = next_boundary - time

	# Convert to real seconds
	var seconds_remaining := time_remaining * TimeManager.day_length_seconds
	var minutes := int(seconds_remaining / 60)
	var seconds := int(seconds_remaining) % 60

	return "%d:%02d" % [minutes, seconds]


func _get_next_period_name() -> String:
	if not TimeManager:
		return "?"

	match TimeManager.current_period:
		TimeManager.Period.NIGHT:
			return "Dawn"
		TimeManager.Period.DAWN:
			return "Day"
		TimeManager.Period.DAY:
			return "Dusk"
		TimeManager.Period.DUSK:
			return "Night"
	return "?"
