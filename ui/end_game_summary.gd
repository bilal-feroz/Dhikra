extends CanvasLayer

signal play_again_pressed()

@onready var time_label: Label = $Panel/Margin/Content/Stats/TimeRow/TimeValue
@onready var deaths_label: Label = $Panel/Margin/Content/Stats/DeathsRow/DeathsValue
@onready var water_label: Label = $Panel/Margin/Content/Stats/WaterRow/WaterValue
@onready var play_again_btn: TextureButton = $Panel/Margin/Content/Buttons/PlayAgain
@onready var main_menu_btn: TextureButton = $Panel/Margin/Content/Buttons/MainMenu

func _ready() -> void:
	visible = false
	play_again_btn.pressed.connect(_on_play_again)
	main_menu_btn.pressed.connect(_on_main_menu)
	WorldManager.game_completed.connect(_on_game_completed)

func _on_game_completed() -> void:
	# Calculate and display stats
	var time_ms: int = WorldManager.game_end_time - WorldManager.game_start_time
	var total_seconds: int = time_ms / 1000
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	time_label.text = "%02d:%02d" % [minutes, seconds]
	deaths_label.text = "%d" % WorldManager.total_deaths
	water_label.text = "%.0f" % [WorldManager.total_water_consumed / 100.0]

	# Show after short delay for dramatic effect
	await get_tree().create_timer(1.5).timeout
	visible = true
	WorldManager.ui_active.emit(true)
	play_again_btn.grab_focus()

func _on_play_again() -> void:
	_reset_world_manager()
	get_tree().change_scene_to_file("res://game.tscn")

func _on_main_menu() -> void:
	_reset_world_manager()
	get_tree().change_scene_to_file("res://main.tscn")

func _reset_world_manager() -> void:
	WorldManager.total_water_consumed = 0.0
	WorldManager.total_deaths = 0
	WorldManager.game_start_time = 0
	WorldManager.game_end_time = 0
	WorldManager.player_has_shovel = false
	WorldManager.player_has_flask = false
	WorldManager.player_completed_game = false
	WorldManager.player_total_flasks = 0
	WorldManager.current_zone = ""
