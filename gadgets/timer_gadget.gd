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


func setup_properties(gadget_properties: GadgetProperties) -> void:
	var oneshot_checkbox := CheckBox.new()
	oneshot_checkbox.text = "One shot"
	oneshot_checkbox.name = gadget_properties.get_control_name(oneshot_checkbox.text)
	oneshot_checkbox.button_pressed = get_meta(&"OneShot", true)
	var _error := oneshot_checkbox.pressed.connect(func() -> void:
		change_property.rpc(&"OneShot", oneshot_checkbox.button_pressed)
		sync_meta.rpc(&"OneShot", oneshot_checkbox.button_pressed)
		gadget_properties.sync_checkbox_pressed.rpc(oneshot_checkbox.get_path(), oneshot_checkbox.button_pressed)
	)
	gadget_properties.vbox.add_child(oneshot_checkbox)

	var _slider := gadget_properties.add_slider("Wait time: ", [&"WaitTime"], 1, 0.1, 60, 0.1, self)


func reset_timer() -> void:
	timer.start()
	output.call_deferred(1, false)
	bar.value = 0


func _on_timer_timeout() -> void:
	if not World.time_paused:
		output(0, true, true) # Pulse
		output(1, true, false) # Signal
