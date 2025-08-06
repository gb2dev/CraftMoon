class_name GadgetInputPort
extends Panel

var icon: Texture2D:
	set(value):
		icon = value
		update_icon()
var output_controls: Array[GadgetOutputControl]
var output_visuals: Array[GadgetOutputVisual]

@onready var texture_rect := $TextureRect as TextureRect

func _ready() -> void:
	update_icon()

func update_icon() -> void:
	if texture_rect:
		texture_rect.texture = icon
