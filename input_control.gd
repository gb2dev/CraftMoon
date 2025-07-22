@tool
class_name InputControl
extends ColorRect

@export var icon: Texture2D = preload("res://icons/power.svg"):
	set(value):
		icon = value
		update_icon()

var output_controls: Array[OutputControl]
var output_visuals: Array[OutputVisual]

@onready var texture_rect := $TextureRect as TextureRect

func _ready() -> void:
	update_icon()

func update_icon() -> void:
	if texture_rect:
		texture_rect.texture = icon
