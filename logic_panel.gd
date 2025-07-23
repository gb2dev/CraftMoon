class_name LogicPanel
extends Panel


const PADDING_GRID_UNITS = 1
const GRID_SIZE = 32
const SOUND_PLACE = preload("res://sounds/place.wav")

@export var audio_player: AudioStreamPlayer

@onready var object_properties := %"Object Properties" as ObjectProperties


func _process(_delta: float) -> void:
	var gadget := get_tree().get_first_node_in_group(&"Dragging") as Gadget
	if gadget and gadget.is_in_group(&"GridSnap"):
		gadget.position = get_snapped_gadget_position(gadget.size) + global_position
		gadget.update_connection_positions()


func place_gadget(gadget: Gadget, silent: bool) -> void:
	if gadget.get_parent() == self:
		gadget.top_level = false
	else:
		gadget.get_parent().remove_child(gadget)
		add_child(gadget)
		gadget.add_to_group(&"Persist")

	gadget.remove_from_group(&"Dragging")
	gadget.position = get_snapped_gadget_position(gadget.size)
	gadget.update_connection_positions()
	gadget.set_mouse_filters(MOUSE_FILTER_STOP)
	if not silent:
		audio_player.stream = SOUND_PLACE
		audio_player.play()


func get_snapped_gadget_position(gadget_size: Vector2) -> Vector2:
	var grid := Vector2.ONE * GRID_SIZE
	return get_local_mouse_position().clamp(
		gadget_size / 2 + grid,
		size - gadget_size / 2 - grid
	).snapped(grid) - gadget_size / 2


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		var gadget := get_tree().get_first_node_in_group(&"Dragging") as Gadget
		if gadget:
			place_gadget(gadget, false)


func _on_visibility_changed() -> void:
	if get_parent().visible:
		for gadget: Gadget in get_children():
			gadget.visible = object_properties.object == gadget.node_3d.get_parent()


func _on_mouse_entered() -> void:
	var gadget := get_tree().get_first_node_in_group(&"Dragging") as Gadget
	if gadget:
		gadget.add_to_group(&"GridSnap")


func _on_mouse_exited() -> void:
	var gadget := get_tree().get_first_node_in_group(&"Dragging") as Gadget
	if gadget:
		gadget.remove_from_group(&"GridSnap")
