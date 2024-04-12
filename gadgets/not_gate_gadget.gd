extends Gadget


func _ready() -> void:
	super._ready()
	output(0, true)
	input_pulse.connect(func(input_index: int) -> void:
		output(0, not is_input_data_powered(0))
	)
