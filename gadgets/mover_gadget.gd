extends Gadget


var movement_direction := Vector3.ZERO


func start() -> void:
	pass


func tick(delta: float) -> void:
	# TODO: change to true when there is a pause/play system
	if is_input_data_powered(0, false):
		node_3d.get_parent().position += movement_direction * delta


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"MovementDirectionX":
			movement_direction.x = value
		&"MovementDirectionY":
			movement_direction.y = value
		&"MovementDirectionZ":
			movement_direction.z = value
