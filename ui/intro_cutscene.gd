extends CanvasLayer

signal cutscene_finished()

const INTRO_TEXTS := [
	"In the Rub al-Khali, the Empty Quarter,\nour ancestors learned to read the land.",
	"They called it Farasat Al-Sahraa—\nDesert Intuition.",
	"The stars guided them. The tracks told stories.\nThe sand itself whispered secrets.",
	"Water is not just survival.\nIt is trust. It is hospitality. It is honor.",
	"Now you must walk their path.\nListen. Observe. Remember.",
	"Your Dhikra—your memory—\nwill echo for those who follow."
]

@onready var text_label: Label = $Panel/TextLabel
@onready var advance_hint: Label = $Panel/AdvanceHint
@onready var dimmer: ColorRect = $Dimmer

var current_index := 0
var cutscene_shown := false
var is_transitioning := false

func _ready() -> void:
	visible = false
	WorldManager.oasis_left.connect(_on_oasis_left)

func _on_oasis_left() -> void:
	if cutscene_shown:
		return
	# Skip intro cutscene in multiplayer mode
	if NetworkManager.is_multiplayer:
		cutscene_shown = true
		return
	# Only show on first time leaving an oasis
	cutscene_shown = true
	_show_cutscene()

func _show_cutscene() -> void:
	visible = true
	current_index = 0
	WorldManager.ui_active.emit(true)
	dimmer.modulate = Color(1, 1, 1, 0)
	text_label.modulate = Color(1, 1, 1, 0)
	advance_hint.modulate = Color(1, 1, 1, 0)

	# Fade in
	var tween := create_tween()
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.5)
	tween.tween_callback(_show_current_text)

func _show_current_text() -> void:
	is_transitioning = true
	text_label.text = INTRO_TEXTS[current_index]
	text_label.modulate = Color(1, 1, 1, 0)
	advance_hint.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.tween_property(text_label, "modulate:a", 1.0, 0.4)
	tween.tween_property(advance_hint, "modulate:a", 0.6, 0.3)
	tween.tween_callback(func() -> void: is_transitioning = false)

func _input(event: InputEvent) -> void:
	if not visible or is_transitioning:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("player_dig"):
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	is_transitioning = true

	# Fade out current text
	var tween := create_tween()
	tween.tween_property(text_label, "modulate:a", 0.0, 0.2)
	tween.tween_property(advance_hint, "modulate:a", 0.0, 0.1)

	current_index += 1
	if current_index >= len(INTRO_TEXTS):
		tween.tween_callback(_finish_cutscene)
	else:
		tween.tween_callback(_show_current_text)

func _finish_cutscene() -> void:
	var tween := create_tween()
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		visible = false
		WorldManager.ui_active.emit(false)
		cutscene_finished.emit()
	)
