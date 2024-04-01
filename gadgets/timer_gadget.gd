extends Gadget


@onready var timer := $Timer as Timer
@onready var bar := $ProgressBar as ProgressBar

var first_shot := true


func input_signal(_delta: float) -> void:
	timer.paused = not signal_powered
	if not first_shot:
		bar.value = 1 - timer.time_left / timer.wait_time


func input_pulse(_input_index: int, _data: Variant) -> void:
	# TODO: Add separate "start timer" input
	if pulse_powered:
		timer.start()
		first_shot = false


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"WaitTime":
			timer.wait_time = value
		&"OneShot":
			timer.one_shot = value


func _on_timer_timeout() -> void:
	if signal_powered:
		output_pulse(0, true)
