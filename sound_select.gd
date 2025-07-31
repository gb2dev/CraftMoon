class_name SoundSelect
extends Window


signal select_sound(sound_name: String, text: String)

const CATEGORY_SCENE = preload("res://sound_select_category.tscn")

@export var categories: TabContainer


func _ready() -> void:
	var _error := close_requested.connect(hide)

	for category_name: String in Audio.get_sound_categories():
		if category_name == "editor_only":
			continue
		var category := CATEGORY_SCENE.instantiate()
		category.name = tr(&"sound_category_%s" % category_name)
		categories.add_child(category)

		for sound_name: String in Audio.get_sounds(category_name):
			var sound := Button.new()
			sound.text = tr(&"sound_%s" % sound_name)
			_error = sound.pressed.connect(func() -> void:
				select_sound.emit(sound_name, category.name + " - " + sound.text)
				hide()
			)
			category.get_child(0).add_child(sound)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_cancel"):
		hide()
