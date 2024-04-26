class_name LevelPortal
extends ShapeCast3D


@export var label: Label3D

var level: String
var menu: Menu


func _process(_delta: float) -> void:
	if is_colliding():
		set_process(false)
		menu.slot = get_index()
		if level.is_empty():
			menu.new_level(false)
		else:
			await menu.wipe()
			menu.load_level(level)
			menu.enter_edit_mode()
