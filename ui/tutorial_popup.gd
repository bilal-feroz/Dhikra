extends CanvasLayer

const TUTORIALS := {
	"SHOVEL": {
		"title": "SHOVEL FOUND",
		"text": "You found a shovel!\n\nPress E to DIG and unearth hidden water.\nPress R to SENSE water nearby.\n\nLook for ripples in the sand."
	},
	"FLASK": {
		"title": "FLASK FOUND",
		"text": "You found a water flask!\n\nFlasks automatically save you when\nwater runs out.\n\nRefill flasks by resting at an oasis."
	},
	"RAIN": {
		"title": "RAIN ABILITY",
		"text": "You can summon rain from clouds!\n\nPress Q near a cloud to make it rain.\nRain creates temporary water sources.\n\nYou have 3 uses - choose wisely."
	}
}

@onready var panel: ColorRect = $Panel
@onready var title_label: Label = $Panel/Margin/Content/TitleLabel
@onready var text_label: Label = $Panel/Margin/Content/TextLabel
@onready var continue_button: TextureButton = $Panel/Margin/Content/ContinueButton

var popup_queue: Array[String] = []
var showing := false
var shown_tutorials: Array[String] = []

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue)
	WorldManager.player_upgraded.connect(_on_player_upgrade)

func _on_player_upgrade(upgrade: String) -> void:
	if upgrade == Playroom.UPGRADE_SHOVEL:
		queue_tutorial("SHOVEL")
	elif upgrade == Playroom.UPGRADE_FLASK:
		# Only show flask tutorial for first flask
		if WorldManager.player_total_flasks == 1:
			queue_tutorial("FLASK")

func queue_tutorial(tutorial_key: String) -> void:
	if tutorial_key in TUTORIALS and tutorial_key not in shown_tutorials:
		popup_queue.push_back(tutorial_key)
		shown_tutorials.append(tutorial_key)
		if not showing:
			_show_next()

func _show_next() -> void:
	if popup_queue.is_empty():
		showing = false
		visible = false
		WorldManager.ui_active.emit(false)
		return

	showing = true
	var key: String = popup_queue.pop_front()
	var tutorial: Dictionary = TUTORIALS[key]

	title_label.text = tutorial["title"]
	text_label.text = tutorial["text"]

	visible = true
	WorldManager.ui_active.emit(true)
	continue_button.grab_focus()

func _on_continue() -> void:
	_show_next()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("player_dig"):
		_on_continue()
		get_viewport().set_input_as_handled()
