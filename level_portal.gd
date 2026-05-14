class_name LevelPortal
extends Node3D


signal portal_entered(slot: int)
signal portal_properties(slot: int)

const HOVER_MATERIAL = preload("res://materials/highlight.tres")
const DEFAULT_MATERIAL = preload("res://materials/concrete/concrete.tres")

@export var label: Label3D
@export var cylinder: CSGCylinder3D
var description: String = ""
var moon: Moon


func select() -> void:
	if not is_multiplayer_authority():
		return

	var slot := get_index()
	portal_entered.emit(Menu.get_save_file_path(str(slot)), slot)


func _on_area_3d_mouse_entered() -> void:
	cylinder.material_overlay = HOVER_MATERIAL
	show_tooltip()


func _on_area_3d_mouse_exited() -> void:
	cylinder.material_overlay = null
	hide_tooltip()


func show_tooltip() -> void:
	if not moon:
		return
	var tooltip := moon.tooltip as PanelContainer
	var name_label := tooltip.get_node("VBoxContainer/NameLabel") as Label
	var desc_label := tooltip.get_node("VBoxContainer/DescriptionLabel") as Label
	var instructions_label := tooltip.get_node("VBoxContainer/InstructionsLabel") as Label

	tooltip.visible = true

	if label.text.is_empty():
		name_label.text = "Empty Slot"
		desc_label.visible = false
		instructions_label.text = "Left-click to create new level"
	else:
		name_label.text = label.text
		desc_label.visible = true
		desc_label.text = description if not description.is_empty() else "(No description)"
		instructions_label.text = "Left-click to edit - Right-click to delete"

	var screen_pos := get_viewport().get_camera_3d().unproject_position(global_position)
	screen_pos.y -= 50
	tooltip.position = screen_pos - tooltip.size / 2


func hide_tooltip() -> void:
	if not moon:
		return
	moon.tooltip.visible = false


func _on_area_3d_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not is_visible_in_tree():
		return

	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event and mouse_button_event.pressed:
		match mouse_button_event.button_index:
			MOUSE_BUTTON_LEFT:
				select()
			MOUSE_BUTTON_RIGHT:
				portal_properties.emit(get_index())
