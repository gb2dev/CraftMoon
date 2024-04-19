extends Control


const SOUND_MENU = preload("res://sounds/menu.wav")

@export var player_scene: PackedScene
@export var audio_player: AudioStreamPlayer

var peer := ENetMultiplayerPeer.new()


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
	if Input.is_action_just_pressed(&"fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if Input.is_action_just_pressed(&"ui_cancel"):
		for control: Control in get_tree().get_nodes_in_group(&"UI"):
			if control.visible:
				return

		get_tree().paused = not get_tree().paused
		visible = get_tree().paused
		if get_tree().paused:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
			audio_player.stream = SOUND_MENU
			audio_player.play()
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func add_player(id := 1) -> void:
	var player := player_scene.instantiate()
	player.name = str(id)
	get_tree().current_scene.add_child.call_deferred(player)


func _on_join_button_pressed() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	hide()
	peer.create_client("localhost", 7000)
	multiplayer.multiplayer_peer = peer
