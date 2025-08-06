extends Gadget


var initial_transform: Transform3D


func start() -> void:
	var _error := Signals.time_rewound.connect(_on_time_rewound)
	initial_transform = node_3d.get_parent_node_3d().transform


func tick(_delta: float) -> void:
	if is_input_data_powered(0, true) and not World.time_paused:
		node_3d.get_parent_node_3d().look_at(get_viewport().get_camera_3d().global_position)


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass


func setup_properties(_gadget_properties: GadgetProperties) -> void:
	pass


func _on_time_rewound() -> void:
	node_3d.get_parent_node_3d().transform = initial_transform
