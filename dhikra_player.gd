extends CharacterBody3D

@export var speed := 2.5
@export var mouse_sensitivity := 0.002
@export var max_pitch_degrees := 70.0

var _pitch := 0.0
var _locked := false
var _game: Node

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_game = get_parent()

func set_game(game: Node) -> void:
	_game = game

func reset_view(pitch_degrees: float = 0.0) -> void:
	_pitch = deg_to_rad(pitch_degrees)
	camera.rotation.x = _pitch

func lock() -> void:
	_locked = true
	velocity = Vector3.ZERO

func unlock() -> void:
	_locked = false

func _physics_process(delta: float) -> void:
	if _locked:
		return
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	move_and_slide()

func _input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(-max_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		camera.rotation.x = _pitch
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _game and _game.has_method("on_primary_action"):
			_game.on_primary_action(ray)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _game and _game.has_method("on_secondary_action"):
			_game.on_secondary_action()
