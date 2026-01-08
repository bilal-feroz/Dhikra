extends Node3D

@export var start_scene := "res://dhikra_game.tscn"
@export var click_area_path: NodePath = NodePath("CameraProp/ClickArea")

var _starting := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click_area = get_node_or_null(click_area_path)
	if click_area:
		click_area.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _starting:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_starting = true
		get_tree().change_scene_to_file(start_scene)
