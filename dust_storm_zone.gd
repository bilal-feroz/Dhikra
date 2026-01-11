extends Area2D
class_name DustStormZone

@export var storm_intensity: float = 2.0  # Multiplier for water drain

func _ready() -> void:
	print("!!! DUST STORM ZONE _ready() called at position: ", global_position)
	collision_layer = 16  # Layer 16 so DustStormDetector can see it
	collision_mask = 1
	add_to_group("dust_storms")

	print("Creating dust storm visual components...")

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
	particles.emitting = true  # CRITICAL FIX: Make particles actually emit!
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
	print("Particles created and EMITTING!")

	# SHOW IMMEDIATELY - NO FADE IN
	modulate.a = 1.0

	# Add a bright colored sprite as backup visual
	var sprite = Sprite2D.new()
	var texture = PlaceholderTexture2D.new()
	texture.size = Vector2(600, 600)
	sprite.texture = texture
	sprite.modulate = Color(1.0, 0.5, 0.0, 0.8)  # Bright orange
	sprite.z_index = 100  # On top of EVERYTHING
	add_child(sprite)

	print("!!! DUST STORM ZONE FULLY CREATED AND VISIBLE!")
	print("Storm position: ", global_position)
	print("Storm has ", get_child_count(), " children")
	print("Visual polygon color: ", visual.color)
	print("Label text: ", label.text)
	print("Sprite created with size 600x600 at z_index 100")
