class_name GadgetOutputPort
extends Panel

var icon: Texture2D:
	set(value):
		icon = value
		update_icon()

@onready var texture_rect := $TextureRect as TextureRect

func _ready() -> void:
	update_icon()

func update_icon() -> void:
	if texture_rect:
		texture_rect.texture = icon
