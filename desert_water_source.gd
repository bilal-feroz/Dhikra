extends Area2D
class_name DesertWaterSource

@onready var sprite: Sprite2D = $Sprite2D
@onready var water_circle: Polygon2D = $WaterCircle
@onready var interaction_hint: Sprite2D = $InteractionHint
@onready var refill_cooldown: Timer = $RefillCooldown

@export var water_amount: float = 80.0  # How much water this source gives (increased for better survival)
@export var cooldown_time: float = 30.0  # Seconds before it can be used again
@export var is_limited_use: bool = false  # If true, can only be used once

var is_available: bool = true
var player_nearby: bool = false
var current_player: Player = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	refill_cooldown.timeout.connect(_on_cooldown_finished)

	interaction_hint.visible = false

	# Set cooldown time
	refill_cooldown.wait_time = cooldown_time

	# Add to water sources group for detection
	add_to_group("water_sources")

func _process(_delta: float) -> void:
	# Show hint when player is nearby and source is available
	if player_nearby and is_available:
		interaction_hint.visible = true

		# Check if player presses E to drink
		if Input.is_action_just_pressed("player_dig"):
			_drink_water()
	else:
		interaction_hint.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body.is_remote_player:
		player_nearby = true
		current_player = body

func _on_body_exited(body: Node2D) -> void:
	if body is Player and not body.is_remote_player:
		player_nearby = false
		current_player = null
		interaction_hint.visible = false

func _drink_water() -> void:
	if not is_available or current_player == null:
		return

	# Add water to player
	current_player.water_buffs += water_amount
	current_player.water_refill.play()

	# Show visual feedback
	_show_consumed_effect()

	# Mark as unavailable
	is_available = false
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Darken sprite
	water_circle.color = Color(0.3, 0.3, 0.3, 0.5)  # Darken circle

	# Start cooldown or disable permanently
	if is_limited_use:
		# Fade out permanently
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
		tween.parallel().tween_property(water_circle, "color:a", 0.0, 2.0)
	else:
		# Start cooldown timer
		refill_cooldown.start()

func _show_consumed_effect() -> void:
	# Create visual feedback effect
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)

	# Pulse the water circle
	var tween2 = create_tween()
	tween2.tween_property(water_circle, "scale", Vector2(1.3, 1.3), 0.1)
	tween2.tween_property(water_circle, "scale", Vector2(1.0, 1.0), 0.1)

func _on_cooldown_finished() -> void:
	# Make water source available again
	is_available = true
	sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)  # Restore normal color
	water_circle.color = Color(0.2, 0.6, 0.9, 0.8)  # Restore circle color
