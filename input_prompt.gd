extends Control


@onready var texture_rect := $TextureRect as TextureRect
@onready var label := $Label as Label

@export var action: StringName


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	InputHelper.device_changed.connect(_on_device_changed)
	_on_device_changed(InputHelper.guess_device_name(), 0)


func _on_device_changed(next_device: String, index: int):
	var input_event := InputHelper.get_keyboard_or_joypad_input_for_action(action)
	var input_string := InputHelper.get_label_for_input(input_event)
	var texture_path := "res://icons/input/" + next_device + "/" + input_string + ".svg"
	if ResourceLoader.exists(texture_path):
		label.text = tr(action)
		texture_rect.texture = load(texture_path)
		texture_rect.show()
	else:
		label.text = "[" + input_string + "] " + tr(action)
		texture_rect.texture = null
		texture_rect.hide()
