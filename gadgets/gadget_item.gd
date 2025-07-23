class_name GadgetItem
extends Control


var object_properties: ObjectProperties
var gadget_data: GadgetData

@onready var background := $Background as NinePatchRect
@onready var icon := $Icon as TextureRect


func _ready() -> void:
	background.modulate = gadget_data.background
	icon.texture = gadget_data.icon
	tooltip_text = gadget_data.name


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			var _gadget := object_properties.create_gadget(gadget_data)
			accept_event()
