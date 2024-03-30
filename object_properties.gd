class_name ObjectProperties
extends Control


@onready var gadgets := %"Gadgets"
@onready var gadget_properties := %"Gadget Properties" as GadgetProperties

var object: PhysicsBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible and Input.is_action_just_pressed("ui_cancel") and not get_tree().get_first_node_in_group("Dragging"):
		if gadget_properties.visible:
			gadget_properties.visible = false
			gadgets.visible = true
		else:
			toggle(object)


func toggle(o: PhysicsBody3D):
	if o:
		visible = not visible
		if visible:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
		object = o
