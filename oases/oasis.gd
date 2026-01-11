extends Area2D
class_name Dhikra

@onready var player_respawn: Marker2D = $PlayerRespawn

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add to water sources group so player can sense oases
	add_to_group("water_sources")

# Make oasis always available for water sense detection
var is_available: bool = true

