extends AudioStreamPlayer


const SOUNDS_DIR = "res://sounds"

var sounds: Dictionary[String, String]


func _ready() -> void:
	var sound_categories := get_sound_categories()
	for sound_category: String in sound_categories:
		var _sounds := get_sounds(sound_category, true)


func play_sound(sound_name: String) -> void:
	stream = load(sounds[sound_name])
	play()


func get_sound_categories() -> Array[String]:
	var dir := DirAccess.open(SOUNDS_DIR)
	dir.include_navigational = false
	var result: Array[String]

	if dir:
		var _error := dir.list_dir_begin()
		var dir_name := dir.get_next()
		while dir_name != "":
			if dir.current_is_dir():
				result.append(dir_name)
			dir_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("Failed to open directory " + SOUNDS_DIR)
	return result


func get_sounds(sound_category: String, add_to_dict := false) -> Array[String]:
	var dir_path := SOUNDS_DIR + "/" + sound_category
	var dir := DirAccess.open(dir_path)
	var result: Array[String]

	if dir:
		var _error := dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".wav"):
				var sound := file_name.trim_suffix(".wav")
				result.append(sound)
				if add_to_dict:
					var file_path := dir_path + "/" + file_name
					sounds[sound] = file_path
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("Failed to open directory " + dir_path)
	return result
