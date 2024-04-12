extends Gadget


func input(delta: float) -> void:
	if is_input_data_powered(0):
		node_3d.get_parent_node_3d().look_at(get_viewport().get_camera_3d().global_position)


func change_property(property: StringName, value: Variant) -> void:
	match property:
		pass
