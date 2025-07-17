extends Gadget


func _ready() -> void:
	super._ready()
	output(0, true)
	var _error := input_pulse.connect(func(_input_index: int) -> void:
		output(0, not is_input_data_powered(0))
	)
