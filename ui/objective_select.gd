extends CanvasLayer

const GAME = preload("res://game.tscn")

signal switch_menu()

# Visual tuning for readability
const MENU_FONT = preload("res://Kenney Mini Square Mono.ttf")
const BUTTON_HEIGHT := 54.0
const BUTTON_PADDING := Vector2(12, 8)
const BUTTON_BG_COLOR := Color(0.92, 0.88, 0.78, 0.9)
const NAME_FONT_SIZE := 13
const DESC_FONT_SIZE := 9
const DIFF_FONT_SIZE := 9
const NAME_COLOR := Color(1.0, 0.95, 0.85, 1)  # Light cream for visibility
const DESC_COLOR := Color(0.9, 0.85, 0.75, 1)  # Slightly darker cream
const OUTLINE_COLOR := Color(0.2, 0.15, 0.1, 0.8)  # Dark outline for contrast

# Objective definitions with positions and descriptions
const OBJECTIVES := {
	"final_oasis": {
		"name": "The Final Oasis",
		"description": "Cross the Rub al-Khali to the legendary waters beyond",
		"position": Vector2(47, 4336),
		"difficulty": "Full Journey"
	},
	"ancient_ruins": {
		"name": "The Falaj Ruins",
		"description": "Seek the ancient irrigation channels of our ancestors",
		"position": Vector2(47, 2000),
		"difficulty": "Half Journey"
	},
	"nearby_spring": {
		"name": "Hidden Spring",
		"description": "A shorter path to water - learn the desert's ways",
		"position": Vector2(47, 800),
		"difficulty": "First Steps"
	}
}

@onready var objective_container: VBoxContainer = $Panel/Margin/Content/ObjectiveList
@onready var back_button: TextureButton = $Panel/Margin/Content/BackButton
@onready var sfx_ui: AudioStreamPlayer = get_node_or_null("../SFX UI")

var selected_objective: String = ""
var objective_buttons: Array[TextureButton] = []

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_create_objective_buttons()

func _create_objective_buttons() -> void:
	# Clear existing buttons
	for child in objective_container.get_children():
		child.queue_free()
	objective_buttons.clear()

	# Create a button for each objective
	for key in OBJECTIVES.keys():
		var objective: Dictionary = OBJECTIVES[key]
		var button := _create_button(key, objective)
		objective_container.add_child(button)
		objective_buttons.append(button)

	# Set up focus navigation
	for i in range(objective_buttons.size()):
		var btn := objective_buttons[i]
		if i > 0:
			btn.focus_neighbor_top = objective_buttons[i - 1].get_path()
			btn.focus_previous = objective_buttons[i - 1].get_path()
		if i < objective_buttons.size() - 1:
			btn.focus_neighbor_bottom = objective_buttons[i + 1].get_path()
			btn.focus_next = objective_buttons[i + 1].get_path()

	# Connect last button to back button
	if objective_buttons.size() > 0:
		var last_btn := objective_buttons[objective_buttons.size() - 1]
		last_btn.focus_neighbor_bottom = back_button.get_path()
		last_btn.focus_next = back_button.get_path()
		back_button.focus_neighbor_top = last_btn.get_path()
		back_button.focus_previous = last_btn.get_path()
		# First button focus from back
		objective_buttons[0].focus_neighbor_top = back_button.get_path()
		back_button.focus_neighbor_bottom = objective_buttons[0].get_path()

func _create_button(key: String, objective: Dictionary) -> TextureButton:
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL

	# Add visible background for the button
	var background := ColorRect.new()
	background.color = Color(0.65, 0.55, 0.45, 1.0)  # Darker brown, fully opaque
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(background)
	button.move_child(background, 0)  # Ensure background is behind other children

	# Create container for button content - use VBox for two rows
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = BUTTON_PADDING.x
	vbox.offset_top = BUTTON_PADDING.y
	vbox.offset_right = -BUTTON_PADDING.x
	vbox.offset_bottom = -BUTTON_PADDING.y
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)

	# Top row: Name + Difficulty on same line
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = objective["name"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 1.0))
	name_label.add_theme_constant_override("outline_size", 2)

	var diff_label := Label.new()
	diff_label.text = "[%s]" % objective["difficulty"]
	diff_label.add_theme_font_size_override("font_size", 10)
	var diff_color := Color(0.3, 0.9, 0.3, 1)  # Green for easy
	if objective["difficulty"] == "Half Journey":
		diff_color = Color(0.9, 0.8, 0.2, 1)  # Yellow
	elif objective["difficulty"] == "Full Journey":
		diff_color = Color(0.9, 0.4, 0.1, 1)  # Orange
	diff_label.add_theme_color_override("font_color", diff_color)
	diff_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 1.0))
	diff_label.add_theme_constant_override("outline_size", 2)

	top_row.add_child(name_label)
	top_row.add_child(diff_label)

	# Bottom row: Description (single line)
	var desc_label := Label.new()
	desc_label.text = objective["description"]
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 1.0))
	desc_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 1.0))
	desc_label.add_theme_constant_override("outline_size", 1)

	vbox.add_child(top_row)
	vbox.add_child(desc_label)
	button.add_child(vbox)

	# Connect button press
	button.pressed.connect(_on_objective_selected.bind(key))

	return button

func grab() -> void:
	if objective_buttons.size() > 0:
		objective_buttons[0].grab_focus()

func _on_objective_selected(key: String) -> void:
	if sfx_ui:
		sfx_ui.play()

	# Store selected objective in WorldManager
	var objective: Dictionary = OBJECTIVES[key]
	WorldManager.selected_objective_name = objective["name"]
	WorldManager.selected_objective_position = objective["position"]

	# Start the game
	get_tree().change_scene_to_packed(GAME)

func _on_back() -> void:
	if sfx_ui:
		sfx_ui.play()
	switch_menu.emit()
