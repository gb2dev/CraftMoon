extends Control


var peer := ENetMultiplayerPeer.new()
@export var player_scene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	hide()
	peer.create_server(7000, 8)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	add_player()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func add_player(id := 1) -> void:
	var player := player_scene.instantiate()
	player.name = str(id)
	get_tree().current_scene.add_child.call_deferred(player)


func _on_join_button_pressed() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	hide()
	peer.create_client("localhost", 7000)
	multiplayer.multiplayer_peer = peer
