class_name Gadget
extends TextureRect


signal open_properties

@onready var input_control := $InputControl as Control
@onready var output := $Output as Line2D
@onready var output_control := $OutputControl as Control
@onready var node_3d := $"3D"

var input_data: Variant
var just_dragged_output := false
var gadget_connected_to_output: Gadget:
	set(value):
		if is_instance_valid(gadget_connected_to_output) and value == null:
			gadget_connected_to_output.input_data = null
		gadget_connected_to_output = value


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_in_group("Dragging"):
		# Dragging Gadget
		position = get_global_mouse_position() - size / 2

		update_connection_positions()
	else:
		if output.is_in_group("Dragging"):
			# Dragging Output
			var mouse_pos := get_local_mouse_position()
			output.points[2] = mouse_pos
			output_control.position = mouse_pos - output_control.size / 2

			gadget_connected_to_output = null

			for input: Control in get_tree().get_nodes_in_group("Input"):
				if get_global_mouse_position().distance_squared_to(input.global_position) < 500:
					output.points[2] = output.to_local(input.global_position + Vector2(0, input.size.y / 2))
					output_control.position = output.to_local(input.global_position - output_control.size / 2 + Vector2(0, input.size.y / 2))
					gadget_connected_to_output = input.get_parent()
					break

			if Input.is_action_just_pressed("action") and not just_dragged_output:
				if gadget_connected_to_output:
					gadget_connected_to_output.input_data = false
				else:
					output.points[2] = output.points[1]
					output_control.position = output.points[1] - output_control.size / 2
				output.remove_from_group("Dragging")
				output_control.mouse_filter = Control.MOUSE_FILTER_STOP
			elif Input.is_action_just_pressed("ui_cancel"):
				output.remove_from_group("Dragging")
				output.points[2] = output.points[1]
				output_control.position = output.points[1] - output_control.size / 2
				output_control.mouse_filter = Control.MOUSE_FILTER_STOP

			just_dragged_output = false


func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE):
		node_3d.queue_free()
		if is_instance_valid(gadget_connected_to_output):
			gadget_connected_to_output.input_data = null


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group("Dragging"):
			# Drag Gadget
			var scene := get_tree().current_scene
			get_parent().remove_child(self)
			scene.add_child(self)
			add_to_group("Dragging")
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			accept_event()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 2:
		open_properties.emit()


func _on_output_control_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group("Dragging"):
			output.add_to_group("Dragging")
			output_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			just_dragged_output = true


func update_connection_positions() -> void:
	for input: Control in get_tree().get_nodes_in_group("Input"):
		if input.get_parent() == gadget_connected_to_output:
			output.points[2] = output.to_local(input.global_position + Vector2(0, input.size.y / 2))
			output_control.position = output.to_local(input.global_position - output_control.size / 2 + Vector2(0, input.size.y / 2))

	for o: Control in get_tree().get_nodes_in_group("Output"):
		var gadget := o.get_parent() as Gadget
		if gadget.gadget_connected_to_output == self:
			if is_queued_for_deletion():
				gadget.output.points[2] = gadget.output.points[1]
				gadget.output_control.position = gadget.output.points[1] - output_control.size / 2
			else:
				gadget.output.points[2] = gadget.output.to_local(input_control.global_position + Vector2(0, input_control.size.y / 2))
				gadget.output_control.position = gadget.output.to_local(input_control.global_position - output_control.size / 2 + Vector2(0, input_control.size.y / 2))


func attach_to_object(o: PhysicsBody3D) -> void:
	remove_child(node_3d)
	o.add_child(node_3d)


func set_icon(t: Texture2D) -> void:
	texture = t


func execute_once() -> void:
	pass


func change_property(property: StringName, value: Variant) -> void:
	pass
