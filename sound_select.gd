class_name SoundSelect
extends Window


signal select_sound(sound: String)

@onready var categories := $Categories


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_requested.connect(hide)

	for category: Control in categories.get_children():
		var vbox := category.get_child(0)
		for sound: Button in vbox.get_children():
			sound.pressed.connect(func() -> void:
				select_sound.emit(sound.name, category.name + " - " + sound.text)
				hide()
			)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_cancel"):
		hide()
