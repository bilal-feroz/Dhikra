extends CharacterBody2D
class_name Player

const WATER_ADDED_BUFF = preload("res://ui/water_added_buff.tscn")
const FLASK_ADDED_BUFF = preload("res://ui/flask_added_buff.tscn")
const FLASK_USED_BUFF = preload("res://ui/flask_used_buff.tscn")

const COMMENT = preload("res://decorations/comment.tscn")
const FOOTPRINT = preload("res://footprint.tscn")
const DUG_HOLE = preload("res://dug_hole.tscn")
const DOWSING_RIPPLE = preload("res://dowsing_ripple.tscn")
const WATER_SOURCE = preload("res://desert_water_source.tscn")
const RAIN_EFFECT = preload("res://cloud_rain_effect.tscn")

const PLAYER_HAS_SHOVEL = preload("res://sprites/player/player.png")
const PLAYER_NO_TOOL = preload("res://sprites/player/player_notool.png")

const ACCEL := 100.0
const MAX_SPEED := 80.0
const RUN_SPEED := 140.0

@export var is_remote_player := false
@export var remote_player_id := ""
var remote_old_position := Vector2.ZERO
var remote_pos_interp := 1.0
var remote_time_normalization := 1.0
var remote_first_move := true
var remote_tweener: Tween = null
var remote_queued_actions: Array[Playroom.PlayerActionData] = []
var remote_active_action: Playroom.PlayerActionData = null
var remote_perform_task: Array[String] = []
var last_received_bundle: Array[Playroom.PlayerActionData] = []

# indicator if the player's position should be sent out
@export var player_broadcast_ready := true
@export var player_needs_action_broadcast := true
@export var player_last_broadcast := Vector2(-99999, -99999)

@onready var zone_detector: Area2D = $ZoneDetector
@onready var shade_detector: Area2D = $ShadeDetector
@onready var power_up_detector: Area2D = $PowerUpDetector
@onready var dialog_detector: Area2D = $DialogDetector
@onready var dust_storm_detector: Area2D = $DustStormDetector
@onready var rain_detector: Area2D = $RainDetector
@onready var broadcast_position_timer: Timer = $BroadcastPositionTimer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var camera_2d: Camera2D = $Camera2D
@onready var sprite_2d: Sprite2D = $Sprite2D


# Spots to drop footprints at
# Can't use left/right foot as its not obvious from animations
@onready var east_side: Marker2D = $EastSide
@onready var west_side: Marker2D = $WestSide

@onready var west_dig: Marker2D = $WestDig
@onready var east_dig: Marker2D = $EastDig

#Where should we spawn buffs at above the player
@onready var buff_start: Marker2D = $BuffStart

#Where should the comment spawn at
@onready var comment_place: Marker2D = $CommentPlace


@onready var animation_tree: AnimationTree = $AnimationTree

@onready var sand_step: AudioStreamPlayer2D = $SandFootstep
@onready var sand_digging: AudioStreamPlayer2D = $SandDigging

@onready var grass_step: AudioStreamPlayer2D = $GrassFootstep
@onready var grass_digging: AudioStreamPlayer2D = $GrassDigging

@onready var sigh_and_breath: AudioStreamPlayer2D = $SighAndBreath
@onready var last_sigh: AudioStreamPlayer2D = $LastSigh

@onready var sfx_dowsing: AudioStreamPlayer2D = $Dowsing

@onready var water_refill: AudioStreamPlayer2D = $WaterRefill

@onready var gulping: AudioStreamPlayer2D = $Gulping

@onready var pickup: AudioStreamPlayer2D = $Pickup

@onready var write: AudioStreamPlayer2D = $Writing

var speed := MAX_SPEED

var last_active_direction := Vector2.DOWN
@export var idling := false
@export var digging := false
@export var dowsing := false
@export var writing := false
@export var raining := false
@export var running := false
@export var exhausted := false
@export var dead := false
@export var disconnected := false #only applies to remote players
@export var invulnerable := false
@export var infinite_water := false

var has_shovel := false

# Water system
var current_water := 100.0
var water_buffs := 0.0

# Cloud rain ability
var rain_uses_remaining: int = 3
var unused_flasks := 0
var total_flasks := 0
var in_oasis := 0
var in_shade := 0 # Needs to be a counter because there may be overlaps
var in_dust_storm := 0  # Counter for overlapping dust storms
var in_rain := 0  # Counter for overlapping rain zones

var current_dialog: SpeechDetector = null

var recent_dhikra: Dhikra = null

var recent_comments: Array[Comment] = []
var recent_comment_idx: int = -1

var recent_footprints: Array[Vector2] = []

var dust_storm_overlay: ColorRect = null
var dust_storm_canvas: CanvasLayer = null

func _ready() -> void:
	animation_tree.active = true

	reset_state()

	# Add to players group so dust storm spawner can find us
	if not is_remote_player:
		add_to_group("players")
		add_to_group("local_player")  # For LAN multiplayer spawning

	# Create fullscreen dust storm overlay
	if not is_remote_player:
		dust_storm_canvas = CanvasLayer.new()
		dust_storm_canvas.layer = 100  # On top of everything
		add_child(dust_storm_canvas)

		dust_storm_overlay = ColorRect.new()
		dust_storm_overlay.color = Color(0.7, 0.6, 0.4, 0.0)  # Start invisible
		dust_storm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		dust_storm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dust_storm_canvas.add_child(dust_storm_overlay)

	if is_remote_player:
		camera_2d.enabled = false
	else:
		WorldManager.game_started.emit()

	if not is_remote_player:
		Playroom.server_connected.connect(_on_server_connected)
		WorldManager.player_respawn.connect(_on_respawn_requested)
		WorldManager.ui_active.connect(_on_ui_active)
		WorldManager.player_finished_writing.connect(_finish_writing_comment)
	
	broadcast_position_timer.timeout.connect(_on_broadcast_timeout)
	
	zone_detector.area_entered.connect(_on_zone_entered)
	zone_detector.area_exited.connect(_on_zone_exited)
	
	shade_detector.area_entered.connect(_on_shade_entered)
	shade_detector.area_exited.connect(_on_shade_exited)

	dust_storm_detector.area_entered.connect(_on_dust_storm_entered)
	dust_storm_detector.area_exited.connect(_on_dust_storm_exited)

	rain_detector.area_entered.connect(_on_rain_entered)
	rain_detector.area_exited.connect(_on_rain_exited)

	dialog_detector.area_entered.connect(_on_dialog_entered)
	dialog_detector.area_exited.connect(_on_dialog_exited)
	
	power_up_detector.area_entered.connect(_on_power_up_entered)

func reset_state() -> void:
	if is_remote_player:
		modulate = Color(0.4, 0.4, 1.0, 0.8)
		# Don't allow the main player to collide with
		# the remote proxy players
		collision_layer = 0
		collision_mask = 0
	
	current_water = 100.0
	unused_flasks = total_flasks
	in_oasis = 0
	in_shade = 0
	in_rain = 0
	dead = false
	exhausted = false
	idling = false
	digging = false
	dowsing = false
	writing = false
	last_active_direction = Vector2.DOWN
	speed = MAX_SPEED
	
	if not is_remote_player:
		WorldManager.player_flask_changed.emit(
			unused_flasks,
			total_flasks
		)
		WorldManager.player_water_changed.emit(
			current_water,
			0.0,
			3
		)
		
		WorldManager.player_idle.emit(false)

func _physics_process(delta: float) -> void:
	
	if dead:
		# Check to see if the remote player has revived
		if is_remote_player:
			# get input data from their state
			_get_player_movement_input(delta)
			# check if they have any actions
			_check_player_actions()
			# TODO: consider using movement as a sign they are respawned anyways
			# TODO: may have missed an update
		return

	# Apply dust storm visual effect - fullscreen overlay
	if dust_storm_overlay:
		if in_dust_storm > 0:
			sprite_2d.modulate = Color(0.7, 0.6, 0.5, 1.0)  # Brownish tint
			# Fade in screen overlay
			dust_storm_overlay.color.a = lerpf(dust_storm_overlay.color.a, 0.5, delta * 3.0)
		elif in_rain > 0:
			sprite_2d.modulate = Color(0.7, 0.8, 1.0, 1.0)  # Bluish tint when in rain
			# Fade out screen overlay
			dust_storm_overlay.color.a = lerpf(dust_storm_overlay.color.a, 0.0, delta * 3.0)
		else:
			sprite_2d.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal color
			# Fade out screen overlay
			dust_storm_overlay.color.a = lerpf(dust_storm_overlay.color.a, 0.0, delta * 3.0)

	# Always calculate water drain while we are alive
	_process_water_drain(delta)

	# prevent moving while digging/dowsing/writing
	if digging or dowsing or writing or raining:
		return
	
	# Don't move while invulnerable (UI menus)
	if invulnerable:
		return

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := _get_player_movement_input(delta)
	
	if direction:
		# If we were previously idling
		if not idling and not is_remote_player:
			WorldManager.player_idle.emit(false)

		idling = false
		last_active_direction = direction

		# Check if running (shift held)
		if not is_remote_player and Input.is_action_pressed("player_run"):
			running = true
			speed = RUN_SPEED
		else:
			running = false
			speed = MAX_SPEED

		velocity = direction * speed
	else:
		# If we weren't previously idling
		if not idling and not is_remote_player:
			WorldManager.player_idle.emit(true)
		idling = true
		running = false
		velocity = Vector2.ZERO
		
	

	if idling:
		animation_tree["parameters/Idle/Exhausted/blend_position"] = last_active_direction
		animation_tree["parameters/Idle/Idle/blend_position"] = last_active_direction
	else:
		animation_tree["parameters/Movement/blend_position"] = direction
	
	_check_player_actions()

	# Only the local player will move with physics
	if not is_remote_player:
		move_and_slide()

		# Broadcast position for LAN multiplayer
		if NetworkManager.is_multiplayer:
			NetworkManager.broadcast_position(global_position, velocity)

	var can_broadcast := player_broadcast_ready and \
				not player_last_broadcast.is_equal_approx(position)

	if not is_remote_player and (player_needs_action_broadcast or can_broadcast):
		player_needs_action_broadcast = false
		player_broadcast_ready = false
		player_last_broadcast = position
		Playroom.update_my_pos(position)


func _get_player_movement_input(delta: float) -> Vector2:
	if is_remote_player:
		return _handle_remote_player_actions(delta)
	else:
		var player_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		player_input = player_input.normalized()
		return player_input

func _check_player_actions() -> void:
	if is_remote_player:
		
		# Check to see if they got the shovel upgrade
		if not has_shovel and \
				Playroom.get_player_upgrade(remote_player_id, Playroom.UPGRADE_SHOVEL):
			_show_shovel()
			
		# Perform task will only be set for a moment, and then is cleared after this check
		var action: Variant = remote_perform_task.pop_front()
		if action == null or action == Playroom.ACTION_NONE:
			return
		
		print("[Player] Remote player performing: ", action)
		
		if action == Playroom.ACTION_DIGGING:
			animation_tree["parameters/Digging/blend_position"] = last_active_direction.x
			digging = true
			return
		elif action == Playroom.ACTION_WRITING:
			writing = true
			return
		elif action == Playroom.ACTION_DOWSING:
			dowsing = true
			return
		elif action == Playroom.ACTION_RAIN:
			raining = true
			_anim_rain_started()
			return
		elif action == Playroom.ACTION_DIED:
			die()
			if remote_tweener != null:
				remote_tweener.kill()
			remote_tweener = create_tween()
			# Fade out at the same rate the death animation occurs
			remote_tweener.tween_property(self, "modulate:a", 0.0, 0.8)
			return
		elif action == Playroom.ACTION_RESPAWN:
			dead = false
			
			# Fade back in with the respawn
			if remote_tweener != null:
				remote_tweener.kill()
			remote_tweener = create_tween()
			# Fade out at the same rate the death animation occurs
			remote_tweener.tween_property(self, "modulate:a", 1.0, 0.8)
			
			return
		
	else:
		# if in a dialog zone, "E" is overridden to advance dialog
		if current_dialog != null and Input.is_action_just_pressed("player_dig"):
			current_dialog.advance()
			return
		elif has_shovel and Input.is_action_just_pressed("player_dig"):
			# Don't dig if standing on a water source - let the water source handle the interaction
			var water_sources = get_tree().get_nodes_in_group("water_sources")
			var on_water_source = false
			for source in water_sources:
				if source is DesertWaterSource:
					var distance = global_position.distance_to(source.global_position)
					if distance < 25.0 and source.is_available:
						on_water_source = true
						break

			if not on_water_source:
				animation_tree["parameters/Digging/blend_position"] = last_active_direction.x
				digging = true
				Playroom.set_player_action(Playroom.ACTION_DIGGING, global_position)
				player_needs_action_broadcast = true
			return
		elif has_shovel and Input.is_action_just_pressed("player_dowse"):
			dowsing = true
			Playroom.set_player_action(Playroom.ACTION_DOWSING, global_position)
			player_needs_action_broadcast = true
			return
		elif Input.is_action_just_pressed("player_write"):
			writing = true
			Playroom.set_player_action(Playroom.ACTION_WRITING, global_position)
			player_needs_action_broadcast = true
			return
		elif Input.is_action_just_pressed("player_rain") and rain_uses_remaining > 0:
			# Find nearby clouds
			var nearest_cloud = _find_nearest_cloud()
			if nearest_cloud != null:
				raining = true
				rain_uses_remaining -= 1
				# Get rain position from cloud
				var rain_position = nearest_cloud.make_it_rain()
				Playroom.set_player_action(Playroom.ACTION_RAIN, rain_position)
				player_needs_action_broadcast = true
				_anim_rain_started(rain_position)  # Pass cloud position for rain
			return

func die() -> void:
	dead = true
	
	last_sigh.play()
	
	if not is_remote_player:
		WorldManager.player_died.emit(position)
		Playroom.set_player_action(Playroom.ACTION_DIED, global_position)
		Playroom.add_death_location(position, recent_footprints)
	else:
		# do nothing for remote player until they respawn
		pass

func remote_left() -> void:
	die()
	
	if remote_tweener != null:
		remote_tweener.kill()
	
	remote_tweener = create_tween()
	remote_tweener.tween_property(self, "modulate:a", 0.0, 0.8*5)
	remote_tweener.tween_callback(queue_free)
	

func _process_water_drain(delta: float) -> void:
	if is_remote_player:
		return
	
	# Useful when in escape menu or dialogs
	# to prevent player water draining
	if invulnerable or infinite_water:
		return
	
	# Start with a base of -1.0 for the heat burning you (reduced from -3.0 for better survival)
	# Milestone 1: Apply time-of-day multiplier (night = slower drain)
	var time_mult := 1.0
	if TimeManager:
		time_mult = TimeManager.get_drain_multiplier()

	var intensity := -1.0 * time_mult

	if in_oasis > 0:
		intensity = 3  # Oasis always heals at full rate

	# Add booster from being in the shade
	intensity += in_shade

	# Add slow water replenishment from rain (slower than oasis but helpful)
	if in_rain > 0:
		intensity += 1.5  # Gives water slowly when standing in rain
		print("[Rain Debug] In rain! intensity = ", intensity)

	# Apply dust storm penalty (3x water drain)
	if in_dust_storm > 0:
		intensity = intensity * 3.0

	# If we are outside the oasis and not in rain
	# don't allow shade boosting to make us positive (healing)
	if in_oasis <= 0 and in_rain <= 0:
		# outside of an oasis or rain you can't heal so no positive values allowed
		intensity = min(0, intensity)
	
	# One flask should recharge in only 3 seconds of oasis time
	const FLASK_RECHARGE_TIME = 100.0 / (3.0 * 3)
	
	# One flask (100.0) should equal roughly 20 seconds of -3 drain
	const DRAIN_TIME_PER_FLASK = 100.0 / (20.0 * 3)
	
	var water_change := delta * DRAIN_TIME_PER_FLASK * intensity
	
	# if we ate cactus flowers or tapped a water hole
	# add in those buffs now
	if water_buffs > 0:
		water_change += water_buffs
		water_buffs = 0

		var buffed := WATER_ADDED_BUFF.instantiate()
		buffed.position = buff_start.position
		add_child(buffed)

		# Blue flash feedback for water gain
		_water_pickup_flash()
	
	current_water += water_change
	
	# If our water dropped below zero,
	# auto use a flask if available
	if current_water <= 0 and unused_flasks > 0:
		current_water += 100.0
		unused_flasks -= 1
		gulping.play()
		WorldManager.player_flask_changed.emit(
			unused_flasks,
			total_flasks
		)

		var buffed := FLASK_USED_BUFF.instantiate()
		buffed.position = buff_start.position
		add_child(buffed)

		# Camera shake feedback for flask use
		_camera_shake(0.15, 3.0)
		
	
	# Check if we can recharge flasks while in an oasis
	var empty_flasks := total_flasks - unused_flasks
	if in_oasis > 0 and \
			current_water >= (100.0 + FLASK_RECHARGE_TIME) and \
			empty_flasks > 0:
		unused_flasks += 1
		unused_flasks = mini(unused_flasks, total_flasks)
		current_water = 100.0
		WorldManager.player_flask_changed.emit(
			unused_flasks,
			total_flasks
		)
		
		var buffed := FLASK_ADDED_BUFF.instantiate()
		buffed.position = buff_start.position
		add_child(buffed)
	elif empty_flasks == 0:
		current_water = minf(current_water, 100.0)
		
	
	# Clamp the water to be within range
	current_water = maxf(current_water, 0.0)
	
	if int(current_water) < 100 && int(current_water) % 20 == 0 && !sigh_and_breath.playing:
		sigh_and_breath.play()
	
	# if our water is still below zero,
	# we died
	if current_water <= 0.0:
		die()
	
	WorldManager.player_water_changed.emit(
		current_water,
		water_change,
		intensity
	)
	
func _on_broadcast_timeout() -> void:
	player_broadcast_ready = true

func _on_zone_entered(body: Area2D) -> void:
	if is_remote_player:
		return
	
	if body is Dhikra:
		if in_oasis == 0:
			WorldManager.oasis_entered.emit()
			
		in_oasis += 1
		recent_dhikra = body
	
	if in_oasis > 0:
		WorldManager.player_water_changed.emit(
			current_water,
			0.0,
			3
		)


func _on_zone_exited(body: Area2D) -> void:
	if is_remote_player:
		return
	
	if body is Dhikra:
		in_oasis -= 1
		if in_oasis <= 0:
			WorldManager.oasis_left.emit()
	
	in_oasis = maxi(in_oasis, 0)

func _on_shade_entered(body: Area2D) -> void:
	if is_remote_player:
		return
		
	if body is ShadeValue:
		in_shade += body.shade_value
	else:
		in_shade += 1
	
func _on_shade_exited(body: Area2D) -> void:
	if is_remote_player:
		return

	if body is ShadeValue:
		in_shade -= body.shade_value
	else:
		in_shade -= 1

	in_shade = maxi(in_shade, 0)

func _on_dust_storm_entered(body: Area2D) -> void:
	if is_remote_player:
		return

	if body is DustStormZone:
		in_dust_storm += 1
		# Shake camera when entering storm
		_camera_shake(0.3, 5.0)

func _on_dust_storm_exited(body: Area2D) -> void:
	if is_remote_player:
		return

	if body is DustStormZone:
		in_dust_storm -= 1
		in_dust_storm = maxi(in_dust_storm, 0)

func _on_rain_entered(body: Area2D) -> void:
	if is_remote_player:
		return

	print("[Rain Debug] Rain entered signal received from: ", body.name, " Groups: ", body.get_groups())

	# Check if we entered a rain zone
	if body.is_in_group("rain_zones"):
		in_rain += 1
		print("[Rain Debug] Now in rain! in_rain = ", in_rain)

func _on_rain_exited(body: Area2D) -> void:
	if is_remote_player:
		return

	# Check if we left a rain zone
	if body.is_in_group("rain_zones"):
		in_rain -= 1
		in_rain = maxi(in_rain, 0)

func _on_dialog_entered(body: Area2D) -> void:
	if is_remote_player:
		return
	
	if body is SpeechDetector:
		current_dialog = body
	WorldManager.player_dialog.emit(true)
	
	
func _on_dialog_exited(body: Area2D) -> void:
	if is_remote_player:
		return
	
	if body is SpeechDetector:
		current_dialog = null
	WorldManager.player_dialog.emit(false)

func _on_power_up_entered(body: Area2D) -> void:
	if is_remote_player:
		return
	
	if body is FlaskPowerUp and not body.consumed:
		total_flasks += 1
		unused_flasks += 1
		pickup.play()
		WorldManager.player_flask_changed.emit(
			unused_flasks,
			total_flasks
		)
		WorldManager.player_upgraded.emit(
			Playroom.UPGRADE_FLASK
		)
		var buffed := FLASK_ADDED_BUFF.instantiate()
		buffed.position = buff_start.position
		add_child(buffed)
		
		body.consume()
	elif body is ShovelPowerUp and not body.consumed:
		pickup.play()
		Playroom.set_player_upgrade(Playroom.UPGRADE_SHOVEL)
		_show_shovel()
		body.consume()
	else:
		var parent := body.get_parent()
		if parent is Cactus and not parent.consumed:
			gulping.play()
			var flowers: int = parent.consume()
			var buffed := WATER_ADDED_BUFF.instantiate()
			buffed.position = buff_start.position
			add_child(buffed)
			water_buffs += float(flowers) * 10.0

func _on_respawn_requested() -> void:
	if is_remote_player:
		return
	
	if recent_dhikra != null:
		global_position = recent_dhikra.player_respawn.global_position
		reset_state()
		dead = false
		Playroom.set_player_action(Playroom.ACTION_RESPAWN, global_position)
		# force a resend
		player_needs_action_broadcast = true

func _on_ui_active(showing: bool) -> void:
	invulnerable = showing

func _anim_dig_hole(spawn_west: bool) -> void:
	
	if in_oasis > 0:
		grass_digging.play()
	else:
		sand_digging.play()
		
	var hole := DUG_HOLE.instantiate()
	if spawn_west:
		hole.global_position = west_dig.global_position
	else:
		hole.global_position = east_dig.global_position

	get_parent().add_child(hole)
	
	# Check if the digging caused anything to activate
	# that was hidden underground
	for item in power_up_detector.get_overlapping_areas():
		if item is WaterHolePowerUp and not item.consumed:
			item.consume()
			
			# Immediately add a lot of water to the player
			water_buffs += 30.0
			
			water_refill.play()
			 

func _anim_place_footprint(spawn_west: bool) -> void:
	var spawn_point := Vector2.ZERO
	if spawn_west:
		spawn_point = west_side.global_position
	else:
		spawn_point = east_side.global_position
	
	# check if this footprint is too close to the other
	const TOO_CLOSE_FOOTPRINT = 10.0 # world coord distance
	if len(recent_footprints) > 0 and \
			spawn_point.distance_to(recent_footprints.back()) < TOO_CLOSE_FOOTPRINT:
		return
	
	var footprint := FOOTPRINT.instantiate()
	footprint.global_position = spawn_point
	get_parent().add_child(footprint)
	
	if in_oasis > 0:
		grass_step.play()
	else:
		sand_step.play()
	
	recent_footprints.push_back(Vector2(footprint.global_position.x, footprint.global_position.y))
	
	while recent_footprints.size() > Playroom.MAX_FOOTPRINTS_STORED:
		recent_footprints.pop_front()

func _anim_player_death_finished() -> void:
	if not is_remote_player:
		WorldManager.player_waiting_respawn.emit(position)


func _anim_player_dowsing_started() -> void:
	if not is_remote_player:
		sfx_dowsing.play()
		
		var ripple := DOWSING_RIPPLE.instantiate()
		ripple.position = global_position
		get_parent().add_child(ripple)

func _anim_start_writing() -> void:
	write.play()

func _anim_place_comment() -> void:
	if not is_remote_player:
		WorldManager.player_started_writing.emit()

func _find_nearest_cloud():
	# Find all clouds in the scene
	var clouds = get_tree().get_nodes_in_group("clouds")
	var nearest_cloud = null
	var nearest_distance = 500.0  # Max detection range for clouds (increased from 300 to 500)

	for cloud in clouds:
		# Skip clouds that have already rained
		if cloud.has_rained:
			continue

		var distance = global_position.distance_to(cloud.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_cloud = cloud

	return nearest_cloud

func _anim_rain_started(rain_position: Vector2 = Vector2.ZERO) -> void:
	if not is_remote_player:
		# If no position provided (remote player), skip spawning
		if rain_position == Vector2.ZERO:
			raining = false
			return

		# Spawn visual rain effect at the cloud position (100 units above rain position)
		var rain_effect = RAIN_EFFECT.instantiate()
		rain_effect.global_position = rain_position + Vector2(0, -100)
		get_parent().add_child(rain_effect)

		# Play water sound effect (reuse water refill sound)
		water_refill.play()

		# Reset raining state after short delay
		raining = false

func _finish_writing_comment(phrase: int, word: int) -> void:
	recent_comment_idx = (recent_comment_idx + 1) % Playroom.MAX_PLAYER_INSCRIPTIONS
	
	if recent_comment_idx < len(recent_comments):
		recent_comments[recent_comment_idx].clear_out()
		
	var comment := COMMENT.instantiate()
	comment.phrase = phrase
	comment.word = word
	comment.position = comment_place.global_position
	get_parent().add_child(comment)
	
	if recent_comment_idx < len(recent_comments):
		recent_comments[recent_comment_idx] = comment
	else:
		recent_comments.push_back(comment)
	
	Playroom.add_inscription(comment_place.global_position, phrase, word)

func _show_shovel() -> void:
	has_shovel = true
	sprite_2d.texture = PLAYER_HAS_SHOVEL
	
	if not is_remote_player:
		WorldManager.player_upgraded.emit(Playroom.UPGRADE_SHOVEL)

func _consume_remote_action() -> void:
	if not remote_active_action.action_consumed:
		remote_active_action.action_consumed = true
		
		print("Consuming action: ", remote_active_action.action)
		
		# these are noop actions, don't bother pushing into the action queue
		if remote_active_action.action == Playroom.ACTION_NONE:
			return
		elif remote_active_action.action == Playroom.ACTION_MOVE:
			
			# If we see movement while dead, assume they respawned as a safety measure
			if dead and len(remote_perform_task) == 0:
				remote_perform_task.push_back(Playroom.ACTION_RESPAWN)
			
			return
		
		
		remote_perform_task.push_back(remote_active_action.action)
	
func _handle_remote_player_actions(delta: float) -> Vector2:
	
	# Try to fetch more actions if we have flushed our current queue
	if len(remote_queued_actions) == 0:
		# this always represents 1 second of queued actions 
		# If the player isn't moving, this will be unchanged
		var new_remote_actions := Playroom.get_other_player_position(remote_player_id)
		
		var fresh_actions := true
		# If the bundles are the same size, check if they have the same content
		# it is possible new state hasn't arrived yet
		if len(new_remote_actions) == len(last_received_bundle):
			var unique_actions := 0
			for i in range(len(new_remote_actions)):
				var last_action := last_received_bundle[i]
				var new_action  := new_remote_actions[i]
				if new_action.action != last_action.action or \
						not new_action.position.is_equal_approx(last_action.position):
					unique_actions += 1
			fresh_actions = unique_actions > 0
			
		if fresh_actions:
			last_received_bundle = new_remote_actions
			for action in new_remote_actions:
				print("Recv: ", action.action, " @ ", action.position)
				remote_queued_actions.push_back(action)
	
	# If we have finished processing all active actions
	# and dont have anything else to do, just sit still
	if len(remote_queued_actions) == 0 and is_equal_approx(remote_pos_interp, 1.0):
		return Vector2.ZERO
	elif remote_active_action == null and len(remote_queued_actions) == 0:
		return Vector2.ZERO

	# If we have finished the previous action
	# pop a new action off the queue and start handling it
	if is_equal_approx(remote_pos_interp, 1.0):
		if remote_active_action != null:
			remote_old_position = remote_active_action.position
			_consume_remote_action()
		
		# guaranteed to have something here
		remote_active_action = remote_queued_actions.pop_front()
		
		# reset our interpolation
		remote_pos_interp = 0.0
		
		# How long in seconds to get from one spot to the next based on a player's MAX_SPEED
		# delta should be normalized by this to get the right speed
		# normal updates should arrive once a second
		remote_time_normalization = min(1.0, (remote_active_action.position.distance_to(remote_old_position)) / (MAX_SPEED*0.9))
		
		# Check if a respawn happened, we need to handle that immediately
		if remote_first_move or remote_active_action.action == Playroom.ACTION_RESPAWN:
			remote_first_move = false
			position = remote_active_action.position
			remote_old_position = remote_active_action.position
			remote_pos_interp = 1.0
			_consume_remote_action()
			return Vector2.ZERO

		# if we are too far behind, 
		# snap our position to the beginning of the interp
		if position.distance_squared_to(remote_old_position) > (10.0 * 10.0):
			position = remote_old_position

	var new_desired_position: Vector2 = \
		lerp(remote_old_position, remote_active_action.position, remote_pos_interp)
	remote_pos_interp += delta / remote_time_normalization
	remote_pos_interp = minf(remote_pos_interp, 1.0)
	
	# If we reached the end of the segment, activate the action that
	# was suppose to occur there
	if is_equal_approx(remote_pos_interp, 1.0) and \
			not remote_active_action.action_consumed:
		_consume_remote_action()
	
	# Stop the player's movement (animation)
	# only if they have reached the destination and we know
	# their broadcast should have occurred already
	if (position.is_equal_approx(remote_active_action.position) \
				and player_broadcast_ready):
		return Vector2.ZERO

	# Otherwise update position and point the player in that animated direction
	position = new_desired_position
	return position.direction_to(remote_active_action.position)

func _on_server_connected(_room: String) -> void:
	if is_remote_player:
		return
	player_needs_action_broadcast = true


func _camera_shake(duration: float, intensity: float) -> void:
	if is_remote_player or not camera_2d:
		return
	var shake_tween := create_tween()
	var shake_count := int(duration / 0.05)
	for i in range(shake_count):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(camera_2d, "offset", offset, 0.05)
	shake_tween.tween_property(camera_2d, "offset", Vector2.ZERO, 0.05)


func _water_pickup_flash() -> void:
	if is_remote_player:
		return
	# Brief blue tint on sprite when picking up water
	var original_modulate := sprite_2d.modulate
	sprite_2d.modulate = Color(0.7, 0.9, 1.3, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite_2d, "modulate", original_modulate, 0.3)
