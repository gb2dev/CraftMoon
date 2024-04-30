class_name Menu
extends Control


const SOUND_MENU = preload("res://sounds/menu.wav")
const SOUND_WHOOSH = preload("res://sounds/whoosh.wav")
const SOUND_DELETE = preload("res://sounds/destroy.wav")
const DEFAULT_MATERIAL = preload("res://materials/checkerboard_dark.tres")
const MOON_MATERIAL = preload("res://materials/concrete/concrete.tres")
const LEVEL_ICON_MATERIAL = preload("res://materials/level_icon.tres")

const LEVEL_PORTAL = preload("res://level_portal.tscn")
const LEVEL_PORTAL_POSITIONS = [
	Vector3(-4, 0, -12),
	Vector3(3, 0, -11),
	Vector3(9, 0, -9),
	Vector3(-11, 0, -8),
	Vector3(0, 0, -7),
	Vector3(-6, 0, -6),
	Vector3(6, 0, -4),
	Vector3(-10, 0, -2),
	Vector3(11, 0, -1),
	Vector3(-11, 0, 3),
	Vector3(9, 0, 4),
	Vector3(-6, 0, 6),
	Vector3(3, 0, 7),
	Vector3(-10, 0, 8),
	Vector3(8, 0, 9),
	Vector3(-3, 0, 10),
]

@export var player_scene: PackedScene
@export var audio_player: AudioStreamPlayer
@export var background_dim: ColorRect
@export var level_transition_wipe: ColorRect
@export var level_name: LineEdit
@export var level_description: TextEdit
@export var mode_button: Button
@export var save_button: Button
@export var moon_button: Button
@export var export_button: Button
@export var level_portals: Node3D

var peer := ENetMultiplayerPeer.new()
var player: Player
var slot := 0


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
	DirAccess.make_dir_absolute("user://levels")
	spawn_level_portals()


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
	if save_data[0].name.is_empty():
		save_data[0].name = tr(&"New Level")
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
				"CSGSphere3D": type = "Ellipsoid"
				"CSGCylinder3D":
					if node.cone:
						type = "Cone"
					else:
						type = "Cylinder"
				"CSGTorus3D": type = "Torus"
			save_data.append({
				"type": type,
				"position": node.position,
				"rotation": node.rotation,
				# TODO: Fix size for some shapes like Cone
				"size": node.size if type == "Cuboid" else node.scale,
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
	var save_file_path := "user://levels/" + str(slot) + ".save"
	var save_file := FileAccess.open(save_file_path, FileAccess.WRITE)
	if save_file:
		save_file.store_var(save_data)
		prints("Save level: ", save_data)
	else:
		printerr("Error! Invalid level name.")


func load_level(level := "") -> void:
	level_name.selecting_enabled = true
	level_name.editable = true
	level_name.flat = false
	level_description.visible = true
	level_name.size_flags_vertical = Control.SIZE_FILL
	mode_button.visible = true
	save_button.visible = true
	moon_button.visible = true
	export_button.visible = true

	if level.is_empty():
		level = level_name.text
	var save_file_path := "user://levels/" + level + ".save"

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
				"Cuboid", "Ellipsoid", "Cylinder", "Cone", "Torus":
					player.editor.construction_material = load(object_data.material)
					player.editor.construction_collision = object_data.collision
					object = player.editor.construct_shape(
						object_data.type,
						object_data.position,
						object_data.rotation,
						object_data.size
					)
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
	player.pivot.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO


func delete_save(level: String) -> void:
	var path := "user://levels/" + level + ".save"
	if FileAccess.file_exists(path):
		audio_player.stream = SOUND_DELETE
		audio_player.play()
		DirAccess.remove_absolute(path)


func new_level(blank := true) -> void:
	if not blank:
		level_name.selecting_enabled = true
		level_name.editable = true
		level_name.flat = false
		level_description.visible = true
		level_name.size_flags_vertical = Control.SIZE_FILL
		mode_button.visible = true
		save_button.visible = true
		moon_button.visible = true
		export_button.visible = true

		await wipe()

		new_level()
		await get_tree().process_frame
		var floor_object := player.editor.construct_shape(
			"Cuboid",
			Vector3(0, -0.5, 0),
			Vector3.ZERO,
			Vector3(100, 1, 100),
		)
		floor_object.material = DEFAULT_MATERIAL
		# TODO: Use spawn point
		player.position = Vector3.ZERO
		player.pivot.rotation = Vector3.ZERO
		player.camera.rotation = Vector3.ZERO
		enter_edit_mode()
	else:
		get_tree().call_group(&"Persist", &"queue_free")
		get_tree().call_group(&"Moon", &"queue_free")
		level_name.text = tr(&"New Level")
		level_description.text = ""


func enter_edit_mode() -> void:
	mode_button.text = tr(&"Play Mode")
	player.editor.input_display.visible = true
	player.editor.process_mode = PROCESS_MODE_INHERIT
	player.editor.set_object_builder_active(false)


func enter_play_mode() -> void:
	mode_button.text = tr(&"Edit Mode")
	player.fly = false
	player.editor.set_object_builder_active(false)
	player.editor.input_display.visible = false
	player.editor.process_mode = PROCESS_MODE_DISABLED


func wipe() -> void:
	audio_player.stream = SOUND_WHOOSH
	audio_player.play()
	var tween := get_tree().create_tween()
	tween.tween_property(level_transition_wipe, ^"color", Color.WHITE, 0.3)
	await tween.finished
	tween = get_tree().create_tween()
	tween.tween_property(level_transition_wipe, ^"color", Color.TRANSPARENT, 0.3)


func spawn_level_portals() -> void:
	for i in LEVEL_PORTAL_POSITIONS.size():
		var pos := LEVEL_PORTAL_POSITIONS[i] as Vector3
		var level_portal := LEVEL_PORTAL.instantiate() as LevelPortal
		level_portals.add_child(level_portal)
		level_portal.position = pos
		level_portal.menu = self
		if i % 3 == 0:
			level_portal.scale = Vector3.ONE * 2
		else:
			level_portal.label.scale = Vector3.ONE * 2
		level_portal.label.global_position.y = 0.25

	player.editor.input_display.clear_input_prompts()
	player.editor.input_display.add_input_prompt(&"destroy", tr(&"Delete Level"))
	player.editor.input_display.visible = true

	var dir := DirAccess.open("user://levels")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save"):
				var save_file_path := "user://levels/" + file_name
				var save_file := FileAccess.open(save_file_path, FileAccess.READ)
				var save_data := save_file.get_var() as Array[Dictionary]
				if save_data:
					var level_portal := level_portals.get_child(int(file_name)) as LevelPortal
					level_portal.label.text = save_data[0].name
					level_portal.level = file_name.trim_suffix(".save")
					level_portal.cylinder.material = load(save_data[1].material)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")


func _on_save_button_pressed() -> void:
	toggle()
	save_level()


func _on_load_button_pressed() -> void:
	toggle()
	await wipe()
	load_level()


func _on_join_button_pressed() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	hide()
	peer.create_client("localhost", 7000)
	multiplayer.multiplayer_peer = peer


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_new_level_button_pressed() -> void:
	toggle()
	new_level(false)


func _on_mode_button_pressed() -> void:
	toggle()
	if player.editor.process_mode == PROCESS_MODE_DISABLED:
		enter_edit_mode()
		load_level()
	else:
		enter_play_mode()
		save_level()
		load_level()


func _on_moon_button_pressed() -> void:
	level_name.selecting_enabled = false
	level_name.editable = false
	level_name.flat = true
	level_description.visible = false
	level_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_button.visible = false
	save_button.visible = false
	moon_button.visible = false
	export_button.visible = false

	toggle()

	await wipe()

	new_level()
	await get_tree().process_frame
	level_name.text = tr(&"Your Moon")
	var floor_object := player.editor.construct_shape(
		"Cuboid",
		Vector3(0, -0.5, 0),
		Vector3.ZERO,
		Vector3(100, 1, 100),
	)
	floor_object.material = MOON_MATERIAL
	# TODO: Use spawn point
	player.position = Vector3.ZERO
	player.pivot.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	enter_play_mode()
	spawn_level_portals()


func _on_export_button_pressed() -> void:
	var scene := PackedScene.new()
	scene.pack(get_tree().current_scene.get_node(^"Geometry"))
	DirAccess.make_dir_absolute("user://export/")
	ResourceSaver.save(scene, "user://export/export.tscn")
