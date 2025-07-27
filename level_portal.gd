class_name LevelPortal
extends ShapeCast3D


signal portal_entered(slot: int)

@export var label: Label3D
@export var cylinder: CSGCylinder3D


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	for result: Dictionary in collision_result:
		if result.collider.name == "1":
			portal_entered.emit(get_index())
			set_process(false)
