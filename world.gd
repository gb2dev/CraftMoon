class_name World
extends Node3D


signal skin_changed(color: Color)

static var time_paused := true
static var destroyed_nodes: Dictionary[Node, Node]

@export var player_scene: PackedScene
@export var credits: Popup
@export var time_paused_indicator: Label

@onready var skin_color_picker: ColorPickerButton = $MainMenu/MainContainer/Option2/SkinColorPicker
@onready var nick_input: LineEdit = $MainMenu/MainContainer/Option1/NickInput
@onready var address_input: LineEdit = $MainMenu/MainContainer/Option3/AddressInput
@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: Control = $MainMenu
@onready var menu: Menu = $Menu
@onready var login_container: VBoxContainer = $MainMenu/LoginContainer
@onready var main_container: VBoxContainer = $MainMenu/MainContainer
@onready var security_code_input: LineEdit = $MainMenu/LoginContainer/Option3/SecurityCodeInput
@onready var email_input: LineEdit = $MainMenu/LoginContainer/Option1/EmailInput
@onready var get_security_code: Button = $MainMenu/LoginContainer/Option2/GetSecurityCode
@onready var status_label: Label = $MainMenu/LoginContainer/StatusLabel
@onready var login: Button = $MainMenu/LoginContainer/Option4/Login

# multiplayer chat
@onready var message: LineEdit = $MultiplayerChat/VBoxContainer/HBoxContainer/Message
@onready var send: Button = $MultiplayerChat/VBoxContainer/HBoxContainer/Send
@onready var chat: TextEdit = $MultiplayerChat/VBoxContainer/Chat
@onready var multiplayer_chat: Control = $MultiplayerChat
@onready var object_properties := %"ObjectProperties" as ObjectProperties
@onready var options_menu: OptionsMenu = $OptionsMenu

var chat_visible := false
var time_elapsed := 0
var time_start := 0
var edit_mode := false:
	set(value):
		edit_mode = value

static var modio: ModIO
static var modio_token: String


func _ready() -> void:
	multiplayer_chat.hide()
	main_menu.show()
	multiplayer_chat.set_process_input(true)
	Menu.shown = false
	nick_input.text = OptionsConfig.get_config_value("player", "nick", "")
	skin_color_picker.color = OptionsConfig.get_config_value("player", "skin_color", Color.WHITE)
	address_input.text = OptionsConfig.get_config_value("network", "last_address", "")
	if not multiplayer.is_server():
		return

	var _error := Network.player_connected.connect(_on_player_connected)
	_error = multiplayer.peer_disconnected.connect(_remove_player)

	modio = ModIO.new()
	add_child(modio)
	var _connected := modio.connect("https://g-10598.modapi.io/v1", "5e07891fe571c166b912d659a085f617", 10598)
	
	var arguments := {}
	for argument in OS.get_cmdline_args():
		if argument.contains("="):
			var key_value := argument.split("=")
			arguments[key_value[0].trim_prefix("--")] = key_value[1]
	if arguments.has("modio-token"):
		modio_token = arguments["modio-token"]
		login_container.hide()
		main_container.show()
	else:
		var saved_token: String = OptionsConfig.get_config_value("modio", "token", "")
		if not saved_token.is_empty():
			modio_token = saved_token
			login_container.hide()
			main_container.show()


func _process(_delta: float) -> void:
	if chat_visible:
		if Input.is_action_just_pressed(&"ui_cancel"):
			toggle_chat()
		elif Input.is_action_just_pressed(&"ui_accept"):
			_on_send_pressed()
	elif Input.is_action_just_pressed(&"toggle_chat"):
		toggle_chat()

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
	Signals.time_paused.emit()
	Signals.time_rewound.emit()


func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	for id: int in Network.players.keys():
		var player_data: Dictionary = Network.players[id]
		if id != peer_id:
			sync_player_skin.rpc_id(peer_id, id, player_data["skin"])

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
		options_menu.set_player(player)
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


func _on_nick_input_text_changed(new_text: String) -> void:
	OptionsConfig.set_config_value(new_text, "player", "nick")


func _on_skin_color_picker_color_changed(color: Color) -> void:
	OptionsConfig.set_config_value(color, "player", "skin_color")


func _on_address_input_text_changed(new_text: String) -> void:
	OptionsConfig.set_config_value(new_text, "network", "last_address")


func _on_sign_out_pressed() -> void:
	OptionsConfig.set_config_value("", "modio", "token")
	modio_token = ""
	main_container.hide()
	login_container.show()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---------- MULTIPLAYER CHAT ----------
func toggle_chat() -> void:
	if main_menu.visible or Menu.shown:
		return

	chat_visible = !chat_visible
	if chat_visible:
		multiplayer_chat.show()
		get_viewport().set_input_as_handled()
		message.grab_focus()
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	else:
		multiplayer_chat.hide.call_deferred()
		get_viewport().set_input_as_handled()
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func is_chat_visible() -> bool:
	return chat_visible


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
			options_menu.set_player(player)
			var _error := skin_changed.connect(_on_player_skin_changed.bind(id))


func _on_player_skin_changed(color: Color, id: int) -> void:
	if id == 1:
		Network.player_info["skin"] = color
	sync_player_skin.rpc(id, color)


func _on_color_picker_button_color_changed(color: Color) -> void:
	skin_changed.emit(color)


func _on_credits_pressed() -> void:
	credits.show()


func _on_login_pressed() -> void:
	var response := modio.login_with_security_code(security_code_input.text)
	if response.is_empty():
		status_label.text = tr("Error: Invalid Security Code")
	else:
		modio_token = response
		OptionsConfig.set_config_value(response, "modio", "token")
		login_container.hide()
		main_container.show()


func _on_get_security_code_pressed() -> void:
	login.disabled = false
	get_security_code.disabled = true
	modio.request_security_code(email_input.text)
	await get_tree().create_timer(10).timeout
	get_security_code.disabled = false


func _on_upload_button_pressed() -> void:
	var base_path := "user://levels/" + str(menu.slot)
	var image := get_viewport().get_texture().get_image()
	var image_path := base_path + ".png"
	var _err := image.save_png(image_path)
	var save_path := base_path + ".save"
	var _mod_id := modio.upload_mod(
		modio_token,
		ProjectSettings.globalize_path(save_path),
		menu.level_name.text,
		menu.level_description.text,
		ProjectSettings.globalize_path(image_path),
		["Level"]
	)
