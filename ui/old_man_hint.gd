extends Label

var tweener: Tween = null
var hint_dismissed := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	modulate.a = 0

	# Show hint when game starts
	WorldManager.game_started.connect(_on_game_started)

	# Hide hint when player talks to old man
	WorldManager.player_dialog.connect(_on_player_dialog)

func _on_game_started() -> void:
	if hint_dismissed:
		return

	# Wait a bit before showing the hint
	await get_tree().create_timer(1.0).timeout

	# Fade in the hint
	visible = true
	if tweener != null:
		tweener.kill()
	tweener = create_tween()
	tweener.tween_property(self, "modulate:a", 1.0, 1.5)

	# Auto-fade out after 15 seconds if player hasn't found old man yet
	await get_tree().create_timer(15.0).timeout
	if not hint_dismissed:
		_fade_out_hint()

func _on_player_dialog(is_talking: bool) -> void:
	if is_talking and not hint_dismissed:
		hint_dismissed = true
		_fade_out_hint()

func _fade_out_hint() -> void:
	if tweener != null:
		tweener.kill()
	tweener = create_tween()
	tweener.tween_property(self, "modulate:a", 0.0, 1.0)
	tweener.tween_callback(func(): visible = false)
