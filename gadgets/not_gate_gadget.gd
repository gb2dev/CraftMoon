extends Gadget


func start() -> void:
	output(0, true)
	var _error := input_pulse.connect(func(_input_index: int) -> void:
		output(0, not is_input_data_powered(0, false))
	)


func tick(_delta: float) -> void:
	pass


func change_property(_property: StringName, _value: Variant) -> void:
	pass
