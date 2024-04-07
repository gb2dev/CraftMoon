extends Gadget


@onready var visible_notifier := $"3D/VisibleOnScreenNotifier3D" as VisibleOnScreenNotifier3D


func change_property(property: StringName, value: Variant) -> void:
	pass


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	output(0, true)


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	output(0, false)
