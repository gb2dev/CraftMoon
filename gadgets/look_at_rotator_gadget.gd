extends Gadget


func input(_delta: float) -> void:
	if is_input_data_powered(0):
		node_3d.get_parent_node_3d().look_at(get_viewport().get_camera_3d().global_position)
