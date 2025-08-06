class_name GadgetProperties
extends Panel


signal gadget_changed

const TITLE_LABEL_SETTINGS = preload("res://title_label_settings.tres")

@export var vbox: VBoxContainer


func open(type: StringName, gadget: Gadget) -> void:
	var _error := gadget_changed.connect(func() -> void:
		for n: Node in vbox.get_children():
			n.name = "Free" + str(n.get_index())
			n.queue_free()
	, Object.CONNECT_ONE_SHOT)

	visible = true

	var label := Label.new()
	label.label_settings = TITLE_LABEL_SETTINGS
	label.text = tr(type)
	vbox.add_child(label)

	gadget.setup_properties(self)


func add_slider(label_prefix: String,
				property_names: Array[StringName],
				default_value: Variant,
				min_value: float,
				max_value: float,
				step: float,
				gadget: Gadget) -> Slider:
	var control_name := get_control_name(label_prefix)

	var label := Label.new()
	label.name = control_name + "Label"
	vbox.add_child(label)

	var slider := HSlider.new()
	slider.name = control_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	for property_name: StringName in property_names:
		slider.value = gadget.get_meta(property_name, default_value)
	slider.add_user_signal("update_text")
	var _obj_connect_error := slider.connect(&"update_text", func(value: float) -> void:
		sync_label_text.rpc(label.get_path(), get_slider_label_text(label_prefix, value, slider.step))
	)
	var _sig_connect_error := slider.value_changed.connect(func(value: float) -> void:
		sync_slider_value.rpc(slider.get_path(), value)
		for property_name: StringName in property_names:
			if gadget:
				gadget.change_property.rpc(property_name, value)
				gadget.sync_meta.rpc(property_name, value)
		var _emit_error := slider.emit_signal(&"update_text", value)
	)
	vbox.add_child(slider)

	_sig_connect_error = slider.visibility_changed.connect(func() -> void:
		label.visible = slider.visible
	)

	label.text = get_slider_label_text(label_prefix, slider.value, slider.step)

	return slider


func get_slider_label_text(label_prefix: String, slider_value: float, step: float) -> String:
	var step_str := str(step).rstrip("0")
	var decimal_places := step_str.get_slice(".", 1).length()
	return "%s%.*f" % [tr(label_prefix), decimal_places, slider_value]


func get_control_name(text: String) -> String:
	var regex := RegEx.new()
	var _regex_error := regex.compile("[^A-Za-z]")
	return regex.sub(text.to_pascal_case(), "", true)


@rpc("any_peer")
func sync_checkbox_pressed(checkbox_path: NodePath, value: bool) -> void:
	var checkbox := get_node_or_null(checkbox_path) as CheckBox
	if checkbox:
		checkbox.set_pressed_no_signal(value)


@rpc("any_peer")
func sync_slider_value(slider_path: NodePath, value: float) -> void:
	var slider := get_node_or_null(slider_path) as Slider
	if slider:
		slider.set_value_no_signal(value)


@rpc("any_peer")
func sync_slider_max_value(slider_path: NodePath, value: float) -> void:
	var slider := get_node_or_null(slider_path) as Slider
	if slider:
		slider.max_value = value


@rpc("any_peer", "call_local")
func sync_label_text(label_path: NodePath, value: String) -> void:
	var label := get_node_or_null(label_path) as Label
	if label:
		label.text = value


@rpc("any_peer")
func sync_option_button_item_selected(option_button_path: NodePath, value: int) -> void:
	var option_button := get_node_or_null(option_button_path) as OptionButton
	if option_button:
		option_button.selected = value


@rpc("any_peer", "call_local")
func sync_control_visible(control_path: NodePath, value: bool) -> void:
	var control := get_node_or_null(control_path) as Control
	if control:
		control.visible = value


@rpc("any_peer", "call_local")
func sync_emit_signal(node_path: NodePath, signal_name: StringName, ...args: Array) -> void:
	var node := get_node_or_null(node_path) as Node
	if node and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.callv(&"emit_signal", [signal_name] + args)
