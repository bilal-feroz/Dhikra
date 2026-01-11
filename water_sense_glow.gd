extends Node2D
class_name WaterSenseGlow

@export var detection_range: float = 500.0  # How far to detect water - much farther now
@export var max_glow_intensity: float = 1.0  # Maximum glow brightness
@export var pulse_speed: float = 2.0  # How fast the glow pulses

var current_intensity: float = 0.0
var pulse_time: float = 0.0
var water_ripples: Array[Polygon2D] = []
var num_ripples: int = 3

func _ready() -> void:
	# Create multiple water ripple rings that emanate from character
	for i in range(num_ripples):
		var ripple = Polygon2D.new()
		ripple.z_index = -1

		# Create ring shape (circle with hole in middle)
		var points = PackedVector2Array()
		var num_points = 24
		var inner_radius = 15.0 + (i * 8.0)
		var outer_radius = inner_radius + 4.0

		# Create ring by making outer circle then inner circle in reverse
		for j in range(num_points):
			var angle = (j / float(num_points)) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
		for j in range(num_points - 1, -1, -1):
			var angle = (j / float(num_points)) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * inner_radius)

		ripple.polygon = points
		ripple.color = Color(0.3, 0.8, 1.0, 0.0)  # Bright cyan, start invisible
		add_child(ripple)
		water_ripples.append(ripple)

func _process(delta: float) -> void:
	var player = get_parent() as Player
	if player == null or player.is_remote_player:
		return

	# Find nearest water source
	var nearest_distance = INF
	var water_sources = get_tree().get_nodes_in_group("water_sources")

	for source in water_sources:
		# Check both desert water sources and oases
		var is_valid_source = false
		if source is DesertWaterSource:
			is_valid_source = source.is_available
		elif source is Dhikra:
			is_valid_source = true  # Oases are always available

		if is_valid_source:
			var distance = player.global_position.distance_to(source.global_position)
			if distance < nearest_distance:
				nearest_distance = distance

	# Calculate glow intensity based on distance
	if nearest_distance <= detection_range:
		# Closer = stronger glow (inverse relationship)
		var distance_ratio = 1.0 - (nearest_distance / detection_range)
		current_intensity = distance_ratio * max_glow_intensity
	else:
		# No water nearby, fade out
		current_intensity = lerp(current_intensity, 0.0, delta * 2.0)

	# Add pulsing/ripple effect - each ring pulses at different times
	pulse_time += delta * pulse_speed

	# Animate ripples emanating from character like water flowing outward
	for i in range(num_ripples):
		if i < water_ripples.size():
			var ripple = water_ripples[i]

			# Each ripple has offset timing for wave effect
			var offset_time = pulse_time + (i * 0.3)
			var pulse = (sin(offset_time) + 1.0) / 2.0  # 0.0 to 1.0

			# Calculate this ripple's intensity
			var ripple_intensity = current_intensity * (0.5 + pulse * 0.5)

			# Apply to ripple
			ripple.color.a = ripple_intensity * 0.7  # Slightly transparent for effect

			# Scale grows and shrinks to simulate water flowing outward
			var scale_factor = 1.0 + (pulse * 0.5)
			ripple.scale = Vector2.ONE * scale_factor

	# Debug output
	if nearest_distance < detection_range:
		print("Water detected! Distance: ", nearest_distance, " Intensity: ", current_intensity)
