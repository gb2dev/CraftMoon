extends Gadget


@onready var bar := $ProgressBar as ProgressBar

var current_count := 0
var target_count := 1


func input_pulse(_input_index: int, _data: Variant) -> void:
	# TODO: Add separate "add" input
	if pulse_powered:
		if current_count < target_count:
			current_count += 1
			bar.value = current_count
			output_signal(0, current_count == target_count)


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"TargetCount":
			current_count = min(current_count, value)
			target_count = value
			if current_count != target_count:
				output_signal(0, false)
			bar.max_value = value
