extends Node2D
class_name WaterSourceSpawner

const WATER_SOURCE = preload("res://desert_water_source.tscn")

@export var spawn_count: int = 5  # How many water sources to spawn
@export var min_distance_from_player: float = 400.0  # Minimum distance from player (outside view)
@export var max_distance_from_player: float = 2000.0  # Maximum distance
@export var spawn_area_size: Vector2 = Vector2(3000, 3000)  # Total area to spawn in
@export var spawn_area_center: Vector2 = Vector2(0, 0)  # Center of spawn area

var spawned_sources: Array[DesertWaterSource] = []

func _ready() -> void:
	# Wait a bit for player to spawn
	await get_tree().create_timer(0.5).timeout
	spawn_water_sources()

	# Respawn water sources when player dies/respawns
	WorldManager.player_respawn.connect(_on_player_respawn)

func spawn_water_sources() -> void:
	# Find the main player (not remote players)
	var player: Player = null
	var world_node = get_tree().root.get_node_or_null("Game/World")
	if world_node:
		for child in world_node.get_children():
			if child is Player and not child.is_remote_player:
				player = child
				break

	if player == null:
		push_error("No player found! Cannot spawn water sources.")
		return

	var player_pos = player.global_position

	for i in range(spawn_count):
		var spawn_pos = _get_random_spawn_position(player_pos)
		var water_source = WATER_SOURCE.instantiate()
		water_source.global_position = spawn_pos

		# Randomize water amount (30-70)
		water_source.water_amount = randf_range(30.0, 70.0)

		# Some sources are limited use (30% chance)
		water_source.is_limited_use = randf() < 0.3

		# Randomize cooldown (20-40 seconds)
		water_source.cooldown_time = randf_range(20.0, 40.0)

		add_child(water_source)
		spawned_sources.append(water_source)

		print("Spawned water source at: ", spawn_pos, " (distance from player: ", player_pos.distance_to(spawn_pos), ")")

func _get_random_spawn_position(player_pos: Vector2) -> Vector2:
	var attempts = 0
	var max_attempts = 50

	while attempts < max_attempts:
		# Generate random position within spawn area
		var random_offset = Vector2(
			randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2),
			randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
		)
		var spawn_pos = spawn_area_center + random_offset

		# Check distance from player
		var distance = player_pos.distance_to(spawn_pos)

		# Must be far enough but not too far
		if distance >= min_distance_from_player and distance <= max_distance_from_player:
			return spawn_pos

		attempts += 1

	# Fallback: spawn at minimum distance in random direction
	var random_angle = randf() * TAU  # Random angle in radians
	var direction = Vector2(cos(random_angle), sin(random_angle))
	return player_pos + direction * min_distance_from_player

func _on_player_respawn() -> void:
	# Clear old water sources
	for source in spawned_sources:
		if is_instance_valid(source):
			source.queue_free()
	spawned_sources.clear()

	# Spawn new ones
	await get_tree().create_timer(0.5).timeout
	spawn_water_sources()

func clear_all_sources() -> void:
	for source in spawned_sources:
		if is_instance_valid(source):
			source.queue_free()
	spawned_sources.clear()
