extends Control

@onready var menu: CanvasLayer = $Menu
@onready var settings: CanvasLayer = $Settings
@onready var instructions: CanvasLayer = $Instructions

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu.switch_menu.connect(_switch_to_settings)
	menu.show_instructions.connect(_switch_to_instructions)
	settings.switch_menu.connect(_switch_to_main)
	instructions.switch_menu.connect(_switch_to_main)

func _switch_to_settings() -> void:
	menu.visible = false
	settings.visible = true
	instructions.visible = false
	
	settings.grab()

func _switch_to_instructions() -> void:
	menu.visible = false
	settings.visible = false
	instructions.visible = true
	
	instructions.grab()

func _switch_to_main() -> void:
	menu.visible = true
	settings.visible = false
	instructions.visible = false
	menu.grab()
