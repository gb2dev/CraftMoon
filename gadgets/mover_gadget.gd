extends Gadget


var movement_direction := Vector3.ZERO


func input(delta: float) -> void:
	if is_input_data_powered(0):
		node_3d.get_parent().position += movement_direction * delta


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"MovementDirectionX":
			movement_direction.x = value
		&"MovementDirectionY":
			movement_direction.y = value
		&"MovementDirectionZ":
			movement_direction.z = value
