extends Node

signal player_spawned(peer_id: int)
signal player_despawned(peer_id: int)

var is_multiplayer := false
var is_host := false

# Track spawned remote players
var remote_players := {}

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

@rpc("any_peer", "call_local")
func spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	print("[Network] Spawning player for peer: ", peer_id)

# Sync player position to all clients
@rpc("any_peer", "unreliable")
func sync_player_position(peer_id: int, pos: Vector2, animation_state: String) -> void:
	if peer_id in remote_players:
		remote_players[peer_id].global_position = pos
		# Update animation state if needed

# Sync player actions (dig, dowse, etc)
@rpc("any_peer", "call_local")
func sync_player_action(peer_id: int, action: String, pos: Vector2) -> void:
	if peer_id in remote_players:
		# Trigger action animation on remote player
		pass
