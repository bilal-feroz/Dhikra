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
@onready var storm_label: Label = $StormWarningLabel

var current_period: int = -1
var storm_time_left: float = -1.0
var night_hint_shown := false
var storm_pulse_tween: Tween = null


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

	if WorldManager:
		WorldManager.dust_storm_warning.connect(_on_dust_storm_warning)

	if storm_label:
		storm_label.visible = false


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
			# Show heritage navigation hint first time night falls
			if not night_hint_shown:
				night_hint_shown = true
				_show_night_hint()
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


func _process(delta: float) -> void:
	if storm_time_left < 0.0 or not storm_label:
		return

	storm_time_left -= delta
	if storm_time_left <= 0.0:
		storm_label.visible = false
		storm_time_left = -1.0
		_stop_storm_pulse()
		return

	storm_label.text = "! HABOOB IN %s - SEEK SHELTER" % _format_seconds(storm_time_left)


func _on_dust_storm_warning(time_until: float) -> void:
	if not storm_label:
		return
	storm_time_left = maxf(time_until, 0.0)
	# Heritage: "Haboob" is the Arabic word for intense sandstorm
	storm_label.text = "! HABOOB IN %s - SEEK SHELTER" % _format_seconds(storm_time_left)
	storm_label.visible = true
	_start_storm_pulse()


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


func _format_seconds(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	var mins := total / 60
	var secs := total % 60
	return "%d:%02d" % [mins, secs]


func _show_night_hint() -> void:
	# Create a temporary hint label about night navigation
	var hint := Label.new()
	hint.text = "The stars guide those who watch - water drains slower at night"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
	hint.modulate.a = 0.0
	add_child(hint)
	hint.position = Vector2(-100, 30)

	# Fade in, wait, fade out
	var tween := create_tween()
	tween.tween_property(hint, "modulate:a", 1.0, 1.0)
	tween.tween_interval(4.0)
	tween.tween_property(hint, "modulate:a", 0.0, 1.0)
	tween.tween_callback(hint.queue_free)


func _start_storm_pulse() -> void:
	if storm_pulse_tween:
		storm_pulse_tween.kill()
	if not storm_label:
		return
	# Urgent pulsing red/orange warning
	storm_pulse_tween = create_tween().set_loops()
	storm_pulse_tween.tween_property(storm_label, "modulate", Color(1.5, 0.4, 0.3, 1.0), 0.4)
	storm_pulse_tween.tween_property(storm_label, "modulate", Color(1.0, 0.8, 0.6, 1.0), 0.4)


func _stop_storm_pulse() -> void:
	if storm_pulse_tween:
		storm_pulse_tween.kill()
		storm_pulse_tween = null
	if storm_label:
		storm_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
