extends Node3D

const STATE_HOME := 0
const STATE_LOCATION := 1
const STATE_FINAL := 2
const STATE_END := 3

@export var align_distance := 0.35
@export var align_angle_degrees := 3.0
@export var align_hold_time := 0.35

@onready var player = $Player
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var locations_root: Node3D = $Locations
@onready var home: Node3D = $Locations/Home
@onready var final_location: Node3D = $Locations/Final

@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var old_photo: TextureRect = $UI/OldPhoto
@onready var memory_label: Label = $UI/MemoryLabel
@onready var reticle: Control = $UI/Reticle
@onready var reticle_h: ColorRect = $UI/Reticle/H
@onready var reticle_v: ColorRect = $UI/Reticle/V
@onready var book_panel: ColorRect = $UI/BookPanel
@onready var book_photo: TextureRect = $UI/BookPanel/BookPhoto
@onready var box_overlay: ColorRect = $UI/BoxOverlay
@onready var title_label: Label = $UI/TitleLabel
@onready var subtitle_label: Label = $UI/SubtitleLabel

var _state := STATE_HOME
var _locations: Array = []
var _location_index := 0
var _current_location: Node3D
var _align_hold := 0.0
var _transitioning := false
var _old_photo_base_pos := Vector2.ZERO
var _overlay_cache := {}
var _captured_photos: Array = []

func _ready() -> void:
	player.set_game(self)
	_old_photo_base_pos = old_photo.position
	memory_label.modulate.a = 0.0
	book_panel.visible = false
	old_photo.visible = false
	box_overlay.visible = false
	title_label.visible = false
	subtitle_label.visible = false
	_setup_locations()
	_hide_all_locations()
	home.visible = true
	_apply_environment(Color(0.22, 0.2, 0.18, 1), Color(1, 0.95, 0.9, 1))
	_set_spawn(home)
	reticle.visible = false
	fade_rect.modulate.a = 1.0
	await _fade_from_black()

func _setup_locations() -> void:
	_locations = [
		{
			"node": $Locations/OldFort,
			"memory": "He said places remember us, even when we forget them.",
			"photo": "fort",
			"bg": Color(0.78, 0.72, 0.64, 1),
			"light": Color(1, 0.95, 0.85, 1)
		},
		{
			"node": $Locations/Souk,
			"memory": "He never rushed a moment. Even the busy ones.",
			"photo": "souk",
			"bg": Color(0.72, 0.62, 0.5, 1),
			"light": Color(1, 0.92, 0.82, 1)
		},
		{
			"node": $Locations/Sea,
			"memory": "The sea taught him patience. And silence.",
			"photo": "sea",
			"bg": Color(0.55, 0.65, 0.75, 1),
			"light": Color(0.9, 0.95, 1, 1)
		},
		{
			"node": $Locations/Modern,
			"memory": "He never feared change. Only forgetting.",
			"photo": "modern",
			"bg": Color(0.7, 0.72, 0.78, 1),
			"light": Color(0.95, 0.98, 1, 1)
		}
	]

func _hide_all_locations() -> void:
	for child in locations_root.get_children():
		if child is Node3D:
			child.visible = false

func _set_spawn(location_node: Node3D) -> void:
	var spawn: Marker3D = location_node.get_node_or_null("Spawn")
	if not spawn:
		return
	player.global_transform = spawn.global_transform
	var look_target: Marker3D = location_node.get_node_or_null("ShotTarget")
	if look_target:
		player.look_at(look_target.global_position, Vector3.UP)
		player.rotation.x = 0.0
		player.rotation.z = 0.0
	else:
		player.rotation = Vector3.ZERO
	player.reset_view(0.0)

func _apply_environment(bg: Color, light: Color) -> void:
	if world_env and world_env.environment:
		world_env.environment.background_color = bg
		world_env.environment.ambient_light_color = bg
	if sun:
		sun.light_color = light

func _process(delta: float) -> void:
	if _transitioning:
		return
	if _state == STATE_LOCATION or _state == STATE_FINAL:
		var aligned_data = _get_alignment_data()
		_update_reticle(aligned_data.score)
		if _state == STATE_LOCATION and aligned_data.anchor:
			_update_old_photo_offset(aligned_data.anchor)
		if aligned_data.aligned:
			_align_hold += delta
			if _align_hold >= align_hold_time:
				_align_hold = 0.0
				_capture_current()
		else:
			_align_hold = 0.0

func on_primary_action(ray: RayCast3D) -> void:
	if _transitioning:
		return
	if _state == STATE_HOME:
		if ray:
			ray.force_raycast_update()
		if ray and ray.is_colliding():
			var collider = ray.get_collider()
			if collider and collider.name == "BoxInteract":
				_open_box()
	elif _state == STATE_LOCATION or _state == STATE_FINAL:
		if _get_alignment_data().aligned:
			_capture_current()

func on_secondary_action() -> void:
	if _transitioning:
		return
	if _state == STATE_LOCATION or _state == STATE_FINAL:
		if _get_alignment_data().aligned:
			_capture_current()

func _open_box() -> void:
	if _transitioning:
		return
	_transitioning = true
	player.lock()
	await _show_box_overlay()
	await _show_memory_line("I hadn't seen this in years.")
	await _transition_to_location(0)
	player.unlock()
	_transitioning = false

func _transition_to_location(index: int) -> void:
	await _fade_to_black()
	await _enter_location(index)

func _enter_location(index: int) -> void:
	_state = STATE_LOCATION
	_location_index = index
	var info = _locations[index]
	_current_location = info["node"]
	_hide_all_locations()
	_current_location.visible = true
	_apply_environment(info["bg"], info["light"])
	_set_spawn(_current_location)
	old_photo.texture = _get_overlay_texture(info["photo"])
	old_photo.visible = true
	reticle.visible = true
	_align_hold = 0.0
	await _fade_from_black()

func _enter_final() -> void:
	_state = STATE_FINAL
	_current_location = final_location
	_hide_all_locations()
	_current_location.visible = true
	_apply_environment(Color(0.62, 0.7, 0.62, 1), Color(0.95, 0.98, 0.95, 1))
	_set_spawn(_current_location)
	old_photo.visible = false
	reticle.visible = true
	_align_hold = 0.0
	await _fade_from_black()

func _capture_current() -> void:
	if _transitioning:
		return
	if _state == STATE_LOCATION:
		_capture_location()
	elif _state == STATE_FINAL:
		_capture_final()

func _capture_location() -> void:
	if _transitioning:
		return
	_transitioning = true
	player.lock()
	old_photo.visible = false
	reticle.visible = false
	var photo_tex = _capture_view()
	_captured_photos.append(photo_tex)
	_flash()
	await _show_memory_line(_locations[_location_index]["memory"])
	await _show_book(photo_tex)
	var next_index := _location_index + 1
	if next_index < _locations.size():
		await _transition_to_location(next_index)
	else:
		await _fade_to_black()
		await _enter_final()
	player.unlock()
	_transitioning = false

func _capture_final() -> void:
	if _transitioning:
		return
	_transitioning = true
	player.lock()
	reticle.visible = false
	var photo_tex = _capture_view()
	_captured_photos.append(photo_tex)
	_flash()
	await _show_memory_line("I understood then. The camera was never the point.")
	await _show_book(photo_tex)
	await _fade_to_black()
	_state = STATE_END
	title_label.visible = true
	subtitle_label.visible = true
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.0)

func _get_alignment_data() -> Dictionary:
	var result = {
		"aligned": false,
		"score": 0.0,
		"anchor": null
	}
	if not _current_location:
		return result
	var anchor: Marker3D = _current_location.get_node_or_null("ShotAnchor")
	var target: Marker3D = _current_location.get_node_or_null("ShotTarget")
	if not anchor or not target:
		return result
	var cam: Camera3D = player.camera
	var distance = cam.global_position.distance_to(anchor.global_position)
	var distance_score = clamp(1.0 - (distance / align_distance), 0.0, 1.0)
	var forward = -cam.global_transform.basis.z
	var to_target = (target.global_position - cam.global_position).normalized()
	var angle_cos = forward.dot(to_target)
	var cos_threshold = cos(deg_to_rad(align_angle_degrees))
	var angle_score = clamp((angle_cos - cos_threshold) / (1.0 - cos_threshold), 0.0, 1.0)
	result.aligned = distance <= align_distance and angle_cos >= cos_threshold
	result.score = min(distance_score, angle_score)
	result.anchor = anchor
	return result

func _update_reticle(score: float) -> void:
	var base = Color(0.95, 0.92, 0.86, 0.8)
	var hot = Color(0.7, 0.95, 0.75, 0.9)
	var color = base.lerp(hot, score)
	reticle_h.color = color
	reticle_v.color = color

func _update_old_photo_offset(anchor: Marker3D) -> void:
	var cam: Camera3D = player.camera
	var offset = Vector2(
		clamp((cam.global_position.x - anchor.global_position.x) * 220.0, -60.0, 60.0),
		clamp((cam.global_position.z - anchor.global_position.z) * 220.0, -40.0, 40.0)
	)
	old_photo.position = _old_photo_base_pos + offset

func _show_box_overlay() -> void:
	box_overlay.visible = true
	box_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(box_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.0)
	tween.tween_property(box_overlay, "modulate:a", 0.0, 0.3)
	await tween.finished
	box_overlay.visible = false

func _show_memory_line(text: String) -> void:
	memory_label.text = text
	memory_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(memory_label, "modulate:a", 1.0, 0.6)
	tween.tween_interval(1.6)
	tween.tween_property(memory_label, "modulate:a", 0.0, 0.6)
	await tween.finished

func _show_book(photo_tex: Texture2D) -> void:
	book_photo.texture = photo_tex
	book_panel.visible = true
	book_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(book_panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(0.8)
	tween.tween_property(book_panel, "modulate:a", 0.0, 0.3)
	await tween.finished
	book_panel.visible = false

func _fade_to_black() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.6)
	await tween.finished

func _fade_from_black() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween.finished

func _flash() -> void:
	fade_rect.color = Color(1, 1, 1, 1)
	fade_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.8, 0.06)
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.2)

func _capture_view() -> Texture2D:
	var img = get_viewport().get_texture().get_image()
	img.flip_y()
	return ImageTexture.create_from_image(img)

func _get_overlay_texture(kind: String) -> Texture2D:
	if _overlay_cache.has(kind):
		return _overlay_cache[kind]
	var tex = _make_old_photo(kind)
	_overlay_cache[kind] = tex
	return tex

func _make_old_photo(kind: String) -> Texture2D:
	var w := 640
	var h := 360
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var paper = Color(0.86, 0.8, 0.72, 1)
	var ink = Color(0.55, 0.5, 0.45, 1)
	img.fill(paper)
	_draw_rect(img, 0, 0, w, 6, ink)
	_draw_rect(img, 0, h - 6, w, 6, ink)
	_draw_rect(img, 0, 0, 6, h, ink)
	_draw_rect(img, w - 6, 0, 6, h, ink)
	match kind:
		"fort":
			_draw_rect(img, 120, 130, 110, 120, ink)
			_draw_rect(img, 410, 130, 110, 120, ink)
			_draw_rect(img, 250, 150, 140, 90, ink)
			_draw_rect(img, 300, 185, 40, 55, paper)
		"souk":
			_draw_rect(img, 140, 170, 140, 70, ink)
			_draw_rect(img, 360, 170, 140, 70, ink)
			_draw_rect(img, 110, 140, 420, 20, ink)
		"sea":
			_draw_rect(img, 0, 210, w, 12, ink)
			_draw_rect(img, 280, 190, 80, 30, ink)
		"modern":
			_draw_rect(img, 130, 120, 60, 150, ink)
			_draw_rect(img, 250, 90, 70, 180, ink)
			_draw_rect(img, 360, 130, 80, 140, ink)
		_:
			_draw_rect(img, 200, 140, 240, 120, ink)
	return ImageTexture.create_from_image(img)

func _draw_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var max_x = clamp(x + w, 0, img.get_width())
	var max_y = clamp(y + h, 0, img.get_height())
	var start_x = clamp(x, 0, img.get_width() - 1)
	var start_y = clamp(y, 0, img.get_height() - 1)
	for ix in range(start_x, max_x):
		for iy in range(start_y, max_y):
			img.set_pixel(ix, iy, color)
