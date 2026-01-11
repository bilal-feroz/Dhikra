extends Control

@onready var ui: CanvasLayer = $UI
@onready var settings: CanvasLayer = $Settings
@onready var comment_setup: CanvasLayer = $CommentSetup
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var world_map: CanvasLayer = $WorldMap
@onready var objective_widget: Control = $UI/ObjectiveWidget
@onready var star_compass: Control = $UI/StarCompass
@onready var player: Node2D = $World/Player

# Day/night colors
const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.3, 0.3, 0.5, 1.0)
const DAWN_COLOR := Color(0.9, 0.8, 0.7, 1.0)
const DUSK_COLOR := Color(0.8, 0.6, 0.5, 1.0)

# Low water vignette
var danger_vignette: ColorRect = null
var vignette_tween: Tween = null

# Death wisdom display
var wisdom_layer: CanvasLayer = null
var wisdom_container: Control = null

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

	# Set up star compass with player reference
	if star_compass and player:
		star_compass.set_player(player)

	# Set up danger vignette for low water warning
	_setup_danger_vignette()
	WorldManager.player_water_changed.connect(_on_water_changed)

	# Set up death wisdom display
	_setup_wisdom_display()
	WorldManager.player_waiting_respawn.connect(_on_player_waiting_respawn)
	WorldManager.player_respawn.connect(_on_player_respawned)

	# Oasis entry celebration
	WorldManager.oasis_entered.connect(_on_oasis_celebration)

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


func _setup_danger_vignette() -> void:
	# Create a red vignette overlay for low water warning
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 10
	add_child(vignette_layer)

	danger_vignette = ColorRect.new()
	danger_vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_layer.add_child(danger_vignette)


func _on_water_changed(total_water: float, _delta: float, _intensity: int) -> void:
	if not danger_vignette:
		return

	# Check if player has flasks (from player node)
	var has_flasks := false
	if player and player.has_method("get") == false:
		has_flasks = player.unused_flasks > 0 if "unused_flasks" in player else false

	var is_critical := total_water < 20.0 and not has_flasks

	if is_critical:
		# Pulse the vignette
		if vignette_tween == null or not vignette_tween.is_running():
			vignette_tween = create_tween().set_loops()
			vignette_tween.tween_property(danger_vignette, "color:a", 0.25, 0.4)
			vignette_tween.tween_property(danger_vignette, "color:a", 0.1, 0.4)
	else:
		# Fade out vignette
		if vignette_tween:
			vignette_tween.kill()
			vignette_tween = null
		danger_vignette.color.a = 0.0


func _setup_wisdom_display() -> void:
	# Create wisdom display layer for death screen
	wisdom_layer = CanvasLayer.new()
	wisdom_layer.layer = 15
	add_child(wisdom_layer)

	wisdom_container = Control.new()
	wisdom_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	wisdom_container.visible = false
	wisdom_layer.add_child(wisdom_container)

	# Dimmer background
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wisdom_container.add_child(dimmer)

	# Arabic wisdom text
	var arabic_label := Label.new()
	arabic_label.name = "ArabicWisdom"
	arabic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arabic_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arabic_label.set_anchors_preset(Control.PRESET_CENTER)
	arabic_label.offset_left = -200
	arabic_label.offset_right = 200
	arabic_label.offset_top = -60
	arabic_label.offset_bottom = -20
	arabic_label.add_theme_font_size_override("font_size", 18)
	arabic_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	wisdom_container.add_child(arabic_label)

	# English translation
	var english_label := Label.new()
	english_label.name = "EnglishWisdom"
	english_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	english_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	english_label.set_anchors_preset(Control.PRESET_CENTER)
	english_label.offset_left = -200
	english_label.offset_right = 200
	english_label.offset_top = -10
	english_label.offset_bottom = 30
	english_label.add_theme_font_size_override("font_size", 12)
	english_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1.0))
	wisdom_container.add_child(english_label)

	# Respawn hint
	var hint_label := Label.new()
	hint_label.name = "RespawnHint"
	hint_label.text = "Press E to rise again"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER)
	hint_label.offset_left = -100
	hint_label.offset_right = 100
	hint_label.offset_top = 50
	hint_label.offset_bottom = 80
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.8))
	wisdom_container.add_child(hint_label)


func _on_player_waiting_respawn() -> void:
	if not wisdom_container:
		return

	# Get random wisdom
	var wisdom: Dictionary = WorldManager.get_random_wisdom()

	# Set wisdom text
	var arabic_label: Label = wisdom_container.get_node("ArabicWisdom")
	var english_label: Label = wisdom_container.get_node("EnglishWisdom")

	if arabic_label:
		arabic_label.text = wisdom["arabic"]
	if english_label:
		english_label.text = "\"" + wisdom["english"] + "\""

	# Fade in
	wisdom_container.modulate.a = 0.0
	wisdom_container.visible = true
	var tween := create_tween()
	tween.tween_property(wisdom_container, "modulate:a", 1.0, 0.8)


func _on_player_respawned() -> void:
	if not wisdom_container:
		return

	# Fade out
	var tween := create_tween()
	tween.tween_property(wisdom_container, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): wisdom_container.visible = false)


func _on_oasis_celebration() -> void:
	# Brief green flash when entering oasis - feeling of relief
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 8
	add_child(flash_layer)

	var flash := ColorRect.new()
	flash.color = Color(0.4, 0.8, 0.5, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash)

	# Flash in and out
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.3, 0.15)
	tween.tween_property(flash, "color:a", 0.0, 0.4)
	tween.tween_callback(flash_layer.queue_free)
