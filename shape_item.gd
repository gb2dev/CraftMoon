class_name ShapeItem
extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = str(get_index() + 1)


func set_selected(value: bool) -> void:
	$Border.visible = value
