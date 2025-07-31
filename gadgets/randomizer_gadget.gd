extends Gadget


func start() -> void:
	var _connect_error := input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0, false):
			var output_controls_connected: Array = output_controls[0].duplicate()
			var _resize_error := output_controls_connected.resize(output_controls_connected.size() - 1)
			output_controls_connected.pick_random().data = true
		else:
			output(0, false)
	)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass
