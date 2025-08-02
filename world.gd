class_name World
extends Node3D


signal skin_changed(color: Color)

static var time_paused := true
static var destroyed_nodes: Dictionary[Node, Node]

@export var player_scene: PackedScene
@export var credits: Popup
@export var time_paused_indicator: Label

@onready var skin_color_picker: ColorPickerButton = $MainMenu/MainContainer/MainMenu/Option2/SkinColorPicker
@onready var nick_input: LineEdit = $MainMenu/MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $MainMenu/MainContainer/MainMenu/Option3/AddressInput
@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: Control = $MainMenu
@onready var menu: Menu = $Menu

# multiplayer chat
@onready var message: LineEdit = $MultiplayerChat/VBoxContainer/HBoxContainer/Message
@onready var send: Button = $MultiplayerChat/VBoxContainer/HBoxContainer/Send
@onready var chat: TextEdit = $MultiplayerChat/VBoxContainer/Chat
@onready var multiplayer_chat: Control = $MultiplayerChat
@onready var object_properties := %"ObjectProperties" as ObjectProperties

var chat_visible := false
var time_elapsed := 0
var time_start := 0
var edit_mode := false:
	set(value):
		edit_mode = value


func _ready() -> void:
	multiplayer_chat.hide()
	main_menu.show()
	multiplayer_chat.set_process_input(true)
	if not multiplayer.is_server():
		return

	var _error := Network.player_connected.connect(_on_player_connected)
	_error = multiplayer.peer_disconnected.connect(_remove_player)


func _process(_delta: float) -> void:
	if not edit_mode:
		return

	if not time_paused:
		update_timer_paused_indicator()

	if not multiplayer.is_server():
		return

	if Input.is_action_just_pressed(&"time_play_pause"):
		sync_time_pause.rpc(not time_paused)
		if time_paused:
			Audio.play_sound("pause")
		else:
			Audio.play_sound("play")

	if Input.is_action_just_pressed(&"time_rewind"):
		sync_time_rewind.rpc()
		Audio.play_sound("rewind")


func update_timer_paused_indicator() -> void:
	var current_total_time := time_elapsed

	if not time_paused:
		current_total_time += Time.get_ticks_msec() - time_start

	var time_passed_seconds := current_total_time / 1000.0
	var minutes := floori(time_passed_seconds / 60.0)
	var seconds := time_passed_seconds - minutes * 60

	if time_paused:
		time_paused_indicator.text = "PAUSED - %02d:%02d" % [minutes, seconds]
	else:
		time_paused_indicator.text = "PLAYING - %02d:%02d" % [minutes, seconds]


@rpc("authority", "call_local")
func sync_time_pause(value: bool) -> void:
	if time_paused == value:
		return

	if time_paused and not value:
		time_start = Time.get_ticks_msec()
		time_paused = false
		Signals.time_played.emit()
	elif not time_paused and value:
		time_elapsed += Time.get_ticks_msec() - time_start
		time_paused = true
		update_timer_paused_indicator()
		Signals.time_paused.emit()


@rpc("authority", "call_local")
func sync_time_rewind() -> void:
	time_elapsed = 0
	time_start = 0
	time_paused = true
	update_timer_paused_indicator()
	for gadget: Gadget in object_properties.logic_panel.get_children():
		gadget.reset_metas_to_initial()
	for parent: Node in destroyed_nodes.keys():
		parent.add_child(destroyed_nodes[parent])
	destroyed_nodes.clear()
	Signals.time_rewound.emit()


func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	for id: int in Network.players.keys():
		var player_data: Dictionary = Network.players[id]
		if id != peer_id:
			sync_player_skin.rpc_id(peer_id, id, player_data["skin"])

	if is_multiplayer_authority():
		menu.populate_level_portals()
	_add_player(peer_id, player_info)


func _on_host_pressed() -> void:
	main_menu.hide()
	var _error := Network.start_host(nick_input.text.strip_edges(), skin_color_picker.color)


func _on_join_pressed() -> void:
	main_menu.hide()
	var address := address_input.text.strip_edges()
	var _error := Network.join_game(nick_input.text.strip_edges(), skin_color_picker.color, address)


func _add_player(id: int, player_info : Dictionary) -> void:
	if players_container.has_node(str(id)) or not multiplayer.is_server():
		return

	var player := player_scene.instantiate() as Character
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)
	if id == 1:
		object_properties.editor = player.editor
		menu.player = player
		var _error := skin_changed.connect(_on_player_skin_changed.bind(id))

	var nick: String = Network.players[id]["nick"]
	player.change_nick.rpc(nick)

	var skin_color: Color = player_info["skin"]
	sync_player_skin.rpc(id, skin_color)

	sync_player_position.rpc(id, player.position)


func get_spawn_point() -> Vector3:
	return Vector3.ZERO


func _remove_player(id: int) -> void:
	if not is_multiplayer_authority() and id == 1:
		menu._on_main_menu_button_pressed.call_deferred()
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node := players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()


@rpc("any_peer", "call_local")
func sync_player_position(id: int, new_position: Vector3) -> void:
	var player := players_container.get_node(str(id)) as Character
	if player:
		player.position = new_position


@rpc("any_peer", "call_local")
func sync_player_skin(id: int, skin_color: Color) -> void:
	var player := players_container.get_node(str(id)) as Character
	if player:
		player.set_player_skin(skin_color)


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---------- MULTIPLAYER CHAT ----------
func toggle_chat() -> void:
	if main_menu.visible:
		return

	chat_visible = !chat_visible
	if chat_visible:
		multiplayer_chat.show()
		message.grab_focus()
	else:
		multiplayer_chat.hide()
		get_viewport().set_input_as_handled()


func is_chat_visible() -> bool:
	return chat_visible


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif key_event and key_event.keycode == KEY_ENTER:
		_on_send_pressed()


func _on_send_pressed() -> void:
	var trimmed_message := message.text.strip_edges()
	if trimmed_message == "":
		return # do not send empty messages

	var nick: String = Network.players[multiplayer.get_unique_id()]["nick"]

	msg_rpc.rpc(nick, trimmed_message)
	message.text = ""
	message.grab_focus()


@rpc("any_peer", "call_local")
func msg_rpc(nick: String, msg: String) -> void:
	chat.text += str(nick, " : ", msg, "\n")


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	var id := multiplayer.get_unique_id()
	if int(node.name) == id:
		var player := node as Character
		if player:
			object_properties.editor = player.editor
			menu.player = player
			var _error := skin_changed.connect(_on_player_skin_changed.bind(id))


func _on_player_skin_changed(color: Color, id: int) -> void:
	if id == 1:
		Network.player_info["skin"] = color
	sync_player_skin.rpc(id, color)


func _on_color_picker_button_color_changed(color: Color) -> void:
	skin_changed.emit(color)


func _on_credits_pressed() -> void:
	credits.show()
