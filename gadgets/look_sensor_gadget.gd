extends Gadget


var visible_notifier: VisibleOnScreenNotifier3D

var is_visible_on_screen: bool


func start() -> void:
	visible_notifier = VisibleOnScreenNotifier3D.new()
	visible_notifier.aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var _error := visible_notifier.screen_entered.connect(_on_visible_on_screen_notifier_3d_screen_entered)
	_error = visible_notifier.screen_exited.connect(_on_visible_on_screen_notifier_3d_screen_exited)
	node_3d.add_child(visible_notifier)

	_error = input_pulse.connect(func(_input_index: int) -> void:
		output(0, is_input_data_powered(0, true) and is_visible_on_screen)
	)


func tick(_delta: float) -> void:
	pass


func change_property(_property: StringName, _value: Variant) -> void:
	pass


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	is_visible_on_screen = true

	if is_input_data_powered(0, true):
		output(0, is_visible_on_screen)


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	is_visible_on_screen = false

	if is_input_data_powered(0, true):
		output(0, is_visible_on_screen)
