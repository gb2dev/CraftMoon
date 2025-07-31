extends Gadget


func start() -> void:
	pass


func tick(_delta: float) -> void:
	# TODO: change to true when there is a pause/play system
	if is_input_data_powered(0, false):
		node_3d.get_parent_node_3d().look_at(get_viewport().get_camera_3d().global_position)


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass
