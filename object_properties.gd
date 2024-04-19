class_name ObjectProperties
extends Control


@export var gadgets_panel: GadgetsPanel
@export var gadget_properties: GadgetProperties
@export var tab_container: TabContainer
@export var object_vbox: VBoxContainer
@export var player_vbox: VBoxContainer

var object: Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible and Input.is_action_just_pressed(&"ui_cancel"):
		close()


func toggle(o: Node3D):
	if o:
		object = o
		if not o.tree_exiting.is_connected(close_on_free):
			o.tree_exiting.connect(close_on_free)
		visible = not visible
		if visible:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
			if object is Player:
				object_vbox.hide()
				player_vbox.show()
			else:
				object_vbox.show()
				player_vbox.hide()
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func close() -> void:
	if get_tree().get_first_node_in_group(&"Dragging"):
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


func _on_collision_check_box_toggled(toggled_on: bool) -> void:
	object.use_collision = toggled_on
