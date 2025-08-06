extends Gadget


const SOUND_SELECT = preload("res://sound_select.tscn")

var audio_player: Node
var is_pulse: bool


func start() -> void:
	change_property(&"ThreeD", false) # Initialize with standard AudioStreamPlayer

	var _error := input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0, true):
			is_pulse = false
			audio_player.play()
			check_pulse.call_deferred()
	)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"Sound":
			if value.begins_with("res://"):
				audio_player.stream = load(value as String)
			else:
				audio_player.stream = AudioStreamOggVorbis.load_from_file(value as String)
		&"Volume":
			audio_player.volume_db = linear_to_db(value as float)
		&"Loop":
			if value:
				if not audio_player.finished.is_connected(play_sound_looped):
					audio_player.finished.connect(play_sound_looped)
			else:
				if audio_player.finished.is_connected(play_sound_looped):
					audio_player.finished.disconnect(play_sound_looped)
		&"ThreeD":
			var stream: AudioStream
			var loop := false
			var volume := 0.0

			if is_instance_valid(audio_player):
				audio_player.queue_free()

				# Old audio player properties
				stream = audio_player.stream
				loop = audio_player.finished.is_connected(audio_player.play)
				volume = audio_player.volume_db

			if value:
				audio_player = AudioStreamPlayer3D.new()
			else:
				audio_player = AudioStreamPlayer.new()

			# Set same properties for new audio player
			audio_player.stream = stream
			if loop:
				change_property(&"Loop", loop)
			audio_player.volume_db = volume

			audio_player.finished.connect(func() -> void:
				if not World.time_paused:
					output(0, true, true)
			)

			node_3d.add_child(audio_player)


func setup_properties(gadget_properties: GadgetProperties) -> void:
	const SELECTED_SOUND_PREFIX = "Selected sound: "

	var select_sound_label := Label.new()
	select_sound_label.name = gadget_properties.get_control_name(SELECTED_SOUND_PREFIX)
	select_sound_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	select_sound_label.text = SELECTED_SOUND_PREFIX + get_meta(&"SoundName", "None")
	gadget_properties.vbox.add_child(select_sound_label)

	var file_dialog := FileDialog.new()
	file_dialog.use_native_dialog = true
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.set_filters(["*.ogg ; OGG Vorbis Sounds"])
	var _error := file_dialog.file_selected.connect(func(path: String) -> void:
		change_property.rpc(&"Sound", path)
		gadget_properties.sync_label_text.rpc(select_sound_label.get_path(), SELECTED_SOUND_PREFIX + path)
		sync_meta.rpc(&"Sound", path)
		sync_meta.rpc(&"SoundName", path)
	)
	gadget_properties.vbox.add_child(file_dialog)

	var custom_button := Button.new()
	custom_button.text = "Select Custom Sound"
	_error = custom_button.pressed.connect(file_dialog.popup)
	gadget_properties.vbox.add_child(custom_button)

	var sound_select_instance := SOUND_SELECT.instantiate() as SoundSelect
	_error = sound_select_instance.select_sound.connect(
		func(sound_name: String, text: String) -> void:
			var path := Audio.sounds[sound_name]
			change_property.rpc(&"Sound", path)
			gadget_properties.sync_label_text.rpc(select_sound_label.get_path(), SELECTED_SOUND_PREFIX + text)
			sync_meta.rpc(&"Sound", path)
			sync_meta.rpc(&"SoundName", text)
	)
	gadget_properties.vbox.add_child(sound_select_instance)

	var library_button := Button.new()
	library_button.text = "Select Library Sound"
	_error = library_button.pressed.connect(sound_select_instance.show)
	gadget_properties.vbox.add_child(library_button)

	var _slider := gadget_properties.add_slider("Volume: ", [&"Volume"], 1, 0, 1, 0.01, self)

	var loop_checkbox := CheckBox.new()
	loop_checkbox.text = "Loop"
	loop_checkbox.name = gadget_properties.get_control_name(loop_checkbox.text)
	loop_checkbox.button_pressed = get_meta(&"Loop", false)
	_error = loop_checkbox.pressed.connect(func() -> void:
		change_property.rpc(&"Loop", loop_checkbox.button_pressed)
		sync_meta.rpc(&"Loop", loop_checkbox.button_pressed)
		gadget_properties.sync_checkbox_pressed.rpc(loop_checkbox.get_path(), loop_checkbox.button_pressed)
	)
	gadget_properties.vbox.add_child(loop_checkbox)

	var threed_checkbox := CheckBox.new()
	threed_checkbox.text = "3D"
	threed_checkbox.name = gadget_properties.get_control_name(threed_checkbox.text)
	threed_checkbox.button_pressed = get_meta(&"ThreeD", false)
	_error = threed_checkbox.pressed.connect(func() -> void:
		change_property.rpc(&"ThreeD", threed_checkbox.button_pressed)
		sync_meta.rpc(&"ThreeD", threed_checkbox.button_pressed)
		gadget_properties.sync_checkbox_pressed.rpc(threed_checkbox.get_path(), threed_checkbox.button_pressed)
	)
	gadget_properties.vbox.add_child(threed_checkbox)


func check_pulse() -> void:
	if get_input_data(0) == false:
		is_pulse = true


func play_sound_looped() -> void:
	if World.time_paused:
		return

	var data: Variant = get_input_data(0)
	if data == true or is_pulse:
		audio_player.play()
