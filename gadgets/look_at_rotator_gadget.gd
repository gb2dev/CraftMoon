extends Gadget


# Variables


func input(delta: float) -> void:
	if is_input_data_powered(0):
		pass
		# Look at
		#node_3d.get_parent().position += movement_direction * delta


func change_property(property: StringName, value: Variant) -> void:
	match property:
		pass
