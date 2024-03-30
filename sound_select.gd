class_name SoundSelect
extends Window


signal select_sound(sound: String)

@onready var sounds := $GridContainer/Sounds as VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_requested.connect(hide)

	for sound: Button in sounds.get_children():
		sound.pressed.connect(func() -> void:
			select_sound.emit(sound.name)
			hide()
		)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
