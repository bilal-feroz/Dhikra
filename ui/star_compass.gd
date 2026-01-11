# ui/star_compass.gd
extends Control
class_name StarCompass

## Night-time navigation compass showing direction to objective
## Represents Najm Al-Shimali (North Star) navigation - traditional Bedouin wayfinding

@onready var compass_container: Control = $CompassContainer
@onready var star_icon: Label = $CompassContainer/StarIcon
@onready var direction_arrow: Label = $CompassContainer/DirectionArrow
@onready var hint_label: Label = $CompassContainer/HintLabel

var player: Node2D = null
var target_position := Vector2.ZERO
var is_night := false
var fade_tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0

	# Style the compass
	star_icon.text = "★"
	star_icon.add_theme_font_size_override("font_size", 24)
	star_icon.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8, 1.0))

	direction_arrow.text = "▼"
	direction_arrow.add_theme_font_size_override("font_size", 16)
	direction_arrow.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 0.9))

	hint_label.text = "Najm Al-Shimali"
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))

	# Connect to time manager
	if TimeManager:
		TimeManager.period_changed.connect(_on_period_changed)
		_on_period_changed(TimeManager.current_period)


func set_player(p: Node2D) -> void:
	player = p
	target_position = WorldManager.selected_objective_position


func _process(_delta: float) -> void:
	if not is_night or player == null or not visible:
		return

	# Calculate direction to target
	var dir_to_target := player.global_position.direction_to(target_position)
	var angle := dir_to_target.angle() + PI / 2  # Adjust for "up" being forward

	# Rotate the arrow to point toward destination
	direction_arrow.rotation = angle

	# Subtle star twinkle
	var twinkle := 0.9 + sin(Time.get_ticks_msec() * 0.005) * 0.1
	star_icon.modulate.a = twinkle


func _on_period_changed(period: int) -> void:
	is_night = (period == TimeManager.Period.NIGHT)

	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()

	if is_night:
		visible = true
		fade_tween.tween_property(self, "modulate:a", 1.0, 1.5)
	else:
		fade_tween.tween_property(self, "modulate:a", 0.0, 1.0)
		fade_tween.tween_callback(func(): visible = false)
