extends Gadget


@onready var timer := $Timer as Timer
@onready var bar := $ProgressBar as ProgressBar

var first_shot := true


func _ready() -> void:
	super._ready()
	input_pulse.connect(func(input_index: int) -> void:
		timer.start()
		first_shot = false
	)


func input(_delta: float) -> void:
	if not first_shot:
		bar.value = 1 - timer.time_left / timer.wait_time

	timer.paused = not is_input_data_powered(0)


func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"WaitTime":
			timer.wait_time = value
		&"OneShot":
			timer.one_shot = value


func _on_timer_timeout() -> void:
	# TODO: Add signal output
	output(0, true, true)
