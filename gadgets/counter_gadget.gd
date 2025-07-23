extends Gadget


var bar: ProgressBar
var current_count := 0:
	set(value):
		set_meta(&"CurrentCount", value)
		property_update.emit(value)
		current_count = value
var target_count := 1


func start() -> void:
	bar = ProgressBar.new()
	bar.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	bar.max_value = 1
	bar.step = 1
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FillMode.FILL_BOTTOM_TO_TOP
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var _error := input_pulse.connect(func(input_index: int) -> void:
		match input_index:
			0:
				output(0, is_input_data_powered(0, true) and current_count == target_count)
			1:
				if is_input_data_powered(input_index, true):
					# Add to Counter
					if current_count < target_count:
						current_count += 1
						bar.value = current_count

						if current_count == target_count:
							output(0, is_input_data_powered(0, true))
			2:
				if is_input_data_powered(input_index, true):
					# Reset Counter
					current_count = 0
					bar.value = current_count
					output(0, false)
	)


func tick(_delta: float) -> void:
	pass


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"CurrentCount":
			current_count = value
			bar.value = current_count

			output(0, is_input_data_powered(0, true) and current_count == target_count)
		&"TargetCount":
			current_count = min(current_count, value)
			target_count = value
			output(0, current_count == target_count)
			bar.max_value = value


func sort_property_list(a: StringName, _b: StringName) -> bool:
	return a == &"TargetCount"
