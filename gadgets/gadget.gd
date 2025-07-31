@abstract
class_name Gadget
extends Control


signal input_pulse(input_index: int)
signal open_properties
signal property_update(value: Variant)

enum ConnectionChange {
	CONNECT,
	DISCONNECT,
	DELETE,
	CANCEL,
}

const _INPUT_CONTROL_SCENE = preload("res://gadgets/gadget_input_control.tscn")
const _OUTPUT_PORT_SCENE = preload("res://gadgets/gadget_output_port.tscn")
const _OUTPUT_VISUAL_SCENE = preload("res://gadgets/gadget_output_visual.tscn")
const _OUTPUT_CONTROL_SCENE = preload("res://gadgets/gadget_output_control.tscn")
const _PORT_SIZE = 16
const _PORT_SPACING = 4
const _CABLE_HIGHLIGHT = preload("res://textures/cable_highlight.tres")
const _POWER_ICON = preload("res://icons/power.svg")

@onready var node_3d := $"3D" as Node3D
@onready var background := $Background as NinePatchRect
@onready var icon := $Icon as TextureRect

var _just_dragged_output := false
var _highlight_line: Line2D
var _output_visuals: Array
var input_controls: Array
var output_controls: Array
var type: String
var output_controls_created_count: int


@abstract func start() -> void
@abstract func tick(delta: float) -> void
@abstract func change_property(property: StringName, value: Variant) -> void


func _process(delta: float) -> void:
	tick(delta)

	if is_in_group(&"Dragging") and not is_in_group(&"GridSnap"):
		# Dragging Gadget without Grid Snap
		position = get_global_mouse_position() - size / 2

		update_connection_positions()
	else:
		for output_index in output_controls.size():
			for output_control: GadgetOutputControl in output_controls[output_index]:
				if output_control.is_in_group(&"Dragging"):
					# Dragging Output
					var output_visual := _output_visuals[output_index][
						_find_nested_array_item(output_controls, output_control)[0]
					] as GadgetOutputVisual
					var mouse_pos := get_global_mouse_position()
					output_visual.point_b = output_visual.to_local(mouse_pos)
					output_control.global_position = mouse_pos - output_control.size / 2

					var target_gadget: Gadget
					var target_input: int

					var nearest_input_control: GadgetInputControl
					var nearest_input_control_distance := INF
					for input_control: GadgetInputControl in get_tree().get_nodes_in_group(&"GadgetInputControl"):
						var distance := mouse_pos.distance_squared_to(
							input_control.global_position + input_control.size / 2
						)
						if distance < 250 and distance < nearest_input_control_distance:
							nearest_input_control = input_control
							nearest_input_control_distance = distance

					if nearest_input_control:
						var new_target_gadget := nearest_input_control.get_parent().get_parent()
						var new_target_input := int(nearest_input_control.name.trim_prefix("GadgetInputControl"))
						# Prevent connecting to an input more than once
						if output_controls[output_index].any(func(other: GadgetOutputControl) -> bool:
							if other == output_control:
								return false
							if other.target_gadget != new_target_gadget:
								return false
							if other.target_input != new_target_input:
								return false
							return true
						):
							break
						output_visual.point_b = output_visual.to_local(
							nearest_input_control.global_position
							+ Vector2(0, nearest_input_control.size.y / 2)
						)
						output_control.global_position = (
							nearest_input_control.global_position
							+ Vector2(0, nearest_input_control.size.y / 2)
							- Vector2(output_control.size.x, output_control.size.y / 2)
						)
						target_gadget = new_target_gadget
						target_input = new_target_input

					if Input.is_action_just_pressed(&"action") and not _just_dragged_output:
						if target_gadget:
							# Connect Output
							update_connection.rpc(
								ConnectionChange.CONNECT,
								output_control.get_path(),
								target_gadget.get_path(),
								target_input
							)
						else:
							# Delete Output
							update_connection.rpc(
								ConnectionChange.DELETE,
								output_control.get_path(),
								NodePath(),
								output_control.target_input
							)
					elif Input.is_action_just_pressed(&"ui_cancel"):
						# Cancel
						update_connection.rpc(
							ConnectionChange.CANCEL,
							output_control.get_path(),
							output_control.target_gadget.get_path(),
							output_control.target_input
						)

					_just_dragged_output = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(node_3d):
			node_3d.queue_free()
		for output_index in output_controls.size():
			output(output_index, null)
			for output_control: GadgetOutputControl in output_controls[output_index]:
				var output_visual := _output_visuals[output_index][
					_find_nested_array_item(output_controls, output_control)[0]
				] as GadgetOutputVisual
				var gadget := output_control.target_gadget
				var input_index := output_control.target_input
				if is_instance_valid(gadget):
					var input_control := gadget.input_controls[input_index] as GadgetInputControl
					input_control.output_controls.erase(output_control)
					input_control.output_visuals.erase(output_visual)


func _put_in_array(value: Variant) -> Variant:
	return [value]


func _find_nested_array_item(array: Array, item: Variant) -> Array[int]:
	var value: Array[int] = [-1, -1]
	for i in array.size():
		value[0] = array[i].find(item)
		if value[0] != -1:
			value[1] = i
			break
	return value


func _get_port_position(port_count: int, port_index: int, side: Side) -> Vector2:
	var height := _PORT_SIZE * port_count + _PORT_SPACING * maxf(0, port_count - 1)
	var pos := _PORT_SIZE * port_index + _PORT_SPACING * port_index
	var y := size.y / 2.0 - height / 2.0 + pos
	match side:
		SIDE_LEFT:
			return Vector2(-_PORT_SIZE, y)
		SIDE_RIGHT:
			return Vector2(size.x, y)
	return Vector2.ZERO


func is_input_data_powered(input_index: int, unconnected_means_powered: bool) -> bool:
	var data: Variant = get_input_data(input_index)
	if data == null:
		return unconnected_means_powered
	else:
		return not is_zero_approx(data as float)


func get_input_data(input_index: int) -> Variant:
	var values: Array[Variant]
	var input_control := input_controls[input_index] as GadgetInputControl
	for output_control: GadgetOutputControl in input_control.output_controls:
		values.append(output_control.data)
	return values.max()


func output(output_index: int, data: Variant, pulse := false) -> void:
	for output_control: GadgetOutputControl in output_controls[output_index]:
		output_control.data = data
		if pulse and data != null:
			output_control.set_deferred(&"data", false)


func set_mouse_filters(value: MouseFilter, outputs_only := false) -> void:
	if not outputs_only:
		mouse_filter = value
		for input_control: GadgetInputControl in get_tree().get_nodes_in_group(&"GadgetInputControl"):
			input_control.mouse_filter = value
	for output_control: GadgetOutputControl in get_tree().get_nodes_in_group(&"GadgetOutputControl"):
		output_control.mouse_filter = value


@rpc("any_peer", "call_local")
func update_connection(
		connection_type: ConnectionChange,
		output_control_path: NodePath,
		gadget_path: NodePath,
		input_index: int,
		silent := false
) -> void:
	var output_control := get_node(output_control_path) as GadgetOutputControl
	var output_location := _find_nested_array_item(output_controls, output_control)
	var output_index := output_location[1]
	var output_visual := _output_visuals[output_index][output_location[0]] as GadgetOutputVisual

	if connection_type == ConnectionChange.DISCONNECT:
		if output_controls[output_index].back() != output_control:
			output_controls[output_index].pop_back().queue_free()
			_output_visuals[output_index].pop_back().queue_free()

		output_controls[output_index].erase(output_control)
		output_controls[output_index].append(output_control)
		_output_visuals[output_index].append(output_visual)
		_output_visuals[output_index].erase(output_visual)
	else:
		output_control.remove_from_group(&"Dragging")
		set_mouse_filters(MOUSE_FILTER_STOP, true)

	if connection_type == ConnectionChange.CONNECT:
		var gadget := get_node(gadget_path) as Gadget
		var input_control := gadget.input_controls[input_index] as GadgetInputControl
		output_visual.point_b = output_visual.to_local(
			input_control.global_position
			+ Vector2(0, input_control.size.y / 2)
		)
		output_control.global_position = (
			input_control.global_position
			+ Vector2(0, input_control.size.y / 2)
			- Vector2(output_control.size.x, output_control.size.y / 2)
		)

		var input_data: Variant = gadget.get_input_data(input_index)
		input_control.output_controls.append(output_control)
		input_control.output_visuals.append(output_visual)
		output_control.target_gadget = gadget
		output_control.target_input = input_index
		var input_data_with: Variant = gadget.get_input_data(input_index)
		if input_data != input_data_with:
			gadget.input_pulse.emit.bind(input_index).call_deferred()

		# Create New Output

		output_control = _OUTPUT_CONTROL_SCENE.instantiate()
		$OutputControls.add_child(output_control)
		output_control.name = str(output_controls_created_count)
		output_controls_created_count += 1
		output_control.position = _get_port_position(output_controls.size(), output_index, SIDE_RIGHT)
		var _error := output_control.mouse_entered.connect(_on_output_control_mouse_entered.bind(output_control))
		_error = output_control.mouse_exited.connect(_on_output_control_mouse_exited)
		_error = output_control.gui_input.connect(_on_output_control_gui_input.bind(output_control))
		output_control.data = output_controls[output_index].back().data
		output_control.tooltip_text = output_controls[output_index].back().tooltip_text
		output_controls[output_index].append(output_control)

		output_visual = _OUTPUT_VISUAL_SCENE.instantiate()
		$OutputVisuals.add_child(output_visual)
		output_visual.position = _get_port_position(_output_visuals.size(), output_index, SIDE_RIGHT) + Vector2(0, _PORT_SIZE / 2.0)
		_output_visuals[output_index].append(output_visual)
		output_control.visual = output_visual

		if not silent:
			Audio.play_sound("place")
	else:
		if connection_type == ConnectionChange.DELETE:
			output_visual.clear_points()
			output_control.position = _get_port_position(output_controls.size(), output_index, SIDE_RIGHT)
			Audio.play_sound("destroy")
		output_control.target_gadget = null

		var gadget := get_node_or_null(gadget_path) as Gadget
		if gadget:
			var input_control := gadget.input_controls[input_index] as GadgetInputControl
			var input_data: Variant = gadget.get_input_data(input_index)
			input_control.output_controls.erase(output_control)
			input_control.output_visuals.erase(output_visual)
			var input_data_without: Variant = gadget.get_input_data(input_index)
			if input_data != input_data_without and input_data_without != null:
				gadget.input_pulse.emit.bind(input_index).call_deferred()


func update_connection_positions() -> void:
	for output_index in output_controls.size():
		for output_control: GadgetOutputControl in output_controls[output_index]:
			if is_instance_valid(output_control.target_gadget):
				var output_visual := _output_visuals[output_index][
					_find_nested_array_item(output_controls, output_control)[0]
				] as GadgetOutputVisual
				var input_control := output_control.target_gadget.input_controls[
					output_control.target_input
				] as GadgetInputControl
				output_visual.point_b = output_visual.to_local(
					input_control.global_position
					+ Vector2(0, input_control.size.y / 2)
				)
				output_control.global_position = (
					input_control.global_position
					+ Vector2(0, input_control.size.y / 2)
					- Vector2(output_control.size.x, output_control.size.y / 2)
				)

	for input_control: GadgetInputControl in input_controls:
		for output_index in input_control.output_controls.size():
			var output_control := input_control.output_controls[output_index]
			var output_visual := input_control.output_visuals[output_index]
			if is_instance_valid(output_control):
				if is_queued_for_deletion():
					output_visual.clear_points()
					output_control.position = _get_port_position(output_controls.size(), output_index, SIDE_RIGHT)
				else:
					output_visual.point_b = output_visual.to_local(
						input_control.global_position
						+ Vector2(0, input_control.size.y / 2)
					)
					output_control.global_position = (
						input_control.global_position
						+ Vector2(0, input_control.size.y / 2)
						- Vector2(output_control.size.x, output_control.size.y / 2)
					)


@rpc("any_peer", "call_local")
func sync_meta(meta_name: StringName, value: Variant) -> void:
	set_meta(meta_name, value)



func attach_to_object(node_path: NodePath) -> void:
	var node := get_node(node_path)
	remove_child(node_3d)
	if node.get_parent() is VisualInstance3D:
		node.get_parent().add_child(node_3d)
		node_3d.position = node.get_parent().get_aabb().get_center()
	else:
		node.add_child(node_3d)
	var _error := node_3d.tree_exited.connect(queue_free)


func set_gadget_data(gadget_data: GadgetData) -> void:
	background.modulate = gadget_data.background
	icon.texture = gadget_data.icon

	var power := GadgetPortData.new()
	power.color = Color(0.75, 0.188, 0.188, 1.0)
	power.icon = _POWER_ICON
	power.name = "Power"
	var inputs := gadget_data.inputs.duplicate()
	inputs.push_front(power)

	size.y *= int((inputs.size() - 1) / 3.0) + 1

	var index := 0
	for input_port_data: GadgetPortData in inputs:
		var input_control := _INPUT_CONTROL_SCENE.instantiate() as GadgetInputControl
		input_control.icon = input_port_data.icon
		input_control.tooltip_text = input_port_data.name
		if input_port_data.color == Color.TRANSPARENT:
			input_control.self_modulate = gadget_data.background
		else:
			input_control.self_modulate = input_port_data.color
		$InputControls.add_child(input_control)
		input_control.name = "GadgetInputControl" + str(index)
		input_control.position = _get_port_position(inputs.size(), index, SIDE_LEFT)
		index += 1

	index = 0
	for output_port_data: GadgetPortData in gadget_data.outputs:
		var output_port := _OUTPUT_PORT_SCENE.instantiate() as GadgetOutputPort
		output_port.icon = output_port_data.icon
		if output_port_data.color == Color.TRANSPARENT:
			output_port.self_modulate = gadget_data.background
		else:
			output_port.self_modulate = output_port_data.color
		$OutputPorts.add_child(output_port)
		output_port.position = _get_port_position(gadget_data.outputs.size(), index, SIDE_RIGHT)

		var output_visual := _OUTPUT_VISUAL_SCENE.instantiate() as GadgetOutputVisual
		$OutputVisuals.add_child(output_visual)
		output_visual.position = _get_port_position(gadget_data.outputs.size(), index, SIDE_RIGHT) + Vector2(0, _PORT_SIZE / 2.0)

		var output_control := _OUTPUT_CONTROL_SCENE.instantiate() as GadgetOutputControl
		output_control.tooltip_text = output_port_data.name
		$OutputControls.add_child(output_control)
		output_control.name = str(output_controls_created_count)
		output_controls_created_count += 1
		output_control.position = _get_port_position(gadget_data.outputs.size(), index, SIDE_RIGHT)

		index += 1

	_output_visuals = $OutputVisuals.get_children().map(_put_in_array)
	input_controls = $InputControls.get_children()
	output_controls = $OutputControls.get_children().map(_put_in_array)

	for output_index in output_controls.size():
		var output_control := output_controls[output_index].front() as GadgetOutputControl
		var output_visual := _output_visuals[output_index].front() as GadgetOutputVisual
		output_control.visual = output_visual
		var _error := output_control.mouse_entered.connect(_on_output_control_mouse_entered.bind(output_control))
		_error = output_control.mouse_exited.connect(_on_output_control_mouse_exited)
		_error = output_control.gui_input.connect(_on_output_control_gui_input.bind(output_control))

	for i in input_controls.size():
		input_pulse.emit(i)

	start()


func _on_output_control_gui_input(event: InputEvent, output_control: GadgetOutputControl) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			# Start Dragging Output
			output_control.add_to_group(&"Dragging")
			set_mouse_filters(MOUSE_FILTER_IGNORE, true)
			if not is_instance_valid(output_control.target_gadget):
				output_control.target_gadget = null
			var target_gadget_path: NodePath
			if output_control.target_gadget:
				target_gadget_path = output_control.target_gadget.get_path()
			update_connection.rpc(
				ConnectionChange.DISCONNECT,
				output_control.get_path(),
				target_gadget_path,
				output_control.target_input
			)
			_just_dragged_output = true


func _on_output_control_mouse_entered(output_control: GadgetOutputControl) -> void:
	var output_visual := output_control.visual
	if output_visual:
		_highlight_line = output_visual.line.duplicate() as Line2D
		_highlight_line.position = output_visual.line.position
		_highlight_line.texture = _CABLE_HIGHLIGHT
		_highlight_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		output_visual.line.get_parent().add_child(_highlight_line)


func _on_output_control_mouse_exited() -> void:
	if is_instance_valid(_highlight_line):
		_highlight_line.queue_free()


func _on_gui_input(event: InputEvent) -> void:
	var event_touch := event as InputEventScreenTouch
	var event_mouse_button := event as InputEventMouseButton
	if event_touch and event_touch.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			# Start Dragging Gadget
			top_level = true
			add_to_group(&"Dragging")
			set_mouse_filters(MOUSE_FILTER_IGNORE)
			accept_event()
	elif event_mouse_button and event_mouse_button.is_pressed() and event_mouse_button.button_index == 2:
		open_properties.emit()
