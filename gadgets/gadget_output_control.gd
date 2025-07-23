class_name GadgetOutputControl
extends Control


var visual: GadgetOutputVisual
var target_gadget: Gadget
var target_input: int
var data: Variant = false:
	set(value):
		if data != value:
			if is_instance_valid(target_gadget):
				var input_data: Variant = target_gadget.get_input_data(target_input)
				data = value
				var input_data_new: Variant = target_gadget.get_input_data(target_input)
				if input_data != input_data_new and input_data_new != null:
					target_gadget.input_pulse.emit.bind(target_input).call_deferred()
			else:
				data = value
