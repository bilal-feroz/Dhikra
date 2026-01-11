extends CanvasLayer

const GAME = preload("res://game.tscn")

signal switch_menu()

@onready var begin: TextureButton = $Panel/Margin/Content/Buttons/Begin
@onready var back: TextureButton = $Panel/Margin/Content/Buttons/Back
@onready var sfx_ui: AudioStreamPlayer = get_node_or_null("../SFX UI")

func _ready() -> void:
	begin.pressed.connect(_on_begin)
	back.pressed.connect(_on_back)

func grab() -> void:
	begin.grab_focus()

func _on_begin() -> void:
	if sfx_ui:
		sfx_ui.play()
	get_tree().change_scene_to_packed(GAME)

func _on_back() -> void:
	if sfx_ui:
		sfx_ui.play()
	switch_menu.emit()
