extends CanvasLayer

signal switch_menu()
signal show_instructions()

@onready var start: TextureButton = $Options/Start
@onready var settings: TextureButton = $Options/Settings
@onready var multiplayer_btn: TextureButton = $Options/Multiplayer

@onready var multiplayer_panel: ColorRect = $MultiplayerPanel
@onready var status_label: Label = $StatusLabel/Label
@onready var ip_input: LineEdit = $MultiplayerPanel/VBoxContainer/IPInput
@onready var port_input: LineEdit = $MultiplayerPanel/VBoxContainer/PortInput
@onready var host_btn: Button = $MultiplayerPanel/VBoxContainer/HostButton
@onready var join_btn: Button = $MultiplayerPanel/VBoxContainer/JoinButton
@onready var back_btn: Button = $MultiplayerPanel/VBoxContainer/BackButton

@onready var sfx_ui: AudioStreamPlayer = $"../SFX UI"

const DEFAULT_PORT = 7777
const MAX_PLAYERS = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	grab()

	start.pressed.connect(_on_start)
	settings.pressed.connect(_on_settings)
	multiplayer_btn.pressed.connect(_on_multiplayer)

	# Multiplayer panel buttons
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	# Multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func grab() -> void:
	start.grab_focus()

func _on_start() -> void:
	print("Start pressed")
	sfx_ui.play()
	show_instructions.emit()

func _on_settings() -> void:
	print("Settings pressed")
	sfx_ui.play()
	switch_menu.emit()

func _on_multiplayer() -> void:
	print("Multiplayer pressed")
	sfx_ui.play()
	multiplayer_panel.visible = true

func _on_host_pressed() -> void:
	status_label.text = "Hosting game..."

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)

	if error != OK:
		status_label.text = "Error: Could not host game!"
		return

	multiplayer.multiplayer_peer = peer
	NetworkManager.setup_multiplayer(true)

	# Get local IP
	var local_ip = IP.get_local_addresses()[0]
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			local_ip = ip
			break

	status_label.text = "Hosting on: " + local_ip + ":" + str(DEFAULT_PORT) + "\nWaiting for other player..."

	# Disable host/join buttons while waiting
	host_btn.disabled = true
	join_btn.disabled = true

func _on_join_pressed() -> void:
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
	NetworkManager.setup_multiplayer(false)

	# Disable buttons while connecting
	host_btn.disabled = true
	join_btn.disabled = true

func _on_back_pressed() -> void:
	multiplayer_panel.visible = false
	status_label.text = ""

	# Re-enable buttons and disconnect if connected
	host_btn.disabled = false
	join_btn.disabled = false

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	print("Player connected: ", id)
	status_label.text = "Player " + str(id) + " joined! Starting game..."

	# Both players start the game
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	status_label.text = "Player " + str(id) + " left!"

func _on_connected_to_server() -> void:
	status_label.text = "Connected! Loading world..."
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"

	# Re-enable buttons
	host_btn.disabled = false
	join_btn.disabled = false

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
