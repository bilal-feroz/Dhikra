extends Area2D
class_name DustStormZone

@export var storm_intensity: float = 2.0  # Multiplier for water drain

func _ready() -> void:
	collision_layer = 16  # Layer 16 so DustStormDetector can see it
	collision_mask = 1
	add_to_group("dust_storms")

	# Create circular storm area - MUCH BIGGER NOW
	var shape = CircleShape2D.new()
	shape.radius = 300.0
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual polygon for storm - BRIGHT AND OBVIOUS
	var visual = Polygon2D.new()
	visual.z_index = 5  # On top so you can SEE IT

	# Create circular polygon - BIGGER
	var points = PackedVector2Array()
	var num_points = 32
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		var radius_variation = randf_range(250.0, 300.0)  # BIGGER irregular edges
		points.append(Vector2(cos(angle), sin(angle)) * radius_variation)

	visual.polygon = points
	visual.color = Color(0.8, 0.6, 0.3, 0.95)  # BRIGHT sandy brown - VERY VISIBLE
	add_child(visual)

	# Add HUGE warning label
	var label = Label.new()
	label.text = "!!! DUST STORM !!!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.5, 0.2, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-100, -280)
	label.z_index = 10
	add_child(label)

	# Add dust particles
	var particles = CPUParticles2D.new()
	particles.amount = 100
	particles.lifetime = 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 250.0
	particles.direction = Vector2(1, 0)
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.7, 0.6, 0.4, 0.7)
	particles.z_index = 4
	add_child(particles)

	# Animate in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 2.0)
