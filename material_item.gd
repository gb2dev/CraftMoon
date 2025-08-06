extends Button


@export var item: BaseMaterial3D
@export var item_data: ItemData
@export var object_properties: ObjectProperties


func _ready() -> void:
	icon = item_data.icon
	tooltip_text = item_data.name
	var _error := object_properties.selected_material_changed.connect(_on_selected_material_changed)


func _on_pressed() -> void:
	object_properties.change_object_material(item)
	var object := object_properties.object
	if object:
		object_properties.sync_object_material.rpc(item.resource_path, object.get_path())


func _on_selected_material_changed() -> void:
	if visible:
		button_pressed = object_properties.get_object_material() == item
