extends Control

@onready var ui: CanvasLayer = $UI
@onready var settings: CanvasLayer = $Settings
@onready var comment_setup: CanvasLayer = $CommentSetup
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var world_map: CanvasLayer = $WorldMap
@onready var objective_widget: Control = $UI/ObjectiveWidget
@onready var player: Node2D = $World/Player

# Day/night colors
const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.3, 0.3, 0.5, 1.0)
const DAWN_COLOR := Color(0.9, 0.8, 0.7, 1.0)
const DUSK_COLOR := Color(0.8, 0.6, 0.5, 1.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# TODO: Add retry logic if the first room is full,
	#  fallback to the next and so on
	# Don't connect to Playroom if using LAN multiplayer
	if not OS.has_feature("editor") and not NetworkManager.is_multiplayer:
		Playroom.connect_room(Playroom.GLOBAL_ROOMS[0])

	settings.visible = false
	comment_setup.visible = false

	settings.switch_menu.connect(_on_settings_leave)
	comment_setup.switch_menu.connect(_on_comment_finished)

	# Connect to TimeManager for day/night visuals
	if TimeManager:
		TimeManager.period_changed.connect(_on_period_changed)
		# Initialize with current period
		_on_period_changed(TimeManager.current_period)

	# Set up objective widget with player reference
	if objective_widget and player:
		objective_widget.set_player(player)

	# Emit game started signal
	WorldManager.game_started.emit()


func _process(_delta: float) -> void:
	# Handle map toggle
	if Input.is_action_just_pressed("toggle_map"):
		if not _is_any_ui_active():
			world_map.show_map(player)

	if Input.is_action_just_pressed("escape_menu"):
		if comment_setup.visible:
			comment_setup.visible = false
		elif world_map.visible:
			world_map.visible = false
			WorldManager.ui_active.emit(false)
		else:
			settings.visible = not settings.visible
			WorldManager.ui_active.emit(settings.visible)
			if settings.visible:
				settings.grab()


func _is_any_ui_active() -> bool:
	return settings.visible or comment_setup.visible or world_map.visible


func _on_settings_leave() -> void:
	WorldManager.ui_active.emit(false)
	settings.visible = false
	#ui.visible = true


func _on_comment_finished() -> void:
	WorldManager.ui_active.emit(false)
	comment_setup.visible = false


func _on_period_changed(period: int) -> void:
	if not day_night_modulate:
		return

	var target_color: Color
	match period:
		TimeManager.Period.NIGHT:
			target_color = NIGHT_COLOR
		TimeManager.Period.DAWN:
			target_color = DAWN_COLOR
		TimeManager.Period.DAY:
			target_color = DAY_COLOR
		TimeManager.Period.DUSK:
			target_color = DUSK_COLOR
		_:
			target_color = DAY_COLOR

	# Smoothly transition the screen tint
	var tween := create_tween()
	tween.tween_property(day_night_modulate, "color", target_color, 2.0)
