class_name GadgetsPanel
extends Panel


const SOUND_DESTROY = preload("res://sounds/destroy.wav")

@export var audio_player: AudioStreamPlayer


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		var gadget := get_tree().get_first_node_in_group(&"Dragging") as Gadget
		if gadget:
			# Delete Gadget
			gadget.queue_free()
			gadget.update_connection_positions()
			audio_player.stream = SOUND_DESTROY
			audio_player.play()
