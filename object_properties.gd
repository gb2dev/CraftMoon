class_name ObjectProperties
extends Control


const SOUND_POPUP = preload("res://sounds/popup.wav")

@export var gadgets_panel: GadgetsPanel
@export var gadget_properties: GadgetProperties
@export var tab_container: TabContainer
@export var object_vbox: VBoxContainer
@export var player_vbox: VBoxContainer
@export var audio_player: AudioStreamPlayer
@export var editor: Editor
@export var logic_panel: LogicPanel

var object: Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed(&"ui_cancel"):
		close()


func toggle(o: Node3D) -> void:
	object = o
	if o and not o.tree_exiting.is_connected(close_on_free):
		o.tree_exiting.connect(close_on_free)
	if visible:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
		hide()
	else:
		audio_player.stream = SOUND_POPUP
		audio_player.play()
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		if object is Player:
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

	if gadget_properties.visible:
		gadget_properties.visible = false
		gadget_properties.gadget_changed.emit()
		gadgets_panel.visible = true
		if tab_container.current_tab == 1:
			return

	toggle(object)


func close_on_free() -> void:
	if visible:
		toggle(object)


func change_object_material(m: BaseMaterial3D) -> void:
	if is_instance_valid(object):
		object.material = m
	else:
		editor.construction_material = m


func get_object_material() -> BaseMaterial3D:
	if is_instance_valid(object):
		return object.material
	else:
		return editor.construction_material


func create_gadget(item: PackedScene, item_data: ItemData, pos := Vector2.INF) -> Gadget:
	var gadget := item.instantiate() as Gadget
	get_tree().current_scene.add_child(gadget)
	gadget.add_to_group(&"Persist")
	if pos == Vector2.INF:
		gadget.add_to_group(&"Dragging")
	else:
		logic_panel.place_gadget(gadget)
		gadget.position = pos
	gadget.attach_to_object(object)
	gadget.set_icon(item_data.icon)
	gadget.open_properties.connect(func() -> void:
		gadget_properties.gadget_changed.emit()
	)
	gadget.open_properties.connect(gadget_properties.open.bind(item_data.name, gadget))
	gadget.open_properties.connect(gadgets_panel.hide)
	gadget.type = item_data.name
	return gadget


func _on_collision_check_box_toggled(toggled_on: bool) -> void:
	if is_instance_valid(object):
		object.use_collision = toggled_on
	else:
		editor.construction_collision = toggled_on
