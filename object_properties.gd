class_name ObjectProperties
extends Control

signal selected_material_changed

const GADGET_SCENE = preload("res://gadgets/gadget.tscn")

@export var gadgets_panel: GadgetsPanel
@export var gadget_properties: GadgetProperties
@export var tab_container: TabContainer
@export var object_vbox: VBoxContainer
@export var player_vbox: VBoxContainer
@export var logic_panel: LogicPanel

var editor: Editor
var object: Node3D
var gadgets_created_count: int


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed(&"ui_cancel"):
		close()


func toggle(o: Node3D) -> void:
	object = o
	if o and not o.tree_exiting.is_connected(close_on_free):
		var _error := o.tree_exiting.connect(close_on_free)
	if visible:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
		hide()
	else:
		Audio.play_sound("popup")
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		if object is Character:
			tab_container.set_deferred(&"current_tab", 0)
			object_vbox.hide()
			player_vbox.show()
		else:
			if is_instance_valid(object):
				tab_container.tabs_visible = true
				tab_container.position.y = 0
				tab_container.size.y = tab_container.get_parent().size.y
			else:
				tab_container.set_deferred(&"current_tab", 0)
				tab_container.tabs_visible = false
				tab_container.position.y = 28
				tab_container.size.y = tab_container.get_parent().size.y - 28
			object_vbox.show()
			player_vbox.hide()
		show()


func close() -> void:
	if get_tree().get_first_node_in_group(&"Dragging") or not visible:
		return

	var exclusive_window := get_tree().get_first_node_in_group(&"ExclusiveWindow") as Window
	if exclusive_window and exclusive_window.visible:
		return

	if close_gadget_properties() and tab_container.current_tab == 1:
		return

	toggle(object)


func close_on_free() -> void:
	if visible:
		var _closed := close_gadget_properties()
		toggle(object)


func close_gadget_properties() -> bool:
	if gadget_properties.visible:
		gadget_properties.visible = false
		gadget_properties.gadget_changed.emit()
		gadgets_panel.visible = true
		return true
	return false


@rpc("any_peer")
func sync_object_material(material_path: String, object_path: NodePath) -> void:
	get_node(object_path).material = load(material_path)
	if object and object.get_path() == object_path:
		selected_material_changed.emit()


func change_object_material(material_resource: BaseMaterial3D) -> void:
	if is_instance_valid(object):
		object.material = material_resource
	else:
		editor.construction_material = material_resource


func get_object_material() -> BaseMaterial3D:
	if is_instance_valid(object):
		return object.material
	else:
		return editor.construction_material


@rpc("any_peer", "call_local")
func create_gadget(
	gadget_data_path: String,
	object_path: NodePath,
	pos := Vector2.INF,
	silent := false
) -> Gadget:
	var gadget_data := load(gadget_data_path) as GadgetData
	var node := GADGET_SCENE.instantiate()
	var script := load(gadget_data.resource_path.replace(".tres", ".gd"))
	node.set_script(script)
	var gadget := node as Gadget
	get_tree().current_scene.add_child(gadget)
	gadget.name = str(gadgets_created_count)
	gadgets_created_count += 1
	gadget.add_to_group(&"Persist")
	if pos == Vector2.INF:
		if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
			gadget.add_to_group(&"Dragging")
		else:
			gadget.position = Vector2.ZERO
	else:
		logic_panel.place_gadget(gadget.get_path(), silent, pos)
	gadget.attach_to_object(object_path)
	var _error := gadget.open_properties.connect(gadget_properties.gadget_changed.emit)
	_error = gadget.open_properties.connect(gadget_properties.open.bind(gadget_data.name, gadget))
	_error = gadget.open_properties.connect(gadgets_panel.hide)
	_error = gadget.close_properties.connect(close_gadget_properties)
	gadget.type = gadget_data.name
	gadget.set_gadget_data(gadget_data)
	if not silent:
		gadget.set_mouse_filters(MOUSE_FILTER_IGNORE)
	return gadget


func _on_collision_check_box_toggled(toggled_on: bool) -> void:
	if is_instance_valid(object):
		object.use_collision = toggled_on
	else:
		editor.construction_collision = toggled_on
