class_name Gadget
extends TextureRect


signal open_properties

enum ConnectionChange {
	CONNECT,
	DISCONNECT,
	DELETE,
	CANCEL,
}

@onready var input_controls := $InputControls.get_children()
@onready var output_controls := $OutputControls.get_children()
@onready var outputs := $Outputs.get_children()
@onready var node_3d := $"3D"

var just_dragged_output := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for output_control: OutputControl in output_controls:
		var output_index := int(output_control.name.trim_prefix("OutputControl"))
		output_control.gui_input.connect(_on_output_control_gui_input.bind(output_index))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	input_signal(delta)

	if is_in_group(&"Dragging"):
		# Dragging Gadget
		position = get_global_mouse_position() - size / 2

		update_connection_positions()
	else:
		for output_control: OutputControl in output_controls:
			if output_control.is_in_group(&"Dragging"):
				# Dragging Output
				var output_index := int(output_control.name.trim_prefix("OutputControl"))
				var output := outputs[output_index]
				var mouse_pos := get_global_mouse_position()
				output.points[2] = output.to_local(mouse_pos)
				output_control.global_position = mouse_pos - output_control.size / 2

				var target_gadget: Gadget
				var target_input: int

				for input_control: Control in get_tree().get_nodes_in_group(&"InputControl"):
					if mouse_pos.distance_squared_to(
						input_control.global_position
					) < 250:
						output.points[2] = output.to_local(
							input_control.global_position
							+ Vector2(0, input_control.size.y / 2)
						)
						output_control.global_position = (
							input_control.global_position
							+ Vector2(0, input_control.size.y / 2)
							- Vector2(output_control.size.x, output_control.size.y / 2)
						)
						target_gadget = input_control.get_parent().get_parent()
						target_input = int(input_control.name.trim_prefix("InputControl"))
						break

				if Input.is_action_just_pressed(&"action") and not just_dragged_output:
					if target_gadget:
						# Connect Output
						update_connection(
							ConnectionChange.CONNECT,
							output_index,
							target_gadget,
							target_input
						)
					else:
						# Delete Output
						update_connection(
							ConnectionChange.DELETE,
							output_index,
							output_control.target_gadget,
							output_control.target_input
						)
				elif Input.is_action_just_pressed(&"ui_cancel"):
					# Cancel
					update_connection(
						ConnectionChange.CANCEL,
						output_index,
						output_control.target_gadget,
						output_control.target_input
					)

				just_dragged_output = false


func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE):
		node_3d.queue_free()
		for i in output_controls.size():
			output_signal(i, null)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			# Drag Gadget
			top_level = true
			add_to_group(&"Dragging")
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			accept_event()
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == 2:
		open_properties.emit()


func _on_output_control_gui_input(event: InputEvent, output_index: int) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			# Drag Output
			var output_control := output_controls[output_index]
			output_control.add_to_group(&"Dragging")
			output_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not is_instance_valid(output_control.target_gadget):
				output_control.target_gadget = null
			update_connection(
				ConnectionChange.DISCONNECT,
				output_index,
				output_control.target_gadget,
				output_control.target_input
			)
			just_dragged_output = true


# Run manually.
func input_signal(_delta: float) -> void:
	pass


# Run every frame.
func input_pulse(_input_index: int, _data: Variant) -> void:
	pass


func output_signal(output_index: int, data: Variant) -> void:
	var output_control := output_controls[output_index] as OutputControl
	var gadget := output_control.target_gadget
	if is_instance_valid(gadget):
		var input_control := gadget.input_controls[output_control.target_input] as InputControl

		if data == null and input_control.output_controls.size() > 1:
			return

		var pulse: bool = data != null and input_control.data != null and data > input_control.data

		input_control.data = data

		if pulse:
			output_pulse(output_index, data)


func output_pulse(output_index: int, data: Variant) -> void:
	var output_control := output_controls[output_index] as OutputControl
	var gadget := output_control.target_gadget
	if is_instance_valid(gadget):
		gadget.input_pulse(output_control.target_input, data)


func change_property(_property: StringName, _value: Variant) -> void:
	pass


func update_connection(
		type: ConnectionChange,
		output_index: int,
		gadget: Gadget,
		input_index: int
) -> void:
	var output := outputs[output_index]
	var output_control := output_controls[output_index] as OutputControl

	if type != ConnectionChange.DISCONNECT:
		output_control.remove_from_group(&"Dragging")
		output_control.mouse_filter = Control.MOUSE_FILTER_STOP

	prints(
		["CONNECT", "DISCONNECT", "DELETE", "CANCEL"][type],
		"OUTPUT",
		output_index,
		"TO",
		gadget,
		"INPUT",
		input_index
	)

	if type == ConnectionChange.CONNECT:
		gadget.input_controls[input_index].output_controls.append(output_control)
		gadget.input_controls[input_index].outputs.append(output)
		output_control.target_gadget = gadget
		output_control.target_input = input_index
		output_signal(output_index, false)
	else:
		output.points[2] = output.points[1]
		output_control.position = output.position - Vector2(0, output_control.size.y / 2)

		output_signal(output_index, null)
		output_control.target_gadget = null

		if gadget:
			gadget.input_controls[input_index].output_controls.erase(output_control)
			gadget.input_controls[input_index].outputs.erase(output)


func update_connection_positions() -> void:
	for output_control: OutputControl in output_controls:
		if is_instance_valid(output_control.target_gadget):
			var output_index := int(output_control.name.trim_prefix("OutputControl"))
			var output := outputs[output_index]
			output.points[2] = output.to_local(
				output_control.target_gadget.global_position
				+ Vector2(0, output_control.target_gadget.size.y / 2)
			)
			output_control.global_position = (
				output_control.target_gadget.global_position
				+ Vector2(0, output_control.target_gadget.size.y / 2)
				- Vector2(output_control.size.x, output_control.size.y / 2)
			)

	for input_control: InputControl in input_controls:
		for i in input_control.output_controls.size():
			var output_control := input_control.output_controls[i]
			var output := input_control.outputs[i]
			if is_instance_valid(output_control):
				if is_queued_for_deletion():
					output.points[2] = output.points[1]
					output_control.position = (
						output.position
						- Vector2(0, output_control.size.y / 2)
					)
				else:
					output.points[2] = output.to_local(
						output_control.target_gadget.global_position
						+ Vector2(0, output_control.target_gadget.size.y / 2)
					)
					output_control.global_position = (
						output_control.target_gadget.global_position
						+ Vector2(0, output_control.target_gadget.size.y / 2)
						- Vector2(output_control.size.x, output_control.size.y / 2)
					)


func attach_to_object(o: PhysicsBody3D) -> void:
	remove_child(node_3d)
	o.add_child(node_3d)
	input_pulse(0, true)


func set_icon(t: Texture2D) -> void:
	texture = t


func is_input_powered(input_index: int) -> bool:
	var input_control := input_controls[input_index] as InputControl
	return input_control.data == null or not is_zero_approx(input_control.data)
