extends Gadget


@onready var timer := $Timer as Timer
@onready var bar := $ProgressBar as ProgressBar

var first_shot := true


func input(_delta: float) -> void:
	timer.paused = not is_input_data_powered(0)
	if not first_shot:
		bar.value = 1 - timer.time_left / timer.wait_time

	if is_input_pulse(0, false):
		timer.start()
		first_shot = false


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"WaitTime":
			timer.wait_time = value
		&"OneShot":
			timer.one_shot = value


func _on_timer_timeout() -> void:
	output(0, true, true)
