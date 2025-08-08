class_name Moon
extends Node3D


signal enter_level(level_slot: int, blank_level: bool)

static var is_using_computer: bool

const LEVEL_PORTAL = preload("res://level_portal.tscn")
const LEVEL_PORTAL_POSITIONS = [
	Vector3(-4, 0, -11),
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

@export var level_portals: Node3D
@export var level_select_camera: Camera3D
@export var computer_screen: Control
@export var interaction_hint: Node3D
@export var computer_area: Area3D


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"interact") or (is_using_computer and Input.is_action_just_pressed(&"ui_cancel")):
		if interaction_hint.visible:
			use_computer()
		elif is_using_computer:
			unuse_computer()


func _exit_tree() -> void:
	if is_multiplayer_authority():
		unuse_computer()


func spawn_level_portals() -> void:
	for i in LEVEL_PORTAL_POSITIONS.size():
		var pos: Vector3 = LEVEL_PORTAL_POSITIONS[i] * 4
		var level_portal := LEVEL_PORTAL.instantiate() as LevelPortal
		level_portals.add_child(level_portal)
		level_portal.position = pos
		if i % 3 == 0:
			level_portal.scale = Vector3.ONE * 1.5
		else:
			level_portal.label.scale = Vector3.ONE * 1.5
		level_portal.label.global_position.y = 0.25

		if is_multiplayer_authority():
			var _error := level_portal.portal_entered.connect(
				enter_level.emit.bind(true)
			)
			_error = level_portal.portal_properties.connect(func(slot: int) -> void:
				Menu.delete_save(str(slot))
				clear_level_portal_details.rpc(slot)
			)


@rpc("any_peer")
func sync_level_portal_details() -> void:
	if is_multiplayer_authority():
		for level_portal: LevelPortal in level_portals.get_children():
			set_level_portal_details.bind(
				level_portal.get_index(),
				level_portal.label.text,
				level_portal.cylinder.material.resource_path
			).rpc_id(multiplayer.get_remote_sender_id())


func populate_level_portals() -> void:
	if not is_multiplayer_authority():
		sync_level_portal_details.rpc_id(1)
		return

	var dir := DirAccess.open("user://levels")
	if dir:
		var _list_dir_error := dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save") and file_name != "remote.save":
				var save_file_path := "user://levels/" + file_name
				var save_file := FileAccess.open(save_file_path, FileAccess.READ)
				var save_data := save_file.get_var() as Array[Dictionary]
				if save_data:
					set_level_portal_details(
						int(file_name),
						save_data[0].name,
						save_data[1].material as String
					)
			file_name = dir.get_next()
	else:
		printerr("An error occurred when trying to access the path.")


@rpc
func set_level_portal_details(
	portal_slot: int,
	portal_level_name: String,
	portal_material: String
) -> void:
	var level_portal := level_portals.get_child(portal_slot) as LevelPortal
	level_portal.label.text = portal_level_name
	level_portal.cylinder.material = load(portal_material)

	if is_multiplayer_authority():
		if level_portal.portal_entered.is_connected(enter_level.emit):
			level_portal.portal_entered.disconnect(enter_level.emit)
		var _connect_error := level_portal.portal_entered.connect(
			enter_level.emit.bind(false)
		)


@rpc("call_local")
func clear_level_portal_details(portal_slot: int) -> void:
	var level_portal := level_portals.get_child(portal_slot) as LevelPortal
	level_portal.label.text = ""
	level_portal.cylinder.material = LevelPortal.DEFAULT_MATERIAL

	if is_multiplayer_authority():
		if level_portal.portal_entered.is_connected(enter_level.emit):
			level_portal.portal_entered.disconnect(enter_level.emit)
		var _error := level_portal.portal_entered.connect(
			enter_level.emit.bind(true)
		)


func use_computer() -> void:
	is_using_computer = true
	interaction_hint.visible = false
	computer_screen.visible = true
	Menu.shown = true
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)


func unuse_computer() -> void:
	is_using_computer = false
	interaction_hint.visible = is_host_in_computer_area()
	computer_screen.visible = false
	Menu.shown = false
	Signals.level_select_closed.emit()
	level_select_camera.current = false
	if not Menu.shown:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func is_host_in_computer_area() -> bool:
	return computer_area.get_overlapping_bodies().any(func(body: Node3D) -> bool:
		return is_multiplayer_authority() and body.name == "1"
	)


func _on_computer_entered(body: Node3D) -> void:
	if is_multiplayer_authority() and body.name == "1":
		interaction_hint.visible = true


func _on_computer_exited(body: Node3D) -> void:
	if is_multiplayer_authority() and body.name == "1":
		interaction_hint.visible = false


func _on_create_button_pressed() -> void:
	computer_screen.visible = false
	level_select_camera.current = true


func _on_community_button_pressed() -> void:
	print("TODO: list community levels")
