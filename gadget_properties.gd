class_name GadgetProperties
extends Panel


signal gadget_changed

const SOUND_SELECT = preload("res://sound_select.tscn")
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

	# TODO: move inside the gadget scripts
	match type:
		&"Audio Gadget":
			const SELECTED_SOUND_PREFIX = "Selected sound: "

			var select_sound_label := Label.new()
			select_sound_label.name = get_control_name(SELECTED_SOUND_PREFIX)
			select_sound_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			select_sound_label.text = SELECTED_SOUND_PREFIX + gadget.get_meta(&"SoundName", "None")
			vbox.add_child(select_sound_label)

			var file_dialog := FileDialog.new()
			file_dialog.use_native_dialog = true
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.set_filters(["*.ogg ; OGG Vorbis Sounds"])
			_error = file_dialog.file_selected.connect(func(path: String) -> void:
				gadget.change_property.rpc(&"Sound", path)
				sync_label_text.rpc(select_sound_label.get_path(), SELECTED_SOUND_PREFIX + path)
				gadget.sync_meta.rpc(&"Sound", path)
				gadget.sync_meta.rpc(&"SoundName", path)
			)
			vbox.add_child(file_dialog)

			var custom_button := Button.new()
			custom_button.text = "Select Custom Sound"
			_error = custom_button.pressed.connect(file_dialog.popup)
			vbox.add_child(custom_button)

			var sound_select_instance := SOUND_SELECT.instantiate() as SoundSelect
			_error = sound_select_instance.select_sound.connect(
				func(sound_name: String, text: String) -> void:
					var path := Audio.sounds[sound_name]
					gadget.change_property.rpc(&"Sound", path)
					sync_label_text.rpc(select_sound_label.get_path(), SELECTED_SOUND_PREFIX + text)
					gadget.sync_meta.rpc(&"Sound", path)
					gadget.sync_meta.rpc(&"SoundName", text)
			)
			vbox.add_child(sound_select_instance)

			var library_button := Button.new()
			library_button.text = "Select Library Sound"
			_error = library_button.pressed.connect(sound_select_instance.show)
			vbox.add_child(library_button)

			var _slider := add_slider("Volume: ", [&"Volume"], 1, 0, 1, 0.01, gadget)

			var loop_checkbox := CheckBox.new()
			loop_checkbox.text = "Loop"
			loop_checkbox.name = get_control_name(loop_checkbox.text)
			loop_checkbox.button_pressed = gadget.get_meta(&"Loop", false)
			_error = loop_checkbox.pressed.connect(func() -> void:
				gadget.change_property.rpc(&"Loop", loop_checkbox.button_pressed)
				gadget.sync_meta.rpc(&"Loop", loop_checkbox.button_pressed)
				sync_checkbox_pressed.rpc(loop_checkbox.get_path(), loop_checkbox.button_pressed)
			)
			vbox.add_child(loop_checkbox)

			var threed_checkbox := CheckBox.new()
			threed_checkbox.text = "3D"
			threed_checkbox.name = get_control_name(threed_checkbox.text)
			threed_checkbox.button_pressed = gadget.get_meta(&"ThreeD", false)
			_error = threed_checkbox.pressed.connect(func() -> void:
				gadget.change_property.rpc(&"ThreeD", threed_checkbox.button_pressed)
				gadget.sync_meta.rpc(&"ThreeD", threed_checkbox.button_pressed)
				sync_checkbox_pressed.rpc(threed_checkbox.get_path(), threed_checkbox.button_pressed)
			)
			vbox.add_child(threed_checkbox)
		&"Trigger Zone Gadget":
			gadget.area_visual.show()
			_error = gadget_changed.connect(gadget.area_visual.hide, Object.CONNECT_ONE_SHOT)

			var shape_option := OptionButton.new()
			shape_option.name = "ZoneShape"
			shape_option.add_item("Sphere")
			shape_option.add_item("Cuboid")
			shape_option.selected = gadget.get_meta(&"ZoneShape", 0)
			vbox.add_child(shape_option)

			const ZONE_SIZE_PREFIX = "Zone size: "
			var size_slider := add_slider(ZONE_SIZE_PREFIX, [&"ZoneWidth", &"ZoneHeight", &"ZoneDepth"], 2, 0.1, 50, 0.1, gadget)
			size_slider.name = get_control_name(ZONE_SIZE_PREFIX)

			const ZONE_WIDTH_PREFIX = "Zone width: "
			var width_slider := add_slider(ZONE_WIDTH_PREFIX, [&"ZoneWidth"], 2, 0.1, 50, 0.1, gadget)
			width_slider.name = get_control_name(ZONE_WIDTH_PREFIX)

			const ZONE_HEIGHT_PREFIX = "Zone height: "
			var height_slider := add_slider(ZONE_HEIGHT_PREFIX, [&"ZoneHeight"], 2, 0.1, 50, 0.1, gadget)
			height_slider.name = get_control_name(ZONE_HEIGHT_PREFIX)

			const ZONE_DEPTH_PREFIX = "Zone depth: "
			var depth_slider := add_slider(ZONE_DEPTH_PREFIX, [&"ZoneDepth"], 2, 0.1, 50, 0.1, gadget)
			depth_slider.name = get_control_name(ZONE_DEPTH_PREFIX)

			var item_selected := func(index: int) -> void:
				sync_option_button_item_selected.rpc(shape_option.get_path(), index)
				gadget.sync_meta.rpc(&"ZoneShape", index)
				var is_uniform_scale := index == 0
				sync_control_visible.rpc(size_slider.get_path(), is_uniform_scale)
				sync_control_visible.rpc(width_slider.get_path(), not is_uniform_scale)
				sync_control_visible.rpc(height_slider.get_path(), not is_uniform_scale)
				sync_control_visible.rpc(depth_slider.get_path(), not is_uniform_scale)
				if is_uniform_scale:
					sync_emit_signal.rpc(size_slider.get_path(), &"value_changed", size_slider.value)
					gadget.change_property.rpc.call_deferred(&"ZoneShape", index)
				else:
					gadget.change_property.rpc(&"ZoneShape", index)
					sync_emit_signal.rpc(width_slider.get_path(), &"value_changed", width_slider.value)
					sync_emit_signal.rpc(height_slider.get_path(), &"value_changed", height_slider.value)
					sync_emit_signal.rpc(depth_slider.get_path(), &"value_changed", depth_slider.value)

			_error = shape_option.item_selected.connect(item_selected)

			item_selected.call(shape_option.selected)
		&"Look Sensor Gadget":
			pass
		&"Timer Gadget":
			var oneshot_checkbox := CheckBox.new()
			oneshot_checkbox.text = "One shot"
			oneshot_checkbox.name = get_control_name(oneshot_checkbox.text)
			oneshot_checkbox.button_pressed = gadget.get_meta(&"OneShot", true)
			_error = oneshot_checkbox.pressed.connect(func() -> void:
				gadget.change_property.rpc(&"OneShot", oneshot_checkbox.button_pressed)
				gadget.sync_meta.rpc(&"OneShot", oneshot_checkbox.button_pressed)
				sync_checkbox_pressed.rpc(oneshot_checkbox.get_path(), oneshot_checkbox.button_pressed)
			)
			vbox.add_child(oneshot_checkbox)

			var _slider := add_slider("Wait time: ", [&"WaitTime"], 1, 0.1, 60, 0.1, gadget)
		&"Counter Gadget":
			var current := add_slider(
				"Current count: ",
				[&"CurrentCount"],
				0,
				0,
				gadget.get_meta(&"TargetCount", 1),
				1,
				gadget
			)
			var target := add_slider("Target count: ", [&"TargetCount"], 1, 1, 100, 1, gadget)
			var _connect_error := target.value_changed.connect(func(value: float) -> void:
				current.max_value = value
				sync_slider_max_value.rpc(current.get_path(), value)
			)
			var update_value := func(value: float) -> void:
				if current:
					current.set_value_no_signal(value)
					var _emit_error := current.emit_signal(&"update_text", value)
			_connect_error = gadget.property_update.connect(update_value)
			_connect_error = gadget_changed.connect(
				gadget.property_update.disconnect.bind(update_value),
				Object.CONNECT_ONE_SHOT
			)
		&"Mover Gadget":
			var _slider := add_slider("Movement direction X: ", [&"MovementDirectionX"], 0, -100, 100, 0.1, gadget)
			_slider = add_slider("Movement direction Y: ", [&"MovementDirectionY"], 0, -100, 100, 0.1, gadget)
			_slider = add_slider("Movement direction Z: ", [&"MovementDirectionZ"], 0, -100, 100, 0.1, gadget)


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
		sync_label_text.rpc(label.get_path(), tr(label_prefix) + str(snappedf(value, step)))
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

	label.text = tr(label_prefix) + str(snappedf(slider.value, step))

	return slider


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
