extends Gadget


@onready var visible_notifier := $"3D/VisibleOnScreenNotifier3D" as VisibleOnScreenNotifier3D

var is_visible_on_screen: bool


func start() -> void:
	var _error := input_pulse.connect(func(_input_index: int) -> void:
		output(0, is_input_data_powered(0, false) and is_visible_on_screen)
	)


func tick(_delta: float) -> void:
	pass


func change_property(_property: StringName, _value: Variant) -> void:
	pass


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	is_visible_on_screen = true

	if is_input_data_powered(0, false):
		output(0, is_visible_on_screen)


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	is_visible_on_screen = false

	if is_input_data_powered(0, false):
		output(0, is_visible_on_screen)
