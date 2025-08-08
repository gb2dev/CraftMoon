extends Node3D
class_name SpringArmCharacter


const MOUSE_SENSIBILITY: float = 0.005

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null


func _unhandled_input(event: InputEvent) -> void:
	if Menu.shown:
		return

	for control: Control in get_tree().get_nodes_in_group(&"UI"):
		if control.visible:
			return

	var event_mouse_motion := event as InputEventMouseMotion
	if event_mouse_motion and is_multiplayer_authority():
		rotate_y(-event_mouse_motion.relative.x * MOUSE_SENSIBILITY)
		_spring_arm.rotate_x(-event_mouse_motion.relative.y * MOUSE_SENSIBILITY)
		_spring_arm.rotation.x = clamp(_spring_arm.rotation.x, -PI/4, PI/24)
