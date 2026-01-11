extends Area2D
class_name DustStormZone

@export var storm_intensity: float = 3.0  # Multiplier for water drain (3x faster)

func _ready() -> void:
	print("!!! DUST STORM ZONE _ready() called at position: ", global_position)
	collision_layer = 16  # Layer 16 so DustStormDetector can see it
	collision_mask = 1
	add_to_group("dust_storms")

	print("Creating dust storm visual components...")

	# Create MASSIVE storm area that covers the screen
	var shape = CircleShape2D.new()
	shape.radius = 900.0  # HUGE collision area
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual polygon for storm - ABSOLUTELY MASSIVE SCREEN COVERAGE
	var visual = Polygon2D.new()
	visual.z_index = 5

	# Create circular polygon - ABSOLUTELY GIGANTIC to cover entire viewport
	var points = PackedVector2Array()
	var num_points = 32
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		var radius_variation = randf_range(3500.0, 4000.0)  # GIGANTIC radius
		points.append(Vector2(cos(angle), sin(angle)) * radius_variation)

	visual.polygon = points
	visual.color = Color(0.8, 0.6, 0.3, 0.35)  # Semi-transparent sandy brown
	add_child(visual)

	# Add HUGE warning label
	var label = Label.new()
	label.text = "!!! DUST STORM !!!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.5, 0.2, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(-150, -400)
	label.z_index = 10
	add_child(label)

	# Add MASSIVE dust particle field covering entire screen
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 500  # Tons of particles for full screen
	particles.lifetime = 4.0  # Longer lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 3000.0  # GIGANTIC emission area
	particles.direction = Vector2(1, 0)
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 6.0
	particles.scale_amount_max = 12.0
	particles.color = Color(0.7, 0.6, 0.4, 0.5)
	particles.z_index = 4
	add_child(particles)
	print("Particles created and EMITTING!")

	# SHOW IMMEDIATELY - NO FADE IN
	modulate.a = 1.0

	print("!!! DUST STORM ZONE FULLY CREATED AND VISIBLE!")
	print("Storm position: ", global_position)
	print("Storm has ", get_child_count(), " children")
	print("Visual polygon color: ", visual.color)
	print("Label text: ", label.text)
