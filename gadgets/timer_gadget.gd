extends Gadget


var timer: Timer
var bar: ProgressBar
var first_shot := true
var is_pulse: bool


func start() -> void:
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)

	bar = ProgressBar.new()
	bar.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	bar.max_value = 1
	bar.step = 1
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FillMode.FILL_BOTTOM_TO_TOP
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var _error := input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0, true):
			timer.start()
			first_shot = false
			check_pulse.call_deferred()
			output(1, false)
	)


func tick(_delta: float) -> void:
	if not first_shot:
		bar.value = 1 - timer.time_left / timer.wait_time

	timer.paused = not is_input_data_powered(0, true) and not is_pulse


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"WaitTime":
			timer.wait_time = value
		&"OneShot":
			timer.one_shot = value


func check_pulse() -> void:
	if get_input_data(0) == false:
		is_pulse = true


func _on_timer_timeout() -> void:
	output(0, true, true) # Pulse
	output(1, true, false) # Signal
