extends Gadget


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
				output(0, true, true)
			)

			node_3d.add_child(audio_player)


func check_pulse() -> void:
	if get_input_data(0) == false:
		is_pulse = true


func play_sound_looped() -> void:
	var data: Variant = get_input_data(0)
	if data == true or is_pulse:
		audio_player.play()
