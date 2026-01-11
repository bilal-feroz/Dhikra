extends Node

# Controller mouse emulation - right stick moves cursor, A button clicks

const CURSOR_SPEED := 400.0  # Pixels per second at full stick deflection
const DEADZONE := 0.15

var mouse_emulation_enabled := true

func _ready() -> void:
	# Process input every frame
	set_process_input(true)

func _process(delta: float) -> void:
	if not mouse_emulation_enabled:
		return

	# Read right stick (axes 2 and 3 on most controllers)
	var right_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var right_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	# Apply deadzone
	if abs(right_x) < DEADZONE:
		right_x = 0.0
	if abs(right_y) < DEADZONE:
		right_y = 0.0

	# Move cursor if stick is deflected
	if right_x != 0.0 or right_y != 0.0:
		var move_vector := Vector2(right_x, right_y) * CURSOR_SPEED * delta
		var current_pos := get_viewport().get_mouse_position()
		var new_pos := current_pos + move_vector

		# Clamp to screen bounds
		var screen_size := get_viewport().get_visible_rect().size
		new_pos.x = clampf(new_pos.x, 0, screen_size.x)
		new_pos.y = clampf(new_pos.y, 0, screen_size.y)

		# Warp mouse to new position
		Input.warp_mouse(new_pos)

func _input(event: InputEvent) -> void:
	if not mouse_emulation_enabled:
		return

	# A button (button index 0) simulates mouse click
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		var mouse_pos := get_viewport().get_mouse_position()

		# Create and send mouse button event
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = event.pressed
		mouse_event.position = mouse_pos
		mouse_event.global_position = mouse_pos

		# Parse the event through the input system
		Input.parse_input_event(mouse_event)
