class_name LevelPortal
extends ShapeCast3D


@export var label: Label3D
@export var cylinder: CSGCylinder3D

var level: String
var menu: Menu


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	for result: Dictionary in collision_result:
		if result.collider.name == "1":
			enter_portal.rpc()

@rpc("any_peer", "call_local")
func enter_portal() -> void:
	set_process(false)
	menu.slot = get_index()
	if level.is_empty():
		menu.new_level(false)
	else:
		if is_multiplayer_authority():
			menu.transfer_level(level)
			await menu.wipe(menu.level_transfer_complete)
			menu.load_level(level)
		else:
			await menu.wipe(menu.level_transfer_complete)
			menu.load_level("remote")
		menu.enter_edit_mode.rpc()
