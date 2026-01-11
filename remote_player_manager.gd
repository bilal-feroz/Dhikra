extends Node2D

const PLAYER = preload("res://player.tscn")

# Player Name -> Player Object
var player_lookups: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Playroom.io multiplayer
	Playroom.player_joined.connect(_on_player_joined)
	Playroom.player_left.connect(_on_player_left)

	# LAN multiplayer
	if NetworkManager.is_multiplayer:
		NetworkManager.player_spawned.connect(_on_lan_player_spawned)
		NetworkManager.player_despawned.connect(_on_lan_player_despawned)

		# If we're the client (not host), spawn a remote player for the host
		if not multiplayer.is_server():
			_spawn_lan_player(1)  # Server is always peer ID 1

		# If we're the host, spawn remote players for any connected clients
		if multiplayer.is_server():
			for peer_id in multiplayer.get_peers():
				_spawn_lan_player(peer_id)

func _on_player_joined(_room: String, player: String) -> void:
	if player == Playroom.whoami():
		return

	if player not in player_lookups:
		print("Player joined the game: ", player)
		var spawn := PLAYER.instantiate() as Player
		spawn.is_remote_player = true
		spawn.remote_player_id = player
		add_child(spawn)

		player_lookups[player] = spawn

func _on_player_left(_room: String, player: String) -> void:
	if player in player_lookups:
		print("Player left the game: ", player)
		player_lookups[player].remote_left()
		player_lookups.erase(player)

# LAN multiplayer handlers
func _on_lan_player_spawned(peer_id: int) -> void:
	print("[RemotePlayerManager] Spawning LAN player: ", peer_id)
	_spawn_lan_player(peer_id)

func _on_lan_player_despawned(peer_id: int) -> void:
	print("[RemotePlayerManager] Despawning LAN player: ", peer_id)
	var player_key = "lan_" + str(peer_id)
	if player_key in player_lookups:
		player_lookups[player_key].remote_left()
		player_lookups.erase(player_key)

	if peer_id in NetworkManager.remote_players:
		NetworkManager.remote_players.erase(peer_id)

func _spawn_lan_player(peer_id: int) -> void:
	# Don't spawn ourselves
	if peer_id == multiplayer.get_unique_id():
		return

	var player_key = "lan_" + str(peer_id)

	# Don't spawn if already exists
	if player_key in player_lookups:
		return

	print("[RemotePlayerManager] Creating remote player for peer: ", peer_id)
	var spawn := PLAYER.instantiate() as Player
	spawn.is_remote_player = true
	spawn.remote_player_id = str(peer_id)
	spawn.name = "RemotePlayer_" + str(peer_id)

	# Position remote player at spawn
	var local_player = get_tree().get_first_node_in_group("local_player")
	if local_player:
		spawn.global_position = local_player.global_position
	else:
		# Default spawn position if no local player found
		spawn.global_position = Vector2(35, -29)

	add_child(spawn)
	player_lookups[player_key] = spawn
	NetworkManager.remote_players[peer_id] = spawn
	print("[RemotePlayerManager] Remote player added to scene: ", peer_id)
