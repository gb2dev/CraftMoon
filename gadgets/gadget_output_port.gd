class_name GadgetOutputPort
extends Control


var icon: Texture2D:
	set(value):
		icon = value
		update_icon()
var color: Color:
	set(value):
		color = value
		update_color()

@onready var texture_rect := $TextureRect as TextureRect
@onready var panel := $Panel as Panel


func _ready() -> void:
	update_icon()
	update_color()


func update_icon() -> void:
	if texture_rect:
		texture_rect.texture = icon


func update_color() -> void:
	if panel:
		panel.self_modulate = color
