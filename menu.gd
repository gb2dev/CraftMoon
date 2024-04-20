extends Control


const SOUND_MENU = preload("res://sounds/menu.wav")

@export var player_scene: PackedScene
@export var audio_player: AudioStreamPlayer
@export var background_dim: ColorRect

var peer := ENetMultiplayerPeer.new()
var player: Player


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
		toggle()


func add_player(id := 1) -> void:
	player = player_scene.instantiate()
	player.name = str(id)
	get_tree().current_scene.add_child.call_deferred(player)
	visibility_changed.connect(player.editor.toggle_ui)


func toggle() -> void:
	for control: Control in get_tree().get_nodes_in_group(&"UI"):
		if control.visible:
			return

	get_tree().paused = not get_tree().paused
	visible = get_tree().paused
	background_dim.visible = get_tree().paused
	if get_tree().paused:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		audio_player.stream = SOUND_MENU
		audio_player.play()
	else:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func _on_save_button_pressed() -> void:
	var save_data: Array[Dictionary]
	for node in get_tree().get_nodes_in_group(&"Persist"):
		if node is CSGShape3D:
			var type: String
			match node.get_class():
				"CSGBox3D": type = "Cuboid"
			save_data.append({
				"type": type,
				"position": node.position,
				"rotation": node.rotation,
				"size": node.size,
				"material": node.material.resource_path,
				"collision": node.use_collision,
				"gadgets": [],
			})
		elif node is Gadget:
			var path: String = "res://gadgets/" + node.type.to_snake_case()
			var item := load(path + ".tscn")
			var item_data := load(path + ".tres")
			var parent_index: int = node.node_3d.get_parent_node_3d().get_index()
			var gadgets: Array = save_data[parent_index].gadgets
			var connections: Array[Array]
			var outputs_count: int = node.output_controls.size()
			connections.resize(outputs_count)
			for output_index in outputs_count:
				for output_control: OutputControl in node.output_controls[output_index]:
					if not is_instance_valid(output_control.target_gadget):
						continue

					connections[output_index].append({
						"target_gadget": output_control.target_gadget.get_index(),
						"target_input": output_control.target_input,
					})
			var gadget_data := {
				"type": item_data.name,
				"connections": connections,
				"position": node.position,
				"properties": {}
			}
			for property: StringName in node.get_meta_list():
				gadget_data.properties[property] = node.get_meta(property)
			gadgets.append(gadget_data)
	var save_file := FileAccess.open("user://level.save", FileAccess.WRITE)
	save_file.store_var(save_data)
	prints("Save level: ", save_data)


func _on_load_button_pressed() -> void:
	if not FileAccess.file_exists("user://level.save"):
		printerr("Error! Save file not found.")
		return

	var save_file := FileAccess.open("user://level.save", FileAccess.READ)
	var save_data := save_file.get_var() as Array[Dictionary]
	if save_data:
		toggle()
		get_tree().call_group(&"Persist", &"queue_free")
		await get_tree().process_frame

		var gadgets: Array
		for object_data: Dictionary in save_data:
			var object: CSGShape3D
			match object_data.type:
				"Cuboid":
					player.editor.construction_material = load(object_data.material)
					player.editor.construction_collision = object_data.collision
					object = player.editor.construct_shape(
						object_data.type,
						object_data.position,
						object_data.rotation,
						object_data.size
					)
			gadgets.append_array(object_data.gadgets)
			for gadget_data: Dictionary in object_data.gadgets:
				player.editor.object_properties.object = object
				var path: String = "res://gadgets/" + gadget_data.type.to_snake_case()
				var item := load(path + ".tscn")
				var item_data := load(path + ".tres")
				var gadget := player.editor.object_properties.create_gadget(
					item,
					item_data,
					gadget_data.position
				)
				for property: StringName in gadget_data.properties:
					var value: Variant = gadget_data.properties[property]
					gadget.set_meta(property, value)
					gadget.change_property(property, value)
		connect_gadgets(gadgets)


func connect_gadgets(gadgets: Array) -> void:
	var logic_panel := player.editor.object_properties.logic_panel
	for i in gadgets.size():
		var gadget_data: Dictionary = gadgets[i]
		var gadget := logic_panel.get_children()[i]
		var outputs_count: int = gadget_data.connections.size()
		for output_index in outputs_count:
			for output_data: Dictionary in gadget_data.connections[output_index]:
				gadget.update_connection(
					Gadget.ConnectionChange.CONNECT,
					gadget.output_controls[output_index].back(),
					logic_panel.get_children()[output_data.target_gadget],
					output_data.target_input
				)


func _on_join_button_pressed() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	hide()
	peer.create_client("localhost", 7000)
	multiplayer.multiplayer_peer = peer


func _on_quit_button_pressed() -> void:
	get_tree().quit()
