extends CanvasLayer

signal switch_menu()

@onready var sfx_ui: AudioStreamPlayer = $"SFX UI"

@onready var bgm_level: HSlider = $VBoxContainer/HBoxContainer/BGMLevel
@onready var sfx_level: HSlider = $VBoxContainer/HBoxContainer2/SFXLevel

@onready var accept: TextureButton = $Accept
@onready var exit: TextureButton = $Exit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	accept.pressed.connect(_on_accept)
	exit.pressed.connect(_on_exit)

	# Initialize with the default settings
	bgm_level.value = SoundManager.bgm_level
	sfx_level.value = SoundManager.sfx_level
	_on_volume_changed(bgm_level.value, "BGM")
	_on_volume_changed(sfx_level.value, "SFX")

	bgm_level.value_changed.connect(_on_volume_changed.bind("BGM"))
	sfx_level.value_changed.connect(_on_volume_changed.bind("SFX"))

func grab() -> void:
	bgm_level.grab_focus()

func _on_volume_changed(value: float, bus: String) -> void:
	var bgm_index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(bgm_index, linear_to_db(value))

	sfx_ui.play()
	
	if bus == "BGM":
		SoundManager.bgm_level = value
	elif bus == "SFX":
		SoundManager.sfx_level = value

func _on_accept() -> void:
	sfx_ui.play()
	switch_menu.emit()

func _on_exit() -> void:
	sfx_ui.play()
	get_tree().change_scene_to_file("res://main.tscn")
