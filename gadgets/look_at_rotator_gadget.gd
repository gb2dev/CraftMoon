extends Gadget


var initial_transform: Transform3D


var has_simulated := false


func start() -> void:
	var _error := Signals.time_rewound.connect(_on_time_rewound)
	initial_transform = node_3d.get_parent_node_3d().transform
	has_simulated = false


func tick(_delta: float) -> void:
	if World.time_paused and not has_simulated:
		initial_transform = node_3d.get_parent_node_3d().transform
	elif not World.time_paused:
		has_simulated = true
		if is_input_data_powered(0, true):
			node_3d.get_parent_node_3d().look_at(get_viewport().get_camera_3d().global_position)


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass


func setup_properties(_gadget_properties: GadgetProperties) -> void:
	pass


func _on_time_rewound() -> void:
	node_3d.get_parent_node_3d().transform = initial_transform
	has_simulated = false
