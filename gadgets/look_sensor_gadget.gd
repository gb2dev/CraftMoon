extends Gadget


var visible_notifier: VisibleOnScreenNotifier3D

var is_visible_on_screen: bool:
	set(value):
		is_visible_on_screen = value
		if is_input_data_powered(0, true):
			if World.time_paused:
				await Signals.time_played
				output(0, is_visible_on_screen)
			else:
				output(0, is_visible_on_screen)


func start() -> void:
	var _error := Signals.time_rewound.connect(_on_time_rewound)

	visible_notifier = VisibleOnScreenNotifier3D.new()
	visible_notifier.aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	_error = visible_notifier.screen_entered.connect(_on_visible_on_screen_notifier_3d_screen_entered)
	_error = visible_notifier.screen_exited.connect(_on_visible_on_screen_notifier_3d_screen_exited)
	node_3d.add_child(visible_notifier)

	_error = input_pulse.connect(func(_input_index: int) -> void:
		output(0, is_input_data_powered(0, true) and is_visible_on_screen)
	)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass


func setup_properties(_gadget_properties: GadgetProperties) -> void:
	pass


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	is_visible_on_screen = true


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	is_visible_on_screen = false


func _on_time_rewound() -> void:
	output(0, false)
	is_visible_on_screen = visible_notifier.is_on_screen()
