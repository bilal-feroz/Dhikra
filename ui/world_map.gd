extends CanvasLayer

signal map_closed()

const START_OASIS_POS := Vector2(-3, -2)
const END_OASIS_POS := Vector2(47, 4336)

@onready var compass: TextureRect = $Panel/Margin/Content/CompassContainer/Compass
@onready var player_marker: ColorRect = $Panel/Margin/Content/CompassContainer/PlayerMarker
@onready var progress_label: Label = $Panel/Margin/Content/ProgressLabel
@onready var distance_label: Label = $Panel/Margin/Content/DistanceLabel
@onready var close_button: TextureButton = $Panel/Margin/Content/CloseButton

var player_ref: Node2D = null

func _ready() -> void:
	close_button.pressed.connect(_on_close)
	visible = false

func show_map(player: Node2D) -> void:
	player_ref = player
	visible = true
	WorldManager.ui_active.emit(true)
	_update_position()
	close_button.grab_focus()

func _update_position() -> void:
	if player_ref == null:
		return

	# Calculate progress as percentage (vertical journey)
	var total_distance := END_OASIS_POS.y - START_OASIS_POS.y
	var current_progress := player_ref.global_position.y - START_OASIS_POS.y
	var progress_percent := clampf(current_progress / total_distance, 0.0, 1.0)

	# Update player marker position on compass (move along vertical path)
	# Compass is 80x80, we want marker to move from bottom to top
	var compass_height := 70.0
	var marker_y := lerpf(compass_height * 0.4, -compass_height * 0.4, progress_percent)
	player_marker.position = Vector2(0, marker_y)

	# Update progress text
	progress_label.text = "Journey: %d%% complete" % [int(progress_percent * 100)]

	# Calculate remaining distance
	var remaining := player_ref.global_position.distance_to(END_OASIS_POS)
	distance_label.text = "%d steps remaining" % [int(remaining / 10)]

func _on_close() -> void:
	visible = false
	WorldManager.ui_active.emit(false)
	map_closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("toggle_map") or event.is_action_pressed("escape_menu"):
		_on_close()
		get_viewport().set_input_as_handled()
