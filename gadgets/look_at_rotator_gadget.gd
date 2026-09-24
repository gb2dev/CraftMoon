extends Gadget


func start() -> void:
	pass


func tick(_delta: float) -> void:
	if not World.time_paused and is_input_data_powered(0, true):
		node_3d.get_parent_node_3d().look_at(get_viewport().get_camera_3d().global_position)


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass


func setup_properties(_gadget_properties: GadgetProperties) -> void:
	pass
