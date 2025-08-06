extends Gadget


func start() -> void:
	var _error := input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0, false) and not World.time_paused:
			var node := node_3d.get_parent()
			var node_parent := node.get_parent()
			World.destroyed_nodes[node_parent] = node
			node_parent.remove_child(node)
	)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass


func setup_properties(_gadget_properties: GadgetProperties) -> void:
	pass
