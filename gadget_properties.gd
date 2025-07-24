class_name GadgetProperties
extends Panel


signal gadget_changed

const SOUND_SELECT = preload("res://sound_select.tscn")
const TITLE_LABEL_SETTINGS = preload("res://title_label_settings.tres")

@export var vbox: VBoxContainer


func open(type: StringName, gadget: Gadget) -> void:
	for n: Node in vbox.get_children():
		n.queue_free()

	visible = true

	var label := Label.new()
	label.label_settings = TITLE_LABEL_SETTINGS
	label.text = tr(type)
	vbox.add_child(label)

	# TODO: move inside the gadget scripts
	match type:
		&"Audio Gadget":
			const selected_sound_prefix = "Selected sound: "

			var select_sound_label := Label.new()
			select_sound_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			select_sound_label.text = selected_sound_prefix + gadget.get_meta(&"SoundName", "None")
			vbox.add_child(select_sound_label)

			var file_dialog := FileDialog.new()
			file_dialog.use_native_dialog = true
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.set_filters(["*.ogg ; OGG Vorbis Sounds"])
			var _error := file_dialog.file_selected.connect(func(path: String) -> void:
				gadget.change_property(&"Sound", path)
				select_sound_label.text = selected_sound_prefix + path
				gadget.set_meta(&"Sound", path)
				gadget.set_meta(&"SoundName", path)
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
					gadget.change_property(&"Sound", path)
					select_sound_label.text = selected_sound_prefix + text
					gadget.set_meta(&"Sound", path)
					gadget.set_meta(&"SoundName", text)
			)
			vbox.add_child(sound_select_instance)

			var library_button := Button.new()
			library_button.text = "Select Library Sound"
			_error = library_button.pressed.connect(sound_select_instance.show)
			vbox.add_child(library_button)

			var _slider := add_slider("Volume: ", [&"Volume"], 1, 0, 1, 0.01, gadget)

			var loop_checkbox := CheckBox.new()
			loop_checkbox.text = "Loop"
			loop_checkbox.button_pressed = gadget.get_meta(&"Loop", false)
			_error = loop_checkbox.pressed.connect(func() -> void:
				gadget.change_property(&"Loop", loop_checkbox.button_pressed)
				gadget.set_meta(&"Loop", loop_checkbox.button_pressed)
			)
			vbox.add_child(loop_checkbox)

			var threed_checkbox := CheckBox.new()
			threed_checkbox.text = "3D"
			threed_checkbox.button_pressed = gadget.get_meta(&"ThreeD", false)
			_error = threed_checkbox.pressed.connect(func() -> void:
				gadget.change_property(&"ThreeD", threed_checkbox.button_pressed)
				gadget.set_meta(&"ThreeD", threed_checkbox.button_pressed)
			)
			vbox.add_child(threed_checkbox)
		&"Trigger Zone Gadget":
			gadget.area_visual.show()
			var _error := gadget_changed.connect(gadget.area_visual.hide, Object.CONNECT_ONE_SHOT)

			var shape_option := OptionButton.new()
			shape_option.add_item("Sphere")
			shape_option.add_item("Cuboid")
			shape_option.selected = gadget.get_meta(&"ZoneShape", 0)
			vbox.add_child(shape_option)

			var size_slider := add_slider("Zone size: ", [&"ZoneWidth", &"ZoneHeight", &"ZoneDepth"], 2, 0.1, 50, 0.1, gadget)
			var width_slider := add_slider("Zone width: ", [&"ZoneWidth"], 2, 0.1, 50, 0.1, gadget)
			var height_slider := add_slider("Zone height: ", [&"ZoneHeight"], 2, 0.1, 50, 0.1, gadget)
			var depth_slider := add_slider("Zone depth: ", [&"ZoneDepth"], 2, 0.1, 50, 0.1, gadget)

			var item_selected := func(index: int) -> void:
				gadget.set_meta(&"ZoneShape", index)
				var is_uniform_scale := index == 0
				size_slider.visible = is_uniform_scale
				width_slider.visible = not is_uniform_scale
				height_slider.visible = not is_uniform_scale
				depth_slider.visible = not is_uniform_scale
				if is_uniform_scale:
					size_slider.value_changed.emit(size_slider.value)
					gadget.change_property.call_deferred(&"ZoneShape", index)
				else:
					gadget.change_property(&"ZoneShape", index)
					width_slider.value_changed.emit(width_slider.value)
					height_slider.value_changed.emit(height_slider.value)
					depth_slider.value_changed.emit(depth_slider.value)

			_error = shape_option.item_selected.connect(item_selected)

			item_selected.call(0)
		&"Look Sensor Gadget":
			pass
		&"Timer Gadget":
			var oneshot_checkbox := CheckBox.new()
			oneshot_checkbox.text = "One shot"
			oneshot_checkbox.button_pressed = gadget.get_meta(&"OneShot", true)
			var _error := oneshot_checkbox.pressed.connect(func() -> void:
				gadget.change_property(&"OneShot", oneshot_checkbox.button_pressed)
				gadget.set_meta(&"OneShot", oneshot_checkbox.button_pressed)
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
			var _error := target.value_changed.connect(func(value: float) -> void:
				current.max_value = value
			)
			var update_value := func(value: float) -> void:
				if current:
					current.value = value
			_error = gadget.property_update.connect(update_value)
			_error = gadget_changed.connect(
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
	var label := Label.new()
	vbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	for property_name: StringName in property_names:
		slider.value = gadget.get_meta(property_name, default_value)
	var _error := slider.value_changed.connect(func(value: float) -> void:
		for property_name: StringName in property_names:
			gadget.change_property(property_name, value)
			gadget.set_meta(property_name, value)
		label.text = label_prefix + str(snappedf(value, step))
	)
	vbox.add_child(slider)

	_error = slider.visibility_changed.connect(func() -> void:
		label.visible = slider.visible
	)

	label.text = label_prefix + str(snappedf(slider.value, step))

	return slider
