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

func _ready() -> void:
	begin.pressed.connect(_on_begin)
	back.pressed.connect(_on_back)
	_setup_heritage_tip()

func grab() -> void:
	begin.grab_focus()

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
	tip_label.add_theme_font_size_override("font_size", 9)
	tip_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 0.9))
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(500, 40)
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
