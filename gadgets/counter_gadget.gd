extends Gadget


@onready var bar := $ProgressBar as ProgressBar

var current_count := 0
var target_count := 1


func input_pulse(input_index: int, _data: Variant) -> void:
	match input_index:
		#0:
			#pass
		0:
			if current_count < target_count:
				current_count += 1
				bar.value = current_count

				if current_count == target_count:
					output_signal(0, true)


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"TargetCount":
			current_count = min(current_count, value)
			target_count = value
			output_signal(0, current_count == target_count)
			bar.max_value = value
