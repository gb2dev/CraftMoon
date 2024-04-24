extends Gadget


func _ready() -> void:
	super._ready()
	input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0):
			node_3d.get_parent().queue_free()
	)
