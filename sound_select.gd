class_name SoundSelect
extends Window


signal select_sound(sound: String)

@onready var categories := $Categories


func _ready() -> void:
	var _error := close_requested.connect(hide)

	for category: Control in categories.get_children():
		var vbox := category.get_child(0)
		for sound: Button in vbox.get_children():
			_error = sound.pressed.connect(func() -> void:
				select_sound.emit(sound.name, category.name + " - " + sound.text)
				hide()
			)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_cancel"):
		hide()
