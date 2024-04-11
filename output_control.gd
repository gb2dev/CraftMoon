class_name OutputControl
extends Control

var target_gadget: Gadget
var target_input: int
var data: Variant = false:
	set(value):
		if data != value:
			data = value
			if is_instance_valid(target_gadget):
				target_gadget.input_data_changed.call_deferred(target_input)
