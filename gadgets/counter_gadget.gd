extends Gadget


@onready var bar := $ProgressBar as ProgressBar

var current_count := 0
var target_count := 1


func input(_delta: float) -> void:
	if is_input_pulse(1):
		# Add to Counter
		if current_count < target_count:
			current_count += 1
			bar.value = current_count

			if current_count == target_count:
				output(0, true)
	elif is_input_pulse(2):
		# Reset Counter
		current_count = 0
		bar.value = current_count
		output(0, false)


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"TargetCount":
			current_count = min(current_count, value)
			target_count = value
			output(0, current_count == target_count)
			bar.max_value = value
