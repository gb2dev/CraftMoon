extends Gadget


var timer: Timer
var bar: ProgressBar
var first_shot := true


func start() -> void:
	timer = Timer.new()
	timer.one_shot = true
	var _error := timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

	_error = Signals.time_rewound.connect(reset_timer)

	bar = ProgressBar.new()
	bar.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	bar.max_value = 1
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FillMode.FILL_BOTTOM_TO_TOP
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_error = input_pulse.connect(func(input_index: int) -> void:
		if input_index == 1 and is_input_data_powered(1, true):
			reset_timer()
	)


func tick(_delta: float) -> void:
	if not timer.paused:
		if first_shot:
			first_shot = false
			reset_timer()
		else:
			bar.value = 1 - timer.time_left / timer.wait_time

	timer.paused = not is_input_data_powered(0, true) or World.time_paused


@rpc("any_peer", "call_local")
func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"WaitTime":
			timer.wait_time = value
		&"OneShot":
			timer.one_shot = value


func reset_timer() -> void:
	timer.start()
	output.call_deferred(1, false)
	bar.value = 0


func _on_timer_timeout() -> void:
	if not World.time_paused:
		output(0, true, true) # Pulse
		output(1, true, false) # Signal
