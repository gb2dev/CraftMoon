extends Control


const SOUND_MENU = preload("res://sounds/menu.wav")
const DEFAULT_MATERIAL = preload("res://materials/checkerboard_dark.tres")
const MOON_MATERIAL = preload("res://materials/concrete/concrete.tres")

@export var player_scene: PackedScene
@export var audio_player: AudioStreamPlayer
@export var background_dim: ColorRect
@export var level_name: LineEdit
@export var level_description: TextEdit
@export var mode_button: Button
@export var save_button: Button
@export var moon_button: Button

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
	await get_tree().process_frame
	enter_play_mode()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
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
	toggle()
	save_level()


func _on_load_button_pressed() -> void:
	toggle()
	load_level()


func connect_gadgets(gadgets: Array[Gadget], gadget_data_array: Array[Dictionary]) -> void:
	var index_offset := 0
	var parent_index := 0
	var logic_panel := player.editor.object_properties.logic_panel
	for gadget: Gadget in gadgets:
		var new_parent_index := gadget.node_3d.get_parent().get_index()
		if parent_index != new_parent_index:
			parent_index = new_parent_index
			index_offset = gadget.get_index()

		var gadget_data: Dictionary = gadget_data_array[gadget.get_index()]
		var outputs_count: int = gadget_data.connections.size()
		for output_index in outputs_count:
			for output_data: Dictionary in gadget_data.connections[output_index]:
				gadget.update_connection(
					Gadget.ConnectionChange.CONNECT,
					gadget.output_controls[output_index].back(),
					logic_panel.get_children()[index_offset + output_data.target_gadget],
					output_data.target_input
				)


func save_level() -> void:
	var save_data := [{
		"type": "Level",
		"name": level_name.text,
		"description": level_description.text,
	}] as Array[Dictionary]
	var gadget_indexes: Dictionary

	for gadget: Gadget in player.editor.object_properties.logic_panel.get_children():
		var parent_index: int = gadget.node_3d.get_parent().get_index()
		if not gadget_indexes.has(parent_index):
			gadget_indexes[parent_index] = []
		gadget_indexes[parent_index].append(gadget.get_index())

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
			var item_data := load(path + ".tres")
			var parent_index: int = node.node_3d.get_parent().get_index()
			var gadgets: Array = save_data[parent_index + 1].gadgets
			var connections: Array[Array]
			var outputs_count: int = node.output_controls.size()
			connections.resize(outputs_count)
			for output_index in outputs_count:
				for output_control: OutputControl in node.output_controls[output_index]:
					if not is_instance_valid(output_control.target_gadget):
						continue

					connections[output_index].append({
						"target_gadget": gadget_indexes[parent_index].find(
							output_control.target_gadget.get_index()
						),
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
	var save_file_path := "user://" + level_name.text.to_snake_case() + ".save"
	var save_file := FileAccess.open(save_file_path, FileAccess.WRITE)
	if save_file:
		save_file.store_var(save_data)
		prints("Save level: ", save_data)
	else:
		printerr("Error! Invalid level name.")


func load_level() -> void:
	var save_file_path := "user://" + level_name.text.to_snake_case() + ".save"

	if not FileAccess.file_exists(save_file_path):
		printerr("Error! Save file not found.")
		return

	var save_file := FileAccess.open(save_file_path, FileAccess.READ)
	var save_data := save_file.get_var() as Array[Dictionary]
	if save_data:
		new_level()
		await get_tree().process_frame
		level_name.text = save_data[0].name
		level_description.text = save_data[0].description

		var gadgets: Array[Gadget]
		var gadget_data_array: Array[Dictionary]
		for object_data: Dictionary in save_data:
			var object: CSGShape3D
			match object_data.type:
				"Level":
					continue
				"Cuboid":
					player.editor.construction_material = load(object_data.material)
					player.editor.construction_collision = object_data.collision
					object = player.editor.construct_shape(
						object_data.type,
						object_data.position,
						object_data.rotation,
						object_data.size
					)
					if object.get_index() == 0:
						object.add_to_group(&"Undeletable")
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
				gadgets.append(gadget)
				gadget_data_array.append(gadget_data)
				for property: StringName in gadget_data.properties:
					var value: Variant = gadget_data.properties[property]
					gadget.set_meta(property, value)
					gadget.change_property(property, value)
		connect_gadgets(gadgets, gadget_data_array)
	# TODO: Use spawn point
	player.position = Vector3.ZERO


func new_level() -> void:
	get_tree().call_group(&"Persist", &"queue_free")
	level_name.text = tr(&"New Level")
	level_description.text = ""


func enter_edit_mode() -> void:
	mode_button.text = tr(&"Play Mode")
	player.editor.input_display.visible = true
	player.editor.process_mode = PROCESS_MODE_INHERIT
	load_level()


func enter_play_mode() -> void:
	mode_button.text = tr(&"Edit Mode")
	player.fly = false
	player.editor.set_object_builder_active(false)
	player.editor.input_display.visible = false
	player.editor.process_mode = PROCESS_MODE_DISABLED
	save_level()
	load_level()


func _on_join_button_pressed() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	hide()
	peer.create_client("localhost", 7000)
	multiplayer.multiplayer_peer = peer


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_new_level_button_pressed() -> void:
	level_name.editable = true
	level_name.flat = false
	level_description.visible = true
	level_name.size_flags_vertical = Control.SIZE_FILL
	mode_button.visible = true
	save_button.visible = true
	moon_button.visible = true

	toggle()
	new_level()
	var floor := player.editor.construct_shape(
		"Cuboid",
		Vector3(0, -0.5, 0),
		Vector3.ZERO,
		Vector3(100, 1, 100),
	)
	floor.add_to_group(&"Undeletable")
	floor.material = DEFAULT_MATERIAL
	# TODO: Use spawn point
	player.position = Vector3.ZERO
	enter_edit_mode()


func _on_mode_button_pressed() -> void:
	toggle()
	if player.editor.process_mode == PROCESS_MODE_DISABLED:
		enter_edit_mode()
	else:
		enter_play_mode()


func _on_moon_button_pressed() -> void:
	level_name.editable = false
	level_name.flat = true
	level_description.visible = false
	level_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_button.visible = false
	save_button.visible = false
	moon_button.visible = false

	toggle()
	new_level()
	level_name.text = tr(&"Your Moon")
	var floor := player.editor.construct_shape(
		"Cuboid",
		Vector3(0, -0.5, 0),
		Vector3.ZERO,
		Vector3(100, 1, 100),
	)
	floor.add_to_group(&"Undeletable")
	floor.material = MOON_MATERIAL
	# TODO: Use spawn point
	player.position = Vector3.ZERO
	enter_play_mode()
