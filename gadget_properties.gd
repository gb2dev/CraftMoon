class_name GadgetProperties
extends Panel


signal gadget_changed

const SOUND_SELECT = preload("res://sound_select.tscn")
const TITLE_LABEL_SETTINGS = preload("res://title_label_settings.tres")

@export var vbox: VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func open(type: StringName, gadget: Gadget) -> void:
	for n: Node in vbox.get_children():
		n.queue_free()

	visible = true

	var label := Label.new()
	label.label_settings = TITLE_LABEL_SETTINGS
	label.text = tr(type)
	vbox.add_child(label)

	match type:
		&"Audio Gadget":
			gadget.area_visual.show()
			gadget_changed.connect(gadget.area_visual.hide, Object.CONNECT_ONE_SHOT)

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
			file_dialog.file_selected.connect(func(path: String) -> void:
				gadget.change_property(&"Sound", path)
				select_sound_label.text = selected_sound_prefix + path
				gadget.set_meta(&"Sound", path)
				gadget.set_meta(&"SoundName", path)
			)
			vbox.add_child(file_dialog)

			var custom_button := Button.new()
			custom_button.text = "Select Custom Sound"
			custom_button.pressed.connect(file_dialog.popup)
			vbox.add_child(custom_button)

			var sound_select_instance := SOUND_SELECT.instantiate() as SoundSelect
			sound_select_instance.select_sound.connect(
				func(sound: String, sound_name: String) -> void:
					var path := "res://sounds/" + sound + ".wav"
					gadget.change_property(&"Sound", path)
					select_sound_label.text = selected_sound_prefix + sound_name
					gadget.set_meta(&"Sound", path)
					gadget.set_meta(&"SoundName", sound_name)
			)
			vbox.add_child(sound_select_instance)

			var library_button := Button.new()
			library_button.text = "Select Library Sound"
			library_button.pressed.connect(sound_select_instance.show)
			vbox.add_child(library_button)

			add_slider("Range: ", &"Range", 2, 0.1, 50, 0.1, gadget)

			add_slider("Volume: ", &"Volume", 1, 0, 1, 0.01, gadget)

			var loop_checkbox := CheckBox.new()
			loop_checkbox.text = "Loop"
			loop_checkbox.button_pressed = gadget.get_meta(&"Loop", false)
			loop_checkbox.pressed.connect(func() -> void:
				gadget.change_property(&"Loop", loop_checkbox.button_pressed)
				gadget.set_meta(&"Loop", loop_checkbox.button_pressed)
			)
			vbox.add_child(loop_checkbox)

			var threed_checkbox := CheckBox.new()
			threed_checkbox.text = "3D"
			threed_checkbox.button_pressed = gadget.get_meta(&"ThreeD", false)
			threed_checkbox.pressed.connect(func() -> void:
				gadget.change_property(&"ThreeD", threed_checkbox.button_pressed)
				gadget.set_meta(&"ThreeD", threed_checkbox.button_pressed)
			)
			vbox.add_child(threed_checkbox)
		&"Trigger Zone Gadget":
			gadget.area_visual.show()
			gadget_changed.connect(gadget.area_visual.hide, Object.CONNECT_ONE_SHOT)

			var shape_option := OptionButton.new()
			shape_option.add_item("Ellipsoid")
			shape_option.add_item("Cuboid")
			shape_option.selected = gadget.get_meta(&"ZoneShape", 0)
			shape_option.item_selected.connect(func(index: int) -> void:
				gadget.change_property(&"ZoneShape", index)
				gadget.set_meta(&"ZoneShape", index)
			)
			vbox.add_child(shape_option)

			add_slider("Zone width: ", &"ZoneWidth", 2, 0.1, 50, 0.1, gadget)
			add_slider("Zone height: ", &"ZoneHeight", 2, 0.1, 50, 0.1, gadget)
			add_slider("Zone depth: ", &"ZoneDepth", 2, 0.1, 50, 0.1, gadget)
		&"Look Sensor Gadget":
			pass
		&"Timer Gadget":
			var oneshot_checkbox := CheckBox.new()
			oneshot_checkbox.text = "One shot"
			oneshot_checkbox.button_pressed = gadget.get_meta(&"OneShot", true)
			oneshot_checkbox.pressed.connect(func() -> void:
				gadget.change_property(&"OneShot", oneshot_checkbox.button_pressed)
				gadget.set_meta(&"OneShot", oneshot_checkbox.button_pressed)
			)
			vbox.add_child(oneshot_checkbox)

			add_slider("Wait time: ", &"WaitTime", 1, 0.1, 60, 0.1, gadget)
		&"Counter Gadget":
			var current := add_slider(
				"Current count: ",
				&"CurrentCount",
				0,
				0,
				gadget.get_meta(&"TargetCount", 1),
				1,
				gadget
			)
			var target := add_slider("Target count: ", &"TargetCount", 1, 1, 100, 1, gadget)
			target.value_changed.connect(func(value: float) -> void:
				current.max_value = value
			)
			var update_value := func(value: float) -> void:
				if current:
					current.value = value
			gadget.property_update.connect(update_value)
			gadget_changed.connect(
				gadget.property_update.disconnect.bind(update_value),
				Object.CONNECT_ONE_SHOT
			)
		&"Mover Gadget":
			add_slider("Movement direction X: ", &"MovementDirectionX", 0, -100, 100, 0.1, gadget)
			add_slider("Movement direction Y: ", &"MovementDirectionY", 0, -100, 100, 0.1, gadget)
			add_slider("Movement direction Z: ", &"MovementDirectionZ", 0, -100, 100, 0.1, gadget)


func add_slider(label_prefix: String,
				property_name: StringName,
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
	slider.value = gadget.get_meta(property_name, default_value)
	slider.value_changed.connect(func(value: float) -> void:
		gadget.change_property(property_name, value)
		label.text = label_prefix + str(snappedf(value, step))
		gadget.set_meta(property_name, value)
	)
	vbox.add_child(slider)

	label.text = label_prefix + str(snappedf(slider.value, step))

	return slider
