extends Node

const SERVER_ADDRESS = "localhost"
const SERVER_PORT = 25565
const MAX_PLAYERS = 10

var players := {}
var player_info := {}

signal player_connected(peer_id: int, player_info: Dictionary)
signal server_disconnected

func _ready() -> void:
	var _error := multiplayer.server_disconnected.connect(_on_connection_failed)
	_error = multiplayer.connection_failed.connect(_on_server_disconnected)
	_error = multiplayer.peer_disconnected.connect(_on_player_disconnected)
	_error = multiplayer.peer_connected.connect(_on_player_connected)
	_error = multiplayer.connected_to_server.connect(_on_connected_ok)

func start_host(nickname: String, skin_color: Color) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var _error := peer.create_server(SERVER_PORT, MAX_PLAYERS)

	multiplayer.multiplayer_peer = peer

	if !nickname:
		nickname = "Player_" + str(multiplayer.get_unique_id())

	player_info["nick"] = nickname
	player_info["skin"] = skin_color

	players[1] = player_info

	player_connected.emit(1, player_info)

	return OK

func join_game(nickname: String, skin_color: Color, address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	if address.is_empty():
		address = SERVER_ADDRESS
	var error := peer.create_client(address, SERVER_PORT)
	if error:
		return error

	multiplayer.multiplayer_peer = peer

	if !nickname:
		nickname = "Player_" + str(multiplayer.get_unique_id())

	player_info["nick"] = nickname
	player_info["skin"] = skin_color

	return OK

func _on_connected_ok() -> void:
	var peer_id := multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_player_connected(id: int) -> void:
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info: Dictionary) -> void:
	var new_player_id := multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

func _on_player_disconnected(id: int) -> void:
	var _existed := players.erase(id)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
