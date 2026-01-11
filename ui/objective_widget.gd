extends Control

const END_OASIS_POS := Vector2(47, 4336)

@onready var goal_label: Label = $VBoxContainer/GoalLabel
@onready var distance_label: Label = $VBoxContainer/DistanceLabel
@onready var compass_icon: TextureRect = $VBoxContainer/CompassRow/CompassIcon

var player_ref: Node2D = null

func _ready() -> void:
	WorldManager.oasis_entered.connect(_on_oasis_entered)
	WorldManager.oasis_left.connect(_on_oasis_left)
	WorldManager.player_upgraded.connect(_on_upgrade)
	WorldManager.game_started.connect(_on_game_started)
	_update_goal()

func set_player(player: Node2D) -> void:
	player_ref = player

func _process(delta: float) -> void:
	if player_ref != null and visible:
		var distance := player_ref.global_position.distance_to(END_OASIS_POS)
		var direction := "north" if player_ref.global_position.y < END_OASIS_POS.y else "south"
		distance_label.text = "%d steps %s" % [int(distance / 10), direction]

		# Rotate compass to point towards destination
		var dir_to_target := (END_OASIS_POS - player_ref.global_position).normalized()
		var target_angle := atan2(dir_to_target.x, -dir_to_target.y)  # -y because up is negative in 2D
		compass_icon.rotation = lerp_angle(compass_icon.rotation, target_angle, delta * 5.0)

func _on_game_started() -> void:
	_update_goal()

func _on_oasis_entered() -> void:
	goal_label.text = "Rest and refill water"

func _on_oasis_left() -> void:
	_update_goal()

func _on_upgrade(_upgrade: String) -> void:
	_update_goal()

func _update_goal() -> void:
	if not WorldManager.player_has_shovel:
		goal_label.text = "Find the ancient shovel"
	elif WorldManager.player_total_flasks == 0:
		goal_label.text = "Find a water flask"
	else:
		goal_label.text = "Reach the Final Oasis"
