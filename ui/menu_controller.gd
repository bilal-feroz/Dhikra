extends CanvasLayer

signal switch_menu()
signal show_instructions()

@onready var start: TextureButton = $Options/Start
@onready var settings: TextureButton = $Options/Settings

@onready var sfx_ui: AudioStreamPlayer = $"../SFX UI"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	grab()

	start.pressed.connect(_on_start)
	settings.pressed.connect(_on_settings)

func grab() -> void:
	start.grab_focus()

func _on_start() -> void:
	print("Start pressed")
	sfx_ui.play()
	show_instructions.emit()

func _on_settings() -> void:
	print("Settings pressed")
	sfx_ui.play()
	switch_menu.emit()
