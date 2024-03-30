class_name GadgetProperties
extends Panel


const SOUND_SELECT = preload("res://sound_select.tscn")

@onready var vbox := $VBoxContainer as VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func open(type: StringName, gadget: Gadget) -> void:
	for n: Node in vbox.get_children():
		n.queue_free()

	visible = true

	var label := Label.new()
	label.text = tr(type)
	vbox.add_child(label)

	match type:
		&"AudioGadget":
			const selected_sound_prefix = "Selected sound: "

			var select_sound_label := Label.new()
			select_sound_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			select_sound_label.text = selected_sound_prefix + gadget.get_meta(&"Sound", "None")
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
			)
			vbox.add_child(file_dialog)

			var custom_button := Button.new()
			custom_button.text = "Select Custom Sound"
			custom_button.pressed.connect(file_dialog.popup)
			vbox.add_child(custom_button)

			var sound_select_instance := SOUND_SELECT.instantiate() as SoundSelect
			sound_select_instance.select_sound.connect(func(sound: String) -> void:
				gadget.change_property(&"Sound", "res://sounds/" + sound + ".wav")
				select_sound_label.text = selected_sound_prefix + sound
				gadget.set_meta(&"Sound", sound)
			)
			vbox.add_child(sound_select_instance)

			var library_button := Button.new()
			library_button.text = "Select Library Sound"
			library_button.pressed.connect(sound_select_instance.show)
			vbox.add_child(library_button)
