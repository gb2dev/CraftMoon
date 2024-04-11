extends Gadget


@onready var bar := $ProgressBar as ProgressBar

var current_count := 0
var target_count := 1


func _ready() -> void:
	super._ready()
	input_pulse.connect(func(input_index: int) -> void:
		match input_index:
			0:
				output(0, is_input_data_powered(0) and current_count == target_count)
			1:
				if is_input_data_powered(input_index):
					# Add to Counter
					if current_count < target_count:
						current_count += 1
						bar.value = current_count

						if current_count == target_count:
							output(0, is_input_data_powered(0, false))
			2:
				if is_input_data_powered(input_index):
					# Reset Counter
					current_count = 0
					bar.value = current_count
					output(0, false)
	)


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"TargetCount":
			current_count = min(current_count, value)
			target_count = value
			output(0, current_count == target_count)
			bar.max_value = value
