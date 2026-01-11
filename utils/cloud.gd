extends Sprite2D

@export var travel_distance := 1600.0
@export var travel_time := 120.0

var initial_position: Vector2 = Vector2.ZERO

var tween: Tween = null
var has_rained: bool = false  # Track if this cloud has already been used for rain

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add to clouds group so player can detect and interact with clouds
	add_to_group("clouds")

	initial_position = position

	#WorldManager.player_respawn.connect(reset)

	#reset()

func reset() -> void:
	if tween != null:
		tween.kill()

	position = initial_position
	modulate.a = 1.0
	has_rained = false  # Reset rain state when cloud resets

	tween = create_tween()

	tween.tween_property(self, "position", position + Vector2.LEFT* travel_distance, travel_time )
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(reset)

func make_it_rain() -> Vector2:
	# Mark this cloud as having rained
	has_rained = true
	# Return the position where rain should spawn (below the cloud)
	return global_position + Vector2(0, 100)
