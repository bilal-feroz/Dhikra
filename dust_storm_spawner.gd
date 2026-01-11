extends Node2D
class_name DustStormSpawner

const STORM_ZONE = preload("res://dust_storm_zone.tscn")

@export var spawn_interval: float = 45.0  # Spawn new storm every 45s
@export var storm_duration: float = 60.0  # Each storm lasts 60s
@export var max_active_storms: int = 2
@export var min_spawn_distance: float = 150.0  # Min distance from player
@export var max_spawn_distance: float = 400.0  # Max distance from player

var active_storms: Array[DustStormZone] = []
var player: Player = null

func _ready() -> void:
	print("=== DUST STORM SPAWNER READY ===")

	# Find the player
	await get_tree().create_timer(2.0).timeout
	var players = get_tree().get_nodes_in_group("players")
	print("Found ", players.size(), " players")
	if players.size() > 0:
		player = players[0]
		print("Player found at: ", player.global_position)

	# Wait 20 seconds before spawning first storm
	await get_tree().create_timer(20.0).timeout
	_spawn_storm_on_player()

	# Set up timer for periodic spawning
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_storm_near_player)
	timer.autostart = true
	add_child(timer)

func _spawn_storm_on_player() -> void:
	print("=== SPAWNING STORM ON PLAYER ===")
	if player == null:
		print("ERROR: Player is null!")
		return

	var storm = STORM_ZONE.instantiate()
	# Spawn EXACTLY where player is standing - impossible to miss
	storm.global_position = player.global_position

	get_parent().add_child(storm)
	active_storms.append(storm)

	print("!!! DUST STORM SPAWNED RIGHT ON YOU at: ", storm.global_position)
	print("Player position: ", player.global_position)

	# Auto-remove after duration - IMMEDIATE removal, no fade
	await get_tree().create_timer(storm_duration).timeout
	if is_instance_valid(storm):
		storm.queue_free()
	active_storms.erase(storm)

func _spawn_storm_near_player() -> void:
	if active_storms.size() >= max_active_storms:
		return

	if player == null:
		# Try to find player again
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0:
			player = players[0]
		else:
			return

	var storm = STORM_ZONE.instantiate()

	# Spawn near the player (not at global_position which might be 0,0)
	var angle = randf() * TAU
	var distance = randf_range(min_spawn_distance, max_spawn_distance)
	storm.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * distance

	get_parent().add_child(storm)
	active_storms.append(storm)

	print("DUST STORM SPAWNED at: ", storm.global_position, " (Player at: ", player.global_position, ")")

	# Auto-remove after duration - IMMEDIATE removal, no fade
	await get_tree().create_timer(storm_duration).timeout
	if is_instance_valid(storm):
		storm.queue_free()
	active_storms.erase(storm)

func clear_all_storms() -> void:
	for storm in active_storms:
		if is_instance_valid(storm):
			storm.queue_free()
	active_storms.clear()
