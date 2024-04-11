extends Gadget


@onready var visible_notifier := $"3D/VisibleOnScreenNotifier3D" as VisibleOnScreenNotifier3D

var is_visible_on_screen: bool


func is_powered_change() -> void:
	if is_visible_on_screen:
		output(0, is_visible_on_screen)


func change_property(property: StringName, value: Variant) -> void:
	pass


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	is_visible_on_screen = true

	output(0, is_visible_on_screen)


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	is_visible_on_screen = false

	output(0, is_visible_on_screen)
