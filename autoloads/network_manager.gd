extends Node

signal player_spawned(peer_id: int)
signal player_despawned(peer_id: int)

var is_multiplayer := false
var is_host := false

# Track spawned remote players
var remote_players := {}

# Local player reference (set by player when ready)
var local_player = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func setup_multiplayer(hosting: bool) -> void:
	is_multiplayer = true
	is_host = hosting
	print("[Network] Multiplayer mode: ", "Host" if is_host else "Client")

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connected: ", id)
	player_spawned.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer disconnected: ", id)
	player_despawned.emit(id)

	# Clean up remote player
	if id in remote_players:
		remote_players[id].queue_free()
		remote_players.erase(id)

# Called by local player to broadcast position to all peers
func broadcast_position(pos: Vector2, velocity: Vector2) -> void:
	if not is_multiplayer:
		return

	# Send to all other peers
	rpc("sync_player_position", multiplayer.get_unique_id(), pos, velocity)

# Receive position updates from other players
@rpc("any_peer", "unreliable")
func sync_player_position(peer_id: int, pos: Vector2, vel: Vector2) -> void:
	# Don't apply to ourselves
	if peer_id == multiplayer.get_unique_id():
		return

	if peer_id in remote_players:
		remote_players[peer_id].global_position = pos
		# Set velocity for animation
		if vel.length() > 0:
			remote_players[peer_id].last_active_direction = vel.normalized()
			remote_players[peer_id].idling = false
		else:
			remote_players[peer_id].idling = true
