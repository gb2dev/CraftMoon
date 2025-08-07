class_name LevelPortal
extends Node3D


signal portal_entered(slot: int)
signal portal_properties(slot: int)

const HOVER_MATERIAL = preload("res://materials/highlight.tres")
const DEFAULT_MATERIAL = preload("res://materials/concrete/concrete.tres")

@export var label: Label3D
@export var cylinder: CSGCylinder3D


func select() -> void:
	if not is_multiplayer_authority():
		return

	portal_entered.emit(get_index())


func _on_area_3d_mouse_entered() -> void:
	cylinder.material_overlay = HOVER_MATERIAL


func _on_area_3d_mouse_exited() -> void:
	cylinder.material_overlay = null


func _on_area_3d_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event and mouse_button_event.pressed:
		match mouse_button_event.button_index:
			MOUSE_BUTTON_LEFT:
				select()
			MOUSE_BUTTON_RIGHT:
				portal_properties.emit(get_index())
