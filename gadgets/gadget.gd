@abstract
class_name Gadget
extends TextureRect


signal input_pulse(input_index: int)
signal open_properties
signal property_update(value: Variant)

enum ConnectionChange {
	CONNECT,
	DISCONNECT,
	DELETE,
	CANCEL,
}

const _OUTPUT_VISUAL_SCENE = preload("res://gadgets/gadget_output_visual.tscn")
const _OUTPUT_CONTROL_SCENE = preload("res://gadgets/gadget_output_control.tscn")
const _OUTPUT_PORT_WIDTH = 16
const _CABLE_HIGHLIGHT = preload("res://textures/cable_highlight.tres")
const _SOUND_PLACE = preload("res://sounds/place.wav")
const _SOUND_DESTROY = preload("res://sounds/destroy.wav")

@onready var _output_visuals := $OutputVisuals.get_children().map(_put_in_array)
@onready var node_3d := $"3D" as Node3D
@onready var input_controls := $InputControls.get_children()
@onready var output_controls := $OutputControls.get_children().map(_put_in_array)

var _just_dragged_output := false
var _randomoutput_controls: Array
var _highlight_line: Line2D
var _audio_player: AudioStreamPlayer
var type: String


@abstract func start() -> void
@abstract func tick(delta: float) -> void
@abstract func change_property(property: StringName, value: Variant) -> void


func _ready() -> void:
	for output_index in output_controls.size():
		var output_control := output_controls[output_index].front() as OutputControl
		var output_visual := _output_visuals[output_index].front() as OutputVisual
		output_control.visual = output_visual
		var _error := output_control.mouse_entered.connect(_on_output_control_mouse_entered.bind(output_control))
		_error = output_control.mouse_exited.connect(_on_output_control_mouse_exited)
		_error = output_control.gui_input.connect(_on_output_control_gui_input.bind(output_control))
	set_mouse_filters(MOUSE_FILTER_IGNORE)
	for i in input_controls.size():
		input_data_changed.call_deferred(i)
	start()


func _process(delta: float) -> void:
	tick(delta)

	if is_in_group(&"Dragging") and not is_in_group(&"GridSnap"):
		# Dragging Gadget without Grid Snap
		position = get_global_mouse_position() - size / 2

		update_connection_positions()
	else:
		for output_index in output_controls.size():
			for output_control: OutputControl in output_controls[output_index]:
				if output_control.is_in_group(&"Dragging"):
					# Dragging Output
					var output_visual := _output_visuals[output_index][
						_find_nested_array_item(output_controls, output_control)[0]
					] as OutputVisual
					var mouse_pos := get_global_mouse_position()
					output_visual.point_b = output_visual.to_local(mouse_pos)
					output_control.global_position = mouse_pos - output_control.size / 2

					var target_gadget: Gadget
					var target_input: int

					var nearest_input_control: InputControl
					var nearest_input_control_distance := INF
					for input_control: InputControl in get_tree().get_nodes_in_group(&"InputControl"):
						var distance := mouse_pos.distance_squared_to(
							input_control.global_position + input_control.size / 2
						)
						if distance < 250 and distance < nearest_input_control_distance:
							nearest_input_control = input_control
							nearest_input_control_distance = distance

					if nearest_input_control:
						var new_target_gadget := nearest_input_control.get_parent().get_parent()
						var new_target_input := int(nearest_input_control.name.trim_prefix("InputControl"))
						# Prevent connecting to an input more than once
						if output_controls[output_index].any(func(other: OutputControl) -> bool:
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
							update_connection(
								ConnectionChange.CONNECT,
								output_control,
								target_gadget,
								target_input
							)
						else:
							# Delete Output
							update_connection(
								ConnectionChange.DELETE,
								output_control,
								output_control.target_gadget,
								output_control.target_input
							)
					elif Input.is_action_just_pressed(&"ui_cancel"):
						# Cancel
						update_connection(
							ConnectionChange.CANCEL,
							output_control,
							output_control.target_gadget,
							output_control.target_input
						)

					_just_dragged_output = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(node_3d):
			node_3d.queue_free()
		for output_index in output_controls.size():
			output(output_index, null)
			for output_control: OutputControl in output_controls[output_index]:
				var output_visual := _output_visuals[output_index][
					_find_nested_array_item(output_controls, output_control)[0]
				] as OutputVisual
				var gadget := output_control.target_gadget
				var input_index := output_control.target_input
				if is_instance_valid(gadget):
					var input_control := gadget.input_controls[input_index] as InputControl
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


func is_input_data_powered(input_index: int, unconnected_means_powered: bool) -> bool:
	var data: Variant = get_input_data(input_index)
	if data == null:
		return unconnected_means_powered
	else:
		return not is_zero_approx(data as float)


func get_input_data(input_index: int) -> Variant:
	var values: Array[Variant]
	var input_control := input_controls[input_index] as InputControl
	for output_control: OutputControl in input_control.output_controls:
		values.append(output_control.data)
	return values.max()


func output(output_index: int, data: Variant, pulse := false, random := false) -> void:
	for output_control: OutputControl in output_controls[output_index]:
		if not random:
			output_control.data = data
		if pulse and data != null:
			output_control.set_deferred(&"data", false)

	# TODO: move inside Randomizer Gadget script
	if random:
		if _randomoutput_controls.is_empty():
			_randomoutput_controls = output_controls[output_index].duplicate()
			var _error := _randomoutput_controls.resize(_randomoutput_controls.size() - 1)
			_randomoutput_controls.shuffle()

		if not _randomoutput_controls.is_empty():
			_randomoutput_controls.pop_back().data = data


func input_data_changed(input_index: int) -> void:
	input_pulse.emit(input_index)


func set_mouse_filters(value: MouseFilter, outputs_only := false) -> void:
	if not outputs_only:
		mouse_filter = value
		for input_control: InputControl in get_tree().get_nodes_in_group(&"InputControl"):
			input_control.mouse_filter = value
	for output_control: OutputControl in get_tree().get_nodes_in_group(&"OutputControl"):
		output_control.mouse_filter = value


func update_connection(
		connection_type: ConnectionChange,
		output_control: OutputControl,
		gadget: Gadget,
		input_index: int,
		silent := false
) -> void:
	var output_location := _find_nested_array_item(output_controls, output_control)
	var output_index := output_location[1]
	var output_visual := _output_visuals[output_index][output_location[0]] as OutputVisual

	if connection_type == ConnectionChange.DISCONNECT:
		if gadget:
			gadget.input_data_changed.call_deferred(input_index)

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

	prints(
		["CONNECT", "DISCONNECT", "DELETE", "CANCEL"][connection_type],
		"OUTPUT",
		output_index,
		"OF",
		self,
		"TO INPUT",
		input_index,
		"OF",
		gadget
	)

	if connection_type == ConnectionChange.CONNECT:
		var input_control := gadget.input_controls[input_index] as InputControl
		output_visual.point_b = output_visual.to_local(
			input_control.global_position
			+ Vector2(0, input_control.size.y / 2)
		)
		output_control.global_position = (
			input_control.global_position
			+ Vector2(0, input_control.size.y / 2)
			- Vector2(output_control.size.x, output_control.size.y / 2)
		)

		input_control.output_controls.append(output_control)
		input_control.output_visuals.append(output_visual)
		output_control.target_gadget = gadget
		output_control.target_input = input_index
		gadget.input_data_changed(input_index)

		# Create New Output
		# TODO Fix for multiple outputs

		output_control = _OUTPUT_CONTROL_SCENE.instantiate()
		$OutputControls.add_child(output_control)
		var _error := output_control.mouse_entered.connect(_on_output_control_mouse_entered.bind(output_control))
		_error = output_control.mouse_exited.connect(_on_output_control_mouse_exited)
		_error = output_control.gui_input.connect(_on_output_control_gui_input.bind(output_control))
		output_control.data = output_controls[output_index].back().data
		output_control.tooltip_text = output_controls[output_index].back().tooltip_text
		output_control.add_to_group(&"OutputControl")
		output_controls[output_index].append(output_control)

		output_visual = _OUTPUT_VISUAL_SCENE.instantiate()
		$OutputVisuals.add_child(output_visual)
		output_visual.position = Vector2(size.x + _OUTPUT_PORT_WIDTH, _OUTPUT_PORT_WIDTH * 2)
		_output_visuals[output_index].append(output_visual)
		output_control.visual = output_visual

		if not silent:
			_audio_player.stream = _SOUND_PLACE
			_audio_player.play()
	else:
		if connection_type == ConnectionChange.DELETE:
			output_visual.clear_points()
			output_control.global_position = output_visual.global_position - Vector2(_OUTPUT_PORT_WIDTH, output_control.size.y / 2)
			_audio_player.stream = _SOUND_DESTROY
			_audio_player.play()
		output_control.target_gadget = null

		if gadget:
			var input_control := gadget.input_controls[input_index] as InputControl
			input_control.output_controls.erase(output_control)
			input_control.output_visuals.erase(output_visual)


func update_connection_positions() -> void:
	for output_index in output_controls.size():
		for output_control: OutputControl in output_controls[output_index]:
			if is_instance_valid(output_control.target_gadget):
				var output_visual := _output_visuals[output_index][
					_find_nested_array_item(output_controls, output_control)[0]
				] as OutputVisual
				var input_control := output_control.target_gadget.input_controls[
					output_control.target_input
				] as InputControl
				output_visual.point_b = output_visual.to_local(
					input_control.global_position
					+ Vector2(0, input_control.size.y / 2)
				)
				output_control.global_position = (
					input_control.global_position
					+ Vector2(0, input_control.size.y / 2)
					- Vector2(output_control.size.x, output_control.size.y / 2)
				)

	for input_control: InputControl in input_controls:
		for output_index in input_control.output_controls.size():
			var output_control := input_control.output_controls[output_index]
			var output_visual := input_control.output_visuals[output_index]
			if is_instance_valid(output_control):
				if is_queued_for_deletion():
					output_visual.clear_points()
					output_control.position = (
						output_visual.position
						- Vector2(0, output_control.size.y / 2)
					)
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


func attach_to_object(o: Node3D) -> void:
	remove_child(node_3d)
	if o.get_parent() is VisualInstance3D:
		o.get_parent().add_child(node_3d)
		node_3d.position = o.get_parent().get_aabb().get_center()
	else:
		o.add_child(node_3d)


func set_icon(t: Texture2D) -> void:
	texture = t


func _on_output_control_gui_input(event: InputEvent, output_control: OutputControl) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			# Start Dragging Output
			output_control.add_to_group(&"Dragging")
			set_mouse_filters(MOUSE_FILTER_IGNORE, true)
			if not is_instance_valid(output_control.target_gadget):
				output_control.target_gadget = null
			update_connection(
				ConnectionChange.DISCONNECT,
				output_control,
				output_control.target_gadget,
				output_control.target_input
			)
			_just_dragged_output = true


func _on_output_control_mouse_entered(output_control: OutputControl) -> void:
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
