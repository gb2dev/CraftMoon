extends Gadget


var movement_direction := Vector3.ZERO


func start() -> void:
	pass


func tick(delta: float) -> void:
	if not World.time_paused and is_input_data_powered(0, true):
		node_3d.get_parent().position += movement_direction * delta


@rpc("any_peer", "call_local")
func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"MovementDirectionX":
			movement_direction.x = value
		&"MovementDirectionY":
			movement_direction.y = value
		&"MovementDirectionZ":
			movement_direction.z = value


func setup_properties(gadget_properties: GadgetProperties) -> void:
	var _slider := gadget_properties.add_slider("Movement direction X: ", [&"MovementDirectionX"], 0, -100, 100, 0.1, self)
	_slider = gadget_properties.add_slider("Movement direction Y: ", [&"MovementDirectionY"], 0, -100, 100, 0.1, self)
	_slider = gadget_properties.add_slider("Movement direction Z: ", [&"MovementDirectionZ"], 0, -100, 100, 0.1, self)
