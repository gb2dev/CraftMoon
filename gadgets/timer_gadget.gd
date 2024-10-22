extends Gadget


@onready var timer := $Timer as Timer
@onready var bar := $ProgressBar as ProgressBar

var first_shot := true
var is_pulse: bool


func _ready() -> void:
	super._ready()
	input_pulse.connect(func(_input_index: int) -> void:
		if is_input_data_powered(0):
			timer.start()
			first_shot = false
			check_pulse.call_deferred()
			output(1, false)
	)


func check_pulse() -> void:
	if get_input_data(0) == false:
		is_pulse = true


func input(_delta: float) -> void:
	if not first_shot:
		bar.value = 1 - timer.time_left / timer.wait_time

	timer.paused = not is_input_data_powered(0) and not is_pulse


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"WaitTime":
			timer.wait_time = value
		&"OneShot":
			timer.one_shot = value


func _on_timer_timeout() -> void:
	output(0, true, true)
	output(1, true)
