extends Gadget


func start() -> void:
	var _error := input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0, false):
			node_3d.get_parent().queue_free()
	)


func tick(_delta: float) -> void:
	pass


func change_property(_property: StringName, _value: Variant) -> void:
	pass
