class_name Moon
extends Node3D


signal enter_level(level_slot: int, blank_level: bool)

static var is_using_computer: bool

const MAX_COMMUNITY_LEVEL_PAGE_BUTTONS = 9
const MAX_COMMUNITY_LEVELS_PER_PAGE = 2
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
const LEVEL_ITEM_SCENE = preload("res://level_item.tscn")

var current_community_levels_page := 1

@export var level_portals: Node3D
@export var level_select_camera: Camera3D
@export var computer_screen: Control
@export var interaction_hint: Node3D
@export var computer_area: Area3D
@export var community_levels: Control
@export var community_levels_layout: Container
@export var page_buttons_layout: Container
@export var http_request: HTTPRequest


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
	computer_screen.get_child(0).visible = true
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
	level_portals.visible = false
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
	level_portals.visible = true


func create_page_button(page_index: int) -> void:
	var page_button := Button.new()
	page_button.text = str(page_index)
	page_button.disabled = (page_index == current_community_levels_page)
	page_button.custom_minimum_size = Vector2(32, 32)

	var idx := page_index
	var _error := page_button.pressed.connect(func() -> void:
		if current_community_levels_page != idx:
			current_community_levels_page = idx
			show_community_levels()
	)
	page_buttons_layout.add_child(page_button)


func create_page_input(pages_count: int) -> void:
	var input := LineEdit.new()
	input.placeholder_text = "..."
	input.custom_minimum_size = Vector2(32, 32)
	input.max_length = 6
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var _error := input.text_submitted.connect(func(text: String) -> void:
		var s := text.strip_edges()
		if s == "":
			return
		if not s.is_valid_int():
			input.text = ""
			return
		var idx := clampi(int(s), 1, pages_count)
		if idx != current_community_levels_page:
			current_community_levels_page = idx
			show_community_levels()
		input.text = ""
	)

	_error = input.focus_exited.connect(func() -> void:
		var s := input.text.strip_edges()
		if s == "":
			input.text = ""
			return
		if not s.is_valid_int():
			input.text = ""
			return
		var idx := clampi(int(s), 1, pages_count)
		if idx != current_community_levels_page:
			current_community_levels_page = idx
			show_community_levels()
		input.text = ""
	)

	page_buttons_layout.add_child(input)


func _on_community_button_pressed() -> void:
	community_levels.visible = true
	current_community_levels_page = 1
	show_community_levels()


func show_community_levels() -> void:
	for node in community_levels_layout.get_children() + page_buttons_layout.get_children():
		node.queue_free()

	var mods := World.modio.get_mods("", current_community_levels_page, MAX_COMMUNITY_LEVELS_PER_PAGE, [])

	var pages_count := mods["pages_count"] as int
	current_community_levels_page = clamp(current_community_levels_page, 1, pages_count)

	for level: Dictionary in mods["mod_list"]:
		var level_item := LEVEL_ITEM_SCENE.instantiate() as Button
		level_item.text = level["name"]
		level_item.set_meta(&"level_id", level["id"])
		level_item.set_meta(&"level_url", level["modfile_url"])
		community_levels_layout.add_child(level_item)
		var _error := level_item.pressed.connect(
			download_and_unzip_mod.bind(
				level_item.get_meta(&"level_url"),
				level_item.get_meta(&"level_id")
			)
		)

	if pages_count <= MAX_COMMUNITY_LEVEL_PAGE_BUTTONS:
		for i in range(1, pages_count + 1):
			create_page_button(i)
		return

	var window_size := MAX_COMMUNITY_LEVEL_PAGE_BUTTONS - 2
	var half := floori(window_size / 2.0)

	var start := current_community_levels_page - half
	var end := current_community_levels_page + half

	if start < 2:
		start = 2
		end = start + window_size - 1
	if end > pages_count - 1:
		end = pages_count - 1
		start = end - window_size + 1

	create_page_button(1)

	if start > 2:
		create_page_input(pages_count)

	for i in range(start, end + 1):
		create_page_button(i)

	if end < pages_count - 1:
		create_page_input(pages_count)

	create_page_button(pages_count)


func download_and_unzip_mod(mod_url: String, mod_id: int) -> void:
	print("Downloading mod from: ", mod_url)

	# Start the download
	var error := http_request.request(mod_url)
	if error != OK:
		print("Failed to start download: ", error)
		return

	# Store mod_id for later use in the callback
	http_request.set_meta(&"mod_id", mod_id)


func _on_http_request_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var mod_id_str := str(http_request.get_meta(&"mod_id"))

	if response_code != 200:
		print("Download failed with response code: ", response_code)
		return

	print("Download completed, file size: ", body.size())

	# Save the downloaded file
	var download_path := "user://mods/"
	var _error := DirAccess.open("user://").make_dir_recursive("mods")

	var zip_file_path := download_path + mod_id_str + ".zip"
	var file := FileAccess.open(zip_file_path, FileAccess.WRITE)
	if file:
		var _success := file.store_buffer(body)
		file.close()
		print("Saved zip file to: ", zip_file_path)

		# Now unzip it
		unzip_mod(zip_file_path, mod_id_str)
	else:
		print("Failed to save zip file")


func unzip_mod(zip_path: String, mod_id_str: String) -> void:
	var zip_reader := ZIPReader.new()
	var error := zip_reader.open(zip_path)

	if error != OK:
		print("Failed to open zip file: ", error)
		return

	var extract_path := "user://mods/" + mod_id_str + "/"
	var _error := DirAccess.open("user://").make_dir_recursive("mods/" + mod_id_str)

	var files := zip_reader.get_files()
	print("Extracting ", files.size(), " files...")

	for file_path in files:
		var file_data := zip_reader.read_file(file_path)
		if file_data.size() > 0:
			# Create directory structure if needed
			var dir_path := extract_path + file_path.get_base_dir()
			if dir_path != extract_path:
				_error = DirAccess.open("user://").make_dir_recursive(
					"mods/" + mod_id_str + "/" + file_path.get_base_dir()
				)

			# Write the file
			var output_path := extract_path + file_path
			var output_file := FileAccess.open(output_path, FileAccess.WRITE)
			if output_file:
				var _success := output_file.store_buffer(file_data)
				output_file.close()
				print("Extracted: ", file_path)
			else:
				print("Failed to create file: ", output_path)

	_error = zip_reader.close()

	# Optionally delete the zip file after extraction
	_error = DirAccess.open("user://").remove(zip_path)

	print("Mod extraction completed to: ", extract_path)

	# Call your function to load/process the mod
	load_extracted_mod(extract_path, mod_id_str)


func load_extracted_mod(mod_path: String, mod_id_str: String) -> void:
	# TODO: Process your extracted mod files here
	prints("Loading mod", mod_path, mod_id_str)
	# You can scan the directory for specific files you need
	# var dir = DirAccess.open(mod_path)
	# etc...
