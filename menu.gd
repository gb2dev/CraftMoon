class_name Menu
extends Control


signal level_transfer_complete
signal wipe_out

const WIPE_TIME = 0.3
const DEFAULT_MATERIAL = preload("res://materials/checkerboard_dark.tres")
const MOON_MATERIAL = preload("res://materials/concrete/concrete.tres")
const LEVEL_ICON_MATERIAL = preload("res://materials/level_icon.tres")
const MOON_SCENE = preload("res://moon.tscn")
const DEFAULT_ENVIRONMENT = preload("res://default_environment.tscn")

static var shown: bool
static var slot := 0

@export var background_dim: ColorRect
@export var level_transition_wipe: ColorRect
@export var level_name: LineEdit
@export var level_description: TextEdit
@export var mode_button: Button
@export var save_button: Button
@export var upload_button: Button
@export var moon_button: Button
@export var export_button: Button
@export var delete_button: Button
@export var main_menu_button: Button
@export var main_menu: Control
@export var object_properties_node: ObjectProperties

var player: Character
@onready var pie_menu: PieMenu = get_node("%PieMenu")

@onready var world := get_tree().current_scene as World
@onready var options_menu: OptionsMenu = $"../OptionsMenu"


func _ready() -> void:
	var _io_error := DirAccess.make_dir_absolute("user://levels")
	var _connect_error := Network.player_connected.connect(func(peer_id: int, _player_info: Dictionary) -> void:
		if peer_id == 1:
			spawn_moon()
			if not is_multiplayer_authority():
				var host_nick: String = Network.players[1]["nick"]
				level_name.text = tr(&"%s's Moon") % host_nick
	)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(&"ui_cancel"):
		if pie_menu and pie_menu.visible:
			pie_menu.close()
			get_viewport().set_input_as_handled()
			return
		if options_menu.visible:
			options_menu.close()
			get_viewport().set_input_as_handled()
			return
		if visible:
			toggle()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"pause_menu"):
		for control: Control in get_tree().get_nodes_in_group(&"UI"):
			if control.visible:
				return
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if main_menu.visible:
		return

	for control: Control in get_tree().get_nodes_in_group(&"UI"):
		if control.visible:
			return

	for camera: Camera3D in get_tree().get_nodes_in_group(&"UICamera"):
		if camera.current:
			return

	visible = not visible
	background_dim.visible = visible
	if not visible:
		options_menu.close()
	if visible:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		Audio.play_sound("menu")
	elif not Moon.is_using_computer:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func connect_gadgets(gadgets: Array[Gadget], gadget_properties_array: Array[Dictionary]) -> void:
	var index_offset := 0
	var parent_index := 0
	var logic_panel := player.editor.object_properties.logic_panel
	for gadget: Gadget in gadgets:
		var new_parent_index := gadget.node_3d.get_parent().get_index()
		if parent_index != new_parent_index:
			parent_index = new_parent_index
			index_offset = gadget.get_index()

		var gadget_properties: Dictionary = gadget_properties_array[gadget.get_index()]
		var outputs_count: int = gadget_properties.connections.size()
		for output_index in outputs_count:
			for output_properties: Dictionary in gadget_properties.connections[output_index]:
				gadget.update_connection(
					Gadget.ConnectionChange.CONNECT,
					gadget.output_controls[output_index].back().get_path(),
					logic_panel.get_children()[index_offset + output_properties.target_gadget].get_path(),
					output_properties.target_input,
					true
				)


func save_level() -> void:
	world.sync_time_rewind()

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

	var geometry_nodes: Array[CSGShape3D]
	var gadget_nodes: Array[Gadget]
	for node in get_tree().get_nodes_in_group(&"Persist"):
		if node is Gadget:
			gadget_nodes.append(node)
		elif node is CSGShape3D:
			geometry_nodes.append(node)
	for geometry in geometry_nodes:
		var type: String = geometry.get_meta(&"shape_type", "")
		save_data.append({
			"type": type,
			"position": geometry.get_meta(&"box_center", geometry.position),
			"rotation": geometry.get_meta(&"rotation", Vector3.ZERO),
			"size": geometry.get_meta(&"box_size", Vector3.ONE),
			"material": geometry.material.resource_path,
			"collision": geometry.use_collision,
			"uniform": geometry.get_meta(&"uniform", false),
			"gadgets": [],
		})
	for gadget: Gadget in gadget_nodes:
		var path: String = "res://gadgets/" + gadget.type.to_snake_case()
		var gadget_data := load(path + ".tres")
		var parent_index: int = gadget.node_3d.get_parent().get_index()
		var gadgets: Array = save_data[parent_index + 1].gadgets
		var connections: Array[Array]
		var outputs_count: int = gadget.output_controls.size()
		var _error := connections.resize(outputs_count)
		for output_index in outputs_count:
			for output_control: GadgetOutputControl in gadget.output_controls[output_index]:
				if not is_instance_valid(output_control.target_gadget):
					continue

				connections[output_index].append({
					"target_gadget": gadget_indexes[parent_index].find(
						output_control.target_gadget.get_index()
					),
					"target_input": output_control.target_input,
				})
		var gadget_properties := {
			"type": gadget_data.name,
			"connections": connections,
			"position": gadget.position,
			"properties": {}
		}
		var property_list := gadget.get_meta_list()
		if gadget.has_method(&"sort_property_list"):
			property_list.sort_custom(gadget.sort_property_list)
		for property: StringName in property_list:
			gadget_properties.properties[property] = gadget.get_meta(property)
		gadgets.append(gadget_properties)
	var save_file_path := get_save_file_path(str(slot))
	var save_file := FileAccess.open(save_file_path, FileAccess.WRITE)
	if save_file:
		var _success := save_file.store_var(save_data)
	else:
		printerr("Error! Invalid level name.")


func transfer_level(save_file_path: String) -> void:
	transfer.rpc(FileAccess.get_file_as_bytes(save_file_path), get_save_file_path("remote"))


static func get_save_file_path(save_file_name: String) -> String:
	return "user://levels/" + save_file_name + ".save"


@rpc("any_peer", "call_local", "reliable")
func emit_level_transfer_complete() -> void:
	level_transfer_complete.emit()


@rpc("any_peer", "reliable")
func transfer(data: PackedByteArray, filename: String) -> void:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	var success := file.store_buffer(data)
	file.flush()
	if success:
		emit_level_transfer_complete.rpc()


@rpc("any_peer", "call_local")
func prepare_load_level() -> void:
	sync_reset_gadgets_created_count()
	if multiplayer.is_server():
		level_name.editable = true
		level_name.flat = false
	level_description.visible = true
	level_description.editable = multiplayer.is_server()
	level_name.size_flags_vertical = Control.SIZE_FILL
	if multiplayer.is_server():
		mode_button.visible = true
		save_button.visible = true
		moon_button.visible = true
		export_button.visible = true
		upload_button.visible = true
		delete_button.visible = true


func load_level(save_file_path := "") -> void:
	prepare_load_level.rpc()

	if save_file_path.is_empty():
		save_file_path = get_save_file_path(str(slot))

	if not FileAccess.file_exists(save_file_path):
		printerr("Error! Save file not found.")
		return

	var save_file := FileAccess.open(save_file_path, FileAccess.READ)
	var save_data := save_file.get_var() as Array[Dictionary]
	if save_data:
		new_level()
		await get_tree().process_frame
		_add_default_environment()
		level_name.text = save_data[0].name
		level_description.text = save_data[0].description

		var gadgets: Array[Gadget]
		var gadget_properties_array: Array[Dictionary]
		for object_properties: Dictionary in save_data:
			var object: CSGShape3D
			match object_properties.type:
				"Level":
					continue
				"Cuboid", "Ellipsoid", "Cylinder", "Cone", "Torus", "Polygon":
					player.editor.construction_material = load(object_properties.material)
					player.editor.construction_collision = object_properties.collision
					var uniform_mode: bool = object_properties.get("uniform", false)
					object = player.editor.construct_shape(
						object_properties.type,
						object_properties.position,
						object_properties.rotation,
						object_properties.size,
						player.editor.construction_material.resource_path,
						player.editor.construction_collision,
						uniform_mode
					)
			for gadget_properties: Dictionary in object_properties.gadgets:
				player.editor.object_properties.object = object
				var path: String = "res://gadgets/" + gadget_properties.type.to_snake_case()
				var gadget_data := load(path + ".tres")
				var gadget := player.editor.object_properties.create_gadget(
					gadget_data.resource_path,
					object.get_path(),
					gadget_properties.position,
					true
				)
				gadgets.append(gadget)
				gadget_properties_array.append(gadget_properties)
				for property: StringName in gadget_properties.properties:
					var value: Variant = gadget_properties.properties[property]
					gadget.sync_meta(property, value)
					gadget.change_property(property, value)
		connect_gadgets(gadgets, gadget_properties_array)

	respawn_player.rpc()


@rpc("any_peer", "call_local")
func respawn_player() -> void:
	player.position = Vector3.ZERO
	Signals.player_respawn.emit(player)
	player.pivot.rotation = Vector3(0, PI, 0)
	player._spring_arm_offset.rotation = player.pivot.rotation
	player._spring_arm_offset._spring_arm.rotation.x = 0
	player._body.apply_rotation_first_person(-player.pivot.global_rotation.y)
	player.camera.rotation = Vector3.ZERO


static func delete_save(save_file_name: String) -> void:
	var path := get_save_file_path(save_file_name)
	if FileAccess.file_exists(path):
		Audio.play_sound("destroy")
		var _error := DirAccess.remove_absolute(path)


@rpc("any_peer", "call_local")
func new_level(blank := true) -> void:
	if not blank:
		if is_multiplayer_authority():
			level_name.editable = true
			level_name.flat = false
		level_description.visible = true
		level_description.editable = is_multiplayer_authority()
		level_name.size_flags_vertical = Control.SIZE_FILL
		if is_multiplayer_authority():
			mode_button.visible = true
			save_button.visible = true
			moon_button.visible = true
			export_button.visible = true
			upload_button.visible = true
			delete_button.visible = true

		await wipe()

		new_level()
		await get_tree().process_frame
		_add_default_environment()
		# Default floor
		var _floor_object := player.editor.construct_shape(
			"Cuboid",
			Vector3(0, -0.5, 0),
			Vector3.ZERO,
			Vector3(100, 1, 100),
			DEFAULT_MATERIAL.resource_path,
			true
		)
		respawn_player()
		enter_edit_mode()
	else:
		get_tree().call_group(&"Moon", &"queue_free")
		get_tree().call_group(&"Persist", &"queue_free")
		level_name.text = tr(&"New Level")
		level_description.text = ""


@rpc("any_peer", "call_local")
func enter_edit_mode() -> void:
	world.edit_mode = true
	world.sync_time_rewind()
	world.time_paused_indicator.visible = true
	mode_button.text = tr(&"Play Mode")
	player.first_person = true
	player.editor.input_display.visible = true
	player.editor.process_mode = PROCESS_MODE_INHERIT
	player.editor.set_object_builder_active(false)
	player.editor._update_input_display()
	world.update_mode_indicator()


@rpc("any_peer", "call_local")
func enter_play_mode() -> void:
	world.edit_mode = false
	world.sync_time_rewind()
	world.sync_time_pause(false)
	world.time_paused_indicator.visible = false
	mode_button.text = tr(&"Edit Mode")
	player.fly = false
	player.first_person = false
	player.editor.process_mode = PROCESS_MODE_DISABLED
	player.editor.set_object_builder_active(false)
	player.editor.input_display.visible = true
	player.editor._update_input_display()
	world.update_mode_indicator()


func spawn_moon() -> void:
	_remove_default_environment()
	var moon := MOON_SCENE.instantiate() as Moon
	world.add_child(moon)
	var _error := moon.enter_level.connect(_on_moon_level_entered)
	moon.spawn_level_portals()
	moon.populate_level_portals()


func _add_default_environment() -> void:
	if world.get_node_or_null("DefaultEnvironment"):
		return
	world.add_child(DEFAULT_ENVIRONMENT.instantiate())


func _remove_default_environment() -> void:
	var env := world.get_node_or_null("DefaultEnvironment")
	if env:
		env.queue_free()


func _on_moon_level_entered(path: String, level_slot: int, blank_level: bool) -> void:
	if is_multiplayer_authority():
		_on_level_entered.rpc(path, level_slot, blank_level)


@rpc("any_peer", "call_local")
func go_to_moon() -> void:
	level_name.editable = false
	level_name.flat = true
	level_description.visible = false
	level_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_button.visible = false
	save_button.visible = false
	moon_button.visible = false
	export_button.visible = false
	upload_button.visible = false
	delete_button.visible = false

	await wipe()

	enter_play_mode()
	new_level()
	await get_tree().process_frame
	if is_multiplayer_authority():
		level_name.text = tr(&"Your Moon")
	else:
		var host_nick: String = Network.players[1]["nick"]
		level_name.text = tr(&"%s's Moon") % host_nick
	spawn_moon()
	respawn_player()
	if is_multiplayer_authority():
		multiplayer.multiplayer_peer.refuse_new_connections = false
	player.editor.input_display.moon_inputs()
	await get_tree().create_timer(WIPE_TIME).timeout


func wipe(await_signal := Signal()) -> void:
	Audio.play_sound("whoosh")
	var tween := get_tree().create_tween()
	var _property_tweener := tween.tween_property(level_transition_wipe, ^"color", Color.WHITE, WIPE_TIME)
	var signals_to_await: Array[Signal]
	signals_to_await.append(tween.finished)
	var _error := tween.finished.connect(
		emit_wipe_out.bind(signals_to_await, tween.finished),
		CONNECT_ONE_SHOT
	)
	if not await_signal.is_null():
		signals_to_await.append(await_signal)
		_error = await_signal.connect(
			emit_wipe_out.bind(signals_to_await, await_signal),
			CONNECT_ONE_SHOT
		)
	await wipe_out
	tween = get_tree().create_tween()
	_property_tweener = tween.tween_property(level_transition_wipe, ^"color", Color.TRANSPARENT, WIPE_TIME)


func emit_wipe_out(signals_to_await: Array[Signal], signal_received: Signal) -> void:
	signals_to_await.erase(signal_received)
	if signals_to_await.is_empty():
		wipe_out.emit()


func _on_save_button_pressed() -> void:
	toggle()
	save_level()


func _on_load_button_pressed() -> void:
	toggle()
	await wipe()
	load_level()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_button_pressed() -> void:
	if options_menu.visible:
		options_menu.close()
	else:
		options_menu.open()


func _on_new_level_button_pressed() -> void:
	toggle()
	new_level.rpc(false)


func _on_mode_button_pressed() -> void:
	toggle()
	if player.editor.process_mode == PROCESS_MODE_DISABLED:
		enter_edit_mode.rpc()
	else:
		enter_play_mode.rpc()
	respawn_player.rpc()


func _on_moon_button_pressed() -> void:
	toggle()
	go_to_moon.rpc()


func _on_export_button_pressed() -> void:
	var scene := PackedScene.new()
	var geometry := get_tree().current_scene.get_node(^"Geometry")
	var _error := scene.pack(geometry)
	_error = DirAccess.make_dir_absolute("user://export/")
	_error = ResourceSaver.save(scene, "user://export/export.tscn")


func _on_delete_button_pressed() -> void:
	delete_save(str(slot))
	_on_moon_button_pressed()


func _on_main_menu_button_pressed() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Network.players.clear()
	Network.player_info.clear()
	var _error := get_tree().reload_current_scene()
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)


@rpc("any_peer", "call_local")
func sync_reset_gadgets_created_count() -> void:
	object_properties_node.gadgets_created_count = 0


@rpc("any_peer", "call_local")
func _on_level_entered(path: String, level_slot: int, blank_level: bool) -> void:
	if is_multiplayer_authority():
		multiplayer.multiplayer_peer.refuse_new_connections = true
	slot = level_slot
	if blank_level:
		sync_reset_gadgets_created_count.rpc()
		new_level(false)
	else:
		if is_multiplayer_authority():
			transfer_level(path)
			if multiplayer.get_peers().size() > 0:
				await wipe(level_transfer_complete)
			else:
				await wipe()
			load_level(path)
		else:
			await wipe(level_transfer_complete)
			load_level(get_save_file_path("remote"))
		enter_edit_mode()


func _on_level_name_text_changed(new_text: String) -> void:
	set_level_name.rpc(new_text)


func _on_level_description_text_changed() -> void:
	set_level_description.rpc(level_description.text)


@rpc
func set_level_name(value: String) -> void:
	level_name.text = value


@rpc
func set_level_description(value: String) -> void:
	level_description.text = value


func _on_visibility_changed() -> void:
	shown = visible
