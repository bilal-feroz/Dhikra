extends CanvasLayer

signal switch_menu()
signal show_objective_select()

# Heritage loading tips - Bedouin desert wisdom
const HERITAGE_TIPS := [
	"The Bedouin say: Follow the ghaf trees - their roots find hidden water.",
	"Ancient wisdom: Travel at night when the stars guide and heat fades.",
	"Desert intuition: Read the dunes - wind patterns reveal safe paths.",
	"Bedouin proverb: من سار على الدرب وصل - Who walks the path, arrives.",
	"The ancestors knew: An oryx herd means water is near.",
	"Falaj channels carried life through the Empty Quarter for centuries.",
	"Heritage tip: The North Star guided travelers home for generations.",
]

@onready var begin: TextureButton = $Panel/Margin/Content/Buttons/Begin
@onready var back: TextureButton = $Panel/Margin/Content/Buttons/Back
@onready var sfx_ui: AudioStreamPlayer = get_node_or_null("../SFX UI")

var tip_label: Label = null
var tip_timer: Timer = null
var controls_container: VBoxContainer = null

func _ready() -> void:
	begin.pressed.connect(_on_begin)
	back.pressed.connect(_on_back)
	_setup_controls_display()
	_setup_heritage_tip()

func grab() -> void:
	begin.grab_focus()

func _setup_controls_display() -> void:
	# Create controls container above the buttons
	controls_container = VBoxContainer.new()
	controls_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_container.add_theme_constant_override("separation", 4)

	var panel := $Panel/Margin/Content
	if panel:
		# Insert before buttons (which should be first child)
		panel.add_child(controls_container)
		panel.move_child(controls_container, 0)

	# Title
	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.9, 0.85, 0.75, 0.5))
	title.add_theme_constant_override("outline_size", 1)
	controls_container.add_child(title)

	# Controls grid - two columns (keyboard | controller)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	controls_container.add_child(grid)

	# Add control rows: [Action, Keyboard, Controller]
	_add_control_row(grid, "Move", "WASD / Arrows", "Left Stick / D-Pad")
	_add_control_row(grid, "Dig/Interact", "E / Space", "A Button")
	_add_control_row(grid, "Dowse", "R", "Y Button")
	_add_control_row(grid, "Write", "T", "X Button")
	_add_control_row(grid, "Rain", "Q", "B Button")
	_add_control_row(grid, "Run", "Shift", "RB")
	_add_control_row(grid, "Map", "M", "Select")
	_add_control_row(grid, "Menu", "Esc", "Start")

func _add_control_row(grid: GridContainer, action: String, keyboard: String, controller: String) -> void:
	var action_label := Label.new()
	action_label.text = action + ":"
	action_label.add_theme_font_size_override("font_size", 9)
	action_label.add_theme_color_override("font_color", Color(0.3, 0.25, 0.2, 1.0))

	var kb_label := Label.new()
	kb_label.text = keyboard
	kb_label.add_theme_font_size_override("font_size", 9)
	kb_label.add_theme_color_override("font_color", Color(0.15, 0.35, 0.6, 1.0))

	var ctrl_label := Label.new()
	ctrl_label.text = controller
	ctrl_label.add_theme_font_size_override("font_size", 9)
	ctrl_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.25, 1.0))

	grid.add_child(action_label)
	grid.add_child(kb_label)
	grid.add_child(ctrl_label)

func _on_begin() -> void:
	if sfx_ui:
		sfx_ui.play()
	visible = false
	show_objective_select.emit()

func _on_back() -> void:
	if sfx_ui:
		sfx_ui.play()
	switch_menu.emit()


func _setup_heritage_tip() -> void:
	# Create tip label at bottom of panel
	tip_label = Label.new()
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 8)
	tip_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3, 0.9))
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(400, 30)
	tip_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var panel := $Panel/Margin/Content
	if panel:
		panel.add_child(tip_label)

	_show_random_tip()

	# Cycle tips every 5 seconds
	tip_timer = Timer.new()
	tip_timer.wait_time = 5.0
	tip_timer.timeout.connect(_show_random_tip)
	tip_timer.autostart = true
	add_child(tip_timer)


func _show_random_tip() -> void:
	if tip_label:
		var tip: String = HERITAGE_TIPS[randi() % HERITAGE_TIPS.size()]
		# Fade out, change, fade in
		var tween := create_tween()
		tween.tween_property(tip_label, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): tip_label.text = tip)
		tween.tween_property(tip_label, "modulate:a", 1.0, 0.3)
