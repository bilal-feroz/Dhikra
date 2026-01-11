extends Control

@onready var join_panel: Panel = $JoinPanel
@onready var status_label: Label = $StatusLabel
@onready var ip_input: LineEdit = $JoinPanel/VBoxContainer/IPInput
@onready var port_input: LineEdit = $JoinPanel/VBoxContainer/PortInput

const DEFAULT_PORT = 7777
const MAX_PLAYERS = 10

func _ready() -> void:
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_single_player_pressed() -> void:
	status_label.text = "Starting single player..."
	get_tree().change_scene_to_file("res://world.tscn")

func _on_host_pressed() -> void:
	status_label.text = "Hosting game..."

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)

	if error != OK:
		status_label.text = "Error: Could not host game!"
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Hosting on port " + str(DEFAULT_PORT)

	# Get local IP
	var local_ip = IP.get_local_addresses()[0]
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			local_ip = ip
			break

	status_label.text = "Hosting on: " + local_ip + ":" + str(DEFAULT_PORT)

	# Wait a moment then start game
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _on_join_pressed() -> void:
	join_panel.visible = true

func _on_connect_pressed() -> void:
	var ip = ip_input.text
	var port = int(port_input.text)

	if port == 0:
		port = DEFAULT_PORT

	status_label.text = "Connecting to " + ip + ":" + str(port) + "..."

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)

	if error != OK:
		status_label.text = "Error: Could not connect!"
		return

	multiplayer.multiplayer_peer = peer

func _on_back_pressed() -> void:
	join_panel.visible = false
	status_label.text = ""

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_peer_connected(id: int) -> void:
	print("Player connected: ", id)
	status_label.text = "Player " + str(id) + " joined!"

func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	status_label.text = "Player " + str(id) + " left!"

func _on_connected_to_server() -> void:
	status_label.text = "Connected! Loading world..."
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	join_panel.visible = false
