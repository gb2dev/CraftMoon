class_name InputPrompt
extends HBoxContainer


@onready var label := $Label as Label

@export var action: StringName:
	set(value):
		action = value
		text = tr(action)

var text: String


func _ready() -> void:
	var _error := InputHelper.device_changed.connect(_on_device_changed)
	_on_device_changed(InputHelper.device, 0)


func _on_device_changed(next_device: String, _index: int) -> void:
	for child in get_children():
		if child != label:
			child.queue_free()

	var input_event := InputHelper.get_keyboard_or_joypad_input_for_action(action)
	if not input_event:
		label.text = text
		return

	var parts: Array[String] = []
	if input_event is InputEventWithModifiers:
		if input_event.ctrl_pressed:
			parts.append("Ctrl")
		if input_event.alt_pressed:
			parts.append("Alt")
		if input_event.shift_pressed:
			parts.append("Shift")
		if input_event.meta_pressed:
			parts.append("Meta")

	var main_input := InputHelper.get_label_for_input(input_event)
	if not main_input.is_empty():
		parts.append(main_input)

	var all_exist := true
	var texture_paths: Array[String] = []
	for p in parts:
		var texture_path := "res://icons/input/" + next_device + "/" + p + ".svg"
		if ResourceLoader.exists(texture_path):
			texture_paths.append(texture_path)
		else:
			all_exist = false
			break

	if all_exist and not texture_paths.is_empty():
		label.text = text

		for i in range(texture_paths.size()):
			var path := texture_paths[i]
			var tr := TextureRect.new()
			tr.custom_minimum_size = Vector2(34, 34)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tr.texture = load(path)
			add_child(tr)
			move_child(tr, get_child_count() - 2)
	else:
		var fallback_str := ""
		for i in range(parts.size()):
			if i > 0:
				fallback_str += " + "
			fallback_str += parts[i]
		label.text = "[" + fallback_str + "] " + text
